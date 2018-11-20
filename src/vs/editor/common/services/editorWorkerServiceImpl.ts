/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import { IntervalTimer } from 'vs/base/common/async';
import { Disposable, IDisposable, dispose, toDisposable } from 'vs/base/common/lifecycle';
import { URI } from 'vs/base/common/uri';
import { SimpleWorkerClient, logOnceWebWorkerWarning } from 'vs/base/common/worker/simpleWorker';
import { DefaultWorkerFactory } from 'vs/base/worker/defaultWorkerFactory';
import { IEditorOptions } from 'vs/editor/common/config/editorOptions';
import { IPosition, Position } from 'vs/editor/common/core/position';
import { IRange } from 'vs/editor/common/core/range';
import * as editorCommon from 'vs/editor/common/editorCommon';
import { ITextModel } from 'vs/editor/common/model';
import * as modes from 'vs/editor/common/modes';
import { LanguageConfigurationRegistry } from 'vs/editor/common/modes/languageConfigurationRegistry';
import { EditorSimpleWorkerImpl } from 'vs/editor/common/services/editorSimpleWorker';
import { IDiffComputationResult, IEditorWorkerService } from 'vs/editor/common/services/editorWorkerService';
import { IModelService } from 'vs/editor/common/services/modelService';
import { ITextResourceConfigurationService } from 'vs/editor/common/services/resourceConfiguration';

/**
 * Stop syncing a model to the worker if it was not needed for 1 min.
 */
const STOP_SYNC_MODEL_DELTA_TIME_MS = 60 * 1000;

/**
 * Stop the worker if it was not needed for 5 min.
 */
const STOP_WORKER_DELTA_TIME_MS = 5 * 60 * 1000;

function canSyncModel(modelService: IModelService, resource: URI): boolean {
	let model = modelService.getModel(resource);
	if (!model) {
		return false;
	}
	if (model.isTooLargeForSyncing()) {
		return false;
	}
	return true;
}

export class EditorWorkerServiceImpl extends Disposable implements IEditorWorkerService {
	public _serviceBrand: any;

	private readonly _modelService: IModelService;
	private readonly _workerManager: WorkerManager;

	constructor(
		@IModelService modelService: IModelService,
		@ITextResourceConfigurationService configurationService: ITextResourceConfigurationService
	) {
		super();
		this._modelService = modelService;
		this._workerManager = this._register(new WorkerManager(this._modelService));

		// todo@joh make sure this happens only once
		this._register(modes.LinkProviderRegistry.register('*', <modes.LinkProvider>{
			provideLinks: (model, token) => {
				if (!canSyncModel(this._modelService, model.uri)) {
					return Promise.resolve([]); // File too large
				}
				return this._workerManager.withWorker().then(client => client.computeLinks(model.uri));
			}
		}));
		this._register(modes.CompletionProviderRegistry.register('*', new WordBasedCompletionItemProvider(this._workerManager, configurationService, this._modelService)));
	}

	public dispose(): void {
		super.dispose();
	}

	public canComputeDiff(original: URI, modified: URI): boolean {
		return (canSyncModel(this._modelService, original) && canSyncModel(this._modelService, modified));
	}

	public computeDiff(original: URI, modified: URI, ignoreTrimWhitespace: boolean): Promise<IDiffComputationResult | null> {
		return this._workerManager.withWorker().then(client => client.computeDiff(original, modified, ignoreTrimWhitespace));
	}

	public canComputeDirtyDiff(original: URI, modified: URI): boolean {
		return (canSyncModel(this._modelService, original) && canSyncModel(this._modelService, modified));
	}

	public computeDirtyDiff(original: URI, modified: URI, ignoreTrimWhitespace: boolean): Promise<editorCommon.IChange[] | null> {
		return this._workerManager.withWorker().then(client => client.computeDirtyDiff(original, modified, ignoreTrimWhitespace));
	}

	public computeMoreMinimalEdits(resource: URI, edits: modes.TextEdit[]): Promise<modes.TextEdit[]> {
		if (!Array.isArray(edits) || edits.length === 0) {
			return Promise.resolve(edits);
		} else {
			if (!canSyncModel(this._modelService, resource)) {
				return Promise.resolve(edits); // File too large
			}
			return this._workerManager.withWorker().then(client => client.computeMoreMinimalEdits(resource, edits));
		}
	}

	public canNavigateValueSet(resource: URI): boolean {
		return (canSyncModel(this._modelService, resource));
	}

	public navigateValueSet(resource: URI, range: IRange, up: boolean): Promise<modes.IInplaceReplaceSupportResult | null> {
		return this._workerManager.withWorker().then(client => client.navigateValueSet(resource, range, up));
	}

	canComputeWordRanges(resource: URI): boolean {
		return canSyncModel(this._modelService, resource);
	}

	computeWordRanges(resource: URI, range: IRange): Promise<{ [word: string]: IRange[] } | null> {
		return this._workerManager.withWorker().then(client => client.computeWordRanges(resource, range));
	}
}

class WordBasedCompletionItemProvider implements modes.CompletionItemProvider {

	private readonly _workerManager: WorkerManager;
	private readonly _configurationService: ITextResourceConfigurationService;
	private readonly _modelService: IModelService;

	constructor(
		workerManager: WorkerManager,
		configurationService: ITextResourceConfigurationService,
		modelService: IModelService
	) {
		this._workerManager = workerManager;
		this._configurationService = configurationService;
		this._modelService = modelService;
	}

	provideCompletionItems(model: ITextModel, position: Position): Promise<modes.CompletionList | null> | undefined {
		const { wordBasedSuggestions } = this._configurationService.getValue<IEditorOptions>(model.uri, position, 'editor');
		if (!wordBasedSuggestions) {
			return undefined;
		}
		if (!canSyncModel(this._modelService, model.uri)) {
			return undefined; // File too large
		}
		return this._workerManager.withWorker().then(client => client.textualSuggest(model.uri, position));
	}
}

class WorkerManager extends Disposable {

	private _modelService: IModelService;
	private _editorWorkerClient: EditorWorkerClient | null;
	private _lastWorkerUsedTime: number;

	constructor(modelService: IModelService) {
		super();
		this._modelService = modelService;
		this._editorWorkerClient = null;

		let stopWorkerInterval = this._register(new IntervalTimer());
		stopWorkerInterval.cancelAndSet(() => this._checkStopIdleWorker(), Math.round(STOP_WORKER_DELTA_TIME_MS / 2));

		this._register(this._modelService.onModelRemoved(_ => this._checkStopEmptyWorker()));
	}

	public dispose(): void {
		if (this._editorWorkerClient) {
			this._editorWorkerClient.dispose();
			this._editorWorkerClient = null;
		}
		super.dispose();
	}

	/**
	 * Check if the model service has no more models and stop the worker if that is the case.
	 */
	private _checkStopEmptyWorker(): void {
		if (!this._editorWorkerClient) {
			return;
		}

		let models = this._modelService.getModels();
		if (models.length === 0) {
			// There are no more models => nothing possible for me to do
			this._editorWorkerClient.dispose();
			this._editorWorkerClient = null;
		}
	}

	/**
	 * Check if the worker has been idle for a while and then stop it.
	 */
	private _checkStopIdleWorker(): void {
		if (!this._editorWorkerClient) {
			return;
		}

		let timeSinceLastWorkerUsedTime = (new Date()).getTime() - this._lastWorkerUsedTime;
		if (timeSinceLastWorkerUsedTime > STOP_WORKER_DELTA_TIME_MS) {
			this._editorWorkerClient.dispose();
			this._editorWorkerClient = null;
		}
	}

	public withWorker(): Promise<EditorWorkerClient> {
		this._lastWorkerUsedTime = (new Date()).getTime();
		if (!this._editorWorkerClient) {
			this._editorWorkerClient = new EditorWorkerClient(this._modelService, 'editorWorkerService');
		}
		return Promise.resolve(this._editorWorkerClient);
	}
}

class EditorModelManager extends Disposable {

	private _proxy: EditorSimpleWorkerImpl;
	private _modelService: IModelService;
	private _syncedModels: { [modelUrl: string]: IDisposable[]; } = Object.create(null);
	private _syncedModelsLastUsedTime: { [modelUrl: string]: number; } = Object.create(null);

	constructor(proxy: EditorSimpleWorkerImpl, modelService: IModelService, keepIdleModels: boolean) {
		super();
		this._proxy = proxy;
		this._modelService = modelService;

		if (!keepIdleModels) {
			let timer = new IntervalTimer();
			timer.cancelAndSet(() => this._checkStopModelSync(), Math.round(STOP_SYNC_MODEL_DELTA_TIME_MS / 2));
			this._register(timer);
		}
	}

	public dispose(): void {
		for (let modelUrl in this._syncedModels) {
			dispose(this._syncedModels[modelUrl]);
		}
		this._syncedModels = Object.create(null);
		this._syncedModelsLastUsedTime = Object.create(null);
		super.dispose();
	}

	public esureSyncedResources(resources: URI[]): void {
		for (let i = 0; i < resources.length; i++) {
			let resource = resources[i];
			let resourceStr = resource.toString();

			if (!this._syncedModels[resourceStr]) {
				this._beginModelSync(resource);
			}
			if (this._syncedModels[resourceStr]) {
				this._syncedModelsLastUsedTime[resourceStr] = (new Date()).getTime();
			}
		}
	}

	private _checkStopModelSync(): void {
		let currentTime = (new Date()).getTime();

		let toRemove: string[] = [];
		for (let modelUrl in this._syncedModelsLastUsedTime) {
			let elapsedTime = currentTime - this._syncedModelsLastUsedTime[modelUrl];
			if (elapsedTime > STOP_SYNC_MODEL_DELTA_TIME_MS) {
				toRemove.push(modelUrl);
			}
		}

		for (let i = 0; i < toRemove.length; i++) {
			this._stopModelSync(toRemove[i]);
		}
	}

	private _beginModelSync(resource: URI): void {
		let model = this._modelService.getModel(resource);
		if (!model) {
			return;
		}
		if (model.isTooLargeForSyncing()) {
			return;
		}

		let modelUrl = resource.toString();

		this._proxy.acceptNewModel({
			url: model.uri.toString(),
			lines: model.getLinesContent(),
			EOL: model.getEOL(),
			versionId: model.getVersionId()
		});

		let toDispose: IDisposable[] = [];
		toDispose.push(model.onDidChangeContent((e) => {
			this._proxy.acceptModelChanged(modelUrl.toString(), e);
		}));
		toDispose.push(model.onWillDispose(() => {
			this._stopModelSync(modelUrl);
		}));
		toDispose.push(toDisposable(() => {
			this._proxy.acceptRemovedModel(modelUrl);
		}));

		this._syncedModels[modelUrl] = toDispose;
	}

	private _stopModelSync(modelUrl: string): void {
		let toDispose = this._syncedModels[modelUrl];
		delete this._syncedModels[modelUrl];
		delete this._syncedModelsLastUsedTime[modelUrl];
		dispose(toDispose);
	}
}

interface IWorkerClient<T> {
	getProxyObject(): Promise<T>;
	dispose(): void;
}

class SynchronousWorkerClient<T extends IDisposable> implements IWorkerClient<T> {
	private _instance: T;
	private _proxyObj: Promise<T>;

	constructor(instance: T) {
		this._instance = instance;
		this._proxyObj = Promise.resolve(this._instance);
	}

	public dispose(): void {
		this._instance.dispose();
	}

	public getProxyObject(): Promise<T> {
		return this._proxyObj;
	}
}

export class EditorWorkerClient extends Disposable {

	private _modelService: IModelService;
	private _worker: IWorkerClient<EditorSimpleWorkerImpl> | null;
	private _workerFactory: DefaultWorkerFactory;
	private _modelManager: EditorModelManager | null;

	constructor(modelService: IModelService, label: string | undefined) {
		super();
		this._modelService = modelService;
		this._workerFactory = new DefaultWorkerFactory(label);
		this._worker = null;
		this._modelManager = null;
	}

	private _getOrCreateWorker(): IWorkerClient<EditorSimpleWorkerImpl> {
		if (!this._worker) {
			try {
				this._worker = this._register(new SimpleWorkerClient<EditorSimpleWorkerImpl>(
					this._workerFactory,
					'vs/editor/common/services/editorSimpleWorker'
				));
			} catch (err) {
				logOnceWebWorkerWarning(err);
				this._worker = new SynchronousWorkerClient(new EditorSimpleWorkerImpl(null));
			}
		}
		return this._worker;
	}

	protected _getProxy(): Promise<EditorSimpleWorkerImpl> {
		return this._getOrCreateWorker().getProxyObject().then(null, (err) => {
			logOnceWebWorkerWarning(err);
			this._worker = new SynchronousWorkerClient(new EditorSimpleWorkerImpl(null));
			return this._getOrCreateWorker().getProxyObject();
		});
	}

	private _getOrCreateModelManager(proxy: EditorSimpleWorkerImpl): EditorModelManager {
		if (!this._modelManager) {
			this._modelManager = this._register(new EditorModelManager(proxy, this._modelService, false));
		}
		return this._modelManager;
	}

	protected _withSyncedResources(resources: URI[]): Promise<EditorSimpleWorkerImpl> {
		return this._getProxy().then((proxy) => {
			this._getOrCreateModelManager(proxy).esureSyncedResources(resources);
			return proxy;
		});
	}

	public computeDiff(original: URI, modified: URI, ignoreTrimWhitespace: boolean): Promise<IDiffComputationResult | null> {
		return this._withSyncedResources([original, modified]).then(proxy => {
			return proxy.computeDiff(original.toString(), modified.toString(), ignoreTrimWhitespace);
		});
	}

	public computeDirtyDiff(original: URI, modified: URI, ignoreTrimWhitespace: boolean): Promise<editorCommon.IChange[] | null> {
		return this._withSyncedResources([original, modified]).then(proxy => {
			return proxy.computeDirtyDiff(original.toString(), modified.toString(), ignoreTrimWhitespace);
		});
	}

	public computeMoreMinimalEdits(resource: URI, edits: modes.TextEdit[]): Promise<modes.TextEdit[]> {
		return this._withSyncedResources([resource]).then(proxy => {
			return proxy.computeMoreMinimalEdits(resource.toString(), edits);
		});
	}

	public computeLinks(resource: URI): Promise<modes.ILink[] | null> {
		return this._withSyncedResources([resource]).then(proxy => {
			return proxy.computeLinks(resource.toString());
		});
	}

	public textualSuggest(resource: URI, position: IPosition): Promise<modes.CompletionList | null> {
		return this._withSyncedResources([resource]).then(proxy => {
			let model = this._modelService.getModel(resource);
			if (!model) {
				return null;
			}
			let wordDefRegExp = LanguageConfigurationRegistry.getWordDefinition(model.getLanguageIdentifier().id);
			let wordDef = wordDefRegExp.source;
			let wordDefFlags = (wordDefRegExp.global ? 'g' : '') + (wordDefRegExp.ignoreCase ? 'i' : '') + (wordDefRegExp.multiline ? 'm' : '');
			return proxy.textualSuggest(resource.toString(), position, wordDef, wordDefFlags);
		});
	}

	computeWordRanges(resource: URI, range: IRange): Promise<{ [word: string]: IRange[] } | null> {
		return this._withSyncedResources([resource]).then(proxy => {
			let model = this._modelService.getModel(resource);
			if (!model) {
				return Promise.resolve(null);
			}
			let wordDefRegExp = LanguageConfigurationRegistry.getWordDefinition(model.getLanguageIdentifier().id);
			let wordDef = wordDefRegExp.source;
			let wordDefFlags = (wordDefRegExp.global ? 'g' : '') + (wordDefRegExp.ignoreCase ? 'i' : '') + (wordDefRegExp.multiline ? 'm' : '');
			return proxy.computeWordRanges(resource.toString(), range, wordDef, wordDefFlags);
		});
	}

	public navigateValueSet(resource: URI, range: IRange, up: boolean): Promise<modes.IInplaceReplaceSupportResult | null> {
		return this._withSyncedResources([resource]).then(proxy => {
			let model = this._modelService.getModel(resource);
			if (!model) {
				return null;
			}
			let wordDefRegExp = LanguageConfigurationRegistry.getWordDefinition(model.getLanguageIdentifier().id);
			let wordDef = wordDefRegExp.source;
			let wordDefFlags = (wordDefRegExp.global ? 'g' : '') + (wordDefRegExp.ignoreCase ? 'i' : '') + (wordDefRegExp.multiline ? 'm' : '');
			return proxy.navigateValueSet(resource.toString(), range, up, wordDef, wordDefFlags);
		});
	}
}
