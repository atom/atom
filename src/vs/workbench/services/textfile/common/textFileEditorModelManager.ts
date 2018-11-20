/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import { Event, Emitter, debounceEvent } from 'vs/base/common/event';
import { TPromise } from 'vs/base/common/winjs.base';
import { URI } from 'vs/base/common/uri';
import { TextFileEditorModel } from 'vs/workbench/services/textfile/common/textFileEditorModel';
import { dispose, IDisposable, Disposable } from 'vs/base/common/lifecycle';
import { ITextFileEditorModel, ITextFileEditorModelManager, TextFileModelChangeEvent, StateChange, IModelLoadOrCreateOptions } from 'vs/workbench/services/textfile/common/textfiles';
import { ILifecycleService } from 'vs/platform/lifecycle/common/lifecycle';
import { IInstantiationService } from 'vs/platform/instantiation/common/instantiation';
import { ResourceMap } from 'vs/base/common/map';
import { onUnexpectedError } from 'vs/base/common/errors';

export class TextFileEditorModelManager extends Disposable implements ITextFileEditorModelManager {

	private readonly _onModelDisposed: Emitter<URI> = this._register(new Emitter<URI>());
	get onModelDisposed(): Event<URI> { return this._onModelDisposed.event; }

	private readonly _onModelContentChanged: Emitter<TextFileModelChangeEvent> = this._register(new Emitter<TextFileModelChangeEvent>());
	get onModelContentChanged(): Event<TextFileModelChangeEvent> { return this._onModelContentChanged.event; }

	private readonly _onModelDirty: Emitter<TextFileModelChangeEvent> = this._register(new Emitter<TextFileModelChangeEvent>());
	get onModelDirty(): Event<TextFileModelChangeEvent> { return this._onModelDirty.event; }

	private readonly _onModelSaveError: Emitter<TextFileModelChangeEvent> = this._register(new Emitter<TextFileModelChangeEvent>());
	get onModelSaveError(): Event<TextFileModelChangeEvent> { return this._onModelSaveError.event; }

	private readonly _onModelSaved: Emitter<TextFileModelChangeEvent> = this._register(new Emitter<TextFileModelChangeEvent>());
	get onModelSaved(): Event<TextFileModelChangeEvent> { return this._onModelSaved.event; }

	private readonly _onModelReverted: Emitter<TextFileModelChangeEvent> = this._register(new Emitter<TextFileModelChangeEvent>());
	get onModelReverted(): Event<TextFileModelChangeEvent> { return this._onModelReverted.event; }

	private readonly _onModelEncodingChanged: Emitter<TextFileModelChangeEvent> = this._register(new Emitter<TextFileModelChangeEvent>());
	get onModelEncodingChanged(): Event<TextFileModelChangeEvent> { return this._onModelEncodingChanged.event; }

	private readonly _onModelOrphanedChanged: Emitter<TextFileModelChangeEvent> = this._register(new Emitter<TextFileModelChangeEvent>());
	get onModelOrphanedChanged(): Event<TextFileModelChangeEvent> { return this._onModelOrphanedChanged.event; }

	private _onModelsDirtyEvent: Event<TextFileModelChangeEvent[]>;
	private _onModelsSaveError: Event<TextFileModelChangeEvent[]>;
	private _onModelsSaved: Event<TextFileModelChangeEvent[]>;
	private _onModelsReverted: Event<TextFileModelChangeEvent[]>;

	private mapResourceToDisposeListener: ResourceMap<IDisposable>;
	private mapResourceToStateChangeListener: ResourceMap<IDisposable>;
	private mapResourceToModelContentChangeListener: ResourceMap<IDisposable>;
	private mapResourceToModel: ResourceMap<ITextFileEditorModel>;
	private mapResourceToPendingModelLoaders: ResourceMap<TPromise<ITextFileEditorModel>>;

	constructor(
		@ILifecycleService private lifecycleService: ILifecycleService,
		@IInstantiationService private instantiationService: IInstantiationService
	) {
		super();

		this.mapResourceToModel = new ResourceMap<ITextFileEditorModel>();
		this.mapResourceToDisposeListener = new ResourceMap<IDisposable>();
		this.mapResourceToStateChangeListener = new ResourceMap<IDisposable>();
		this.mapResourceToModelContentChangeListener = new ResourceMap<IDisposable>();
		this.mapResourceToPendingModelLoaders = new ResourceMap<TPromise<ITextFileEditorModel>>();

		this.registerListeners();
	}

	private registerListeners(): void {

		// Lifecycle
		this.lifecycleService.onShutdown(this.dispose, this);
	}

	get onModelsDirty(): Event<TextFileModelChangeEvent[]> {
		if (!this._onModelsDirtyEvent) {
			this._onModelsDirtyEvent = this.debounce(this.onModelDirty);
		}

		return this._onModelsDirtyEvent;
	}

	get onModelsSaveError(): Event<TextFileModelChangeEvent[]> {
		if (!this._onModelsSaveError) {
			this._onModelsSaveError = this.debounce(this.onModelSaveError);
		}

		return this._onModelsSaveError;
	}

	get onModelsSaved(): Event<TextFileModelChangeEvent[]> {
		if (!this._onModelsSaved) {
			this._onModelsSaved = this.debounce(this.onModelSaved);
		}

		return this._onModelsSaved;
	}

	get onModelsReverted(): Event<TextFileModelChangeEvent[]> {
		if (!this._onModelsReverted) {
			this._onModelsReverted = this.debounce(this.onModelReverted);
		}

		return this._onModelsReverted;
	}

	private debounce(event: Event<TextFileModelChangeEvent>): Event<TextFileModelChangeEvent[]> {
		return debounceEvent(event, (prev: TextFileModelChangeEvent[], cur: TextFileModelChangeEvent) => {
			if (!prev) {
				prev = [cur];
			} else {
				prev.push(cur);
			}
			return prev;
		}, this.debounceDelay());
	}

	protected debounceDelay(): number {
		return 250;
	}

	get(resource: URI): ITextFileEditorModel {
		return this.mapResourceToModel.get(resource);
	}

	loadOrCreate(resource: URI, options?: IModelLoadOrCreateOptions): TPromise<ITextFileEditorModel> {

		// Return early if model is currently being loaded
		const pendingLoad = this.mapResourceToPendingModelLoaders.get(resource);
		if (pendingLoad) {
			return pendingLoad;
		}

		let modelPromise: TPromise<ITextFileEditorModel>;

		// Model exists
		let model = this.get(resource);
		if (model) {
			if (options && options.reload) {

				// async reload: trigger a reload but return immediately
				if (options.reload.async) {
					modelPromise = TPromise.as(model);
					model.load(options).then(null, onUnexpectedError);
				}

				// sync reload: do not return until model reloaded
				else {
					modelPromise = model.load(options);
				}
			} else {
				modelPromise = TPromise.as(model);
			}
		}

		// Model does not exist
		else {
			model = this.instantiationService.createInstance(TextFileEditorModel, resource, options ? options.encoding : void 0);
			modelPromise = model.load(options);

			// Install state change listener
			this.mapResourceToStateChangeListener.set(resource, model.onDidStateChange(state => {
				const event = new TextFileModelChangeEvent(model, state);
				switch (state) {
					case StateChange.DIRTY:
						this._onModelDirty.fire(event);
						break;
					case StateChange.SAVE_ERROR:
						this._onModelSaveError.fire(event);
						break;
					case StateChange.SAVED:
						this._onModelSaved.fire(event);
						break;
					case StateChange.REVERTED:
						this._onModelReverted.fire(event);
						break;
					case StateChange.ENCODING:
						this._onModelEncodingChanged.fire(event);
						break;
					case StateChange.ORPHANED_CHANGE:
						this._onModelOrphanedChanged.fire(event);
						break;
				}
			}));

			// Install model content change listener
			this.mapResourceToModelContentChangeListener.set(resource, model.onDidContentChange(e => {
				this._onModelContentChanged.fire(new TextFileModelChangeEvent(model, e));
			}));
		}

		// Store pending loads to avoid race conditions
		this.mapResourceToPendingModelLoaders.set(resource, modelPromise);

		return modelPromise.then(model => {

			// Make known to manager (if not already known)
			this.add(resource, model);

			// Model can be dirty if a backup was restored, so we make sure to have this event delivered
			if (model.isDirty()) {
				this._onModelDirty.fire(new TextFileModelChangeEvent(model, StateChange.DIRTY));
			}

			// Remove from pending loads
			this.mapResourceToPendingModelLoaders.delete(resource);

			return model;
		}, error => {

			// Free resources of this invalid model
			model.dispose();

			// Remove from pending loads
			this.mapResourceToPendingModelLoaders.delete(resource);

			return TPromise.wrapError<ITextFileEditorModel>(error);
		});
	}

	getAll(resource?: URI, filter?: (model: ITextFileEditorModel) => boolean): ITextFileEditorModel[] {
		if (resource) {
			const res = this.mapResourceToModel.get(resource);

			return res ? [res] : [];
		}

		const res: ITextFileEditorModel[] = [];
		this.mapResourceToModel.forEach(model => {
			if (!filter || filter(model)) {
				res.push(model);
			}
		});

		return res;
	}

	add(resource: URI, model: ITextFileEditorModel): void {
		const knownModel = this.mapResourceToModel.get(resource);
		if (knownModel === model) {
			return; // already cached
		}

		// dispose any previously stored dispose listener for this resource
		const disposeListener = this.mapResourceToDisposeListener.get(resource);
		if (disposeListener) {
			disposeListener.dispose();
		}

		// store in cache but remove when model gets disposed
		this.mapResourceToModel.set(resource, model);
		this.mapResourceToDisposeListener.set(resource, model.onDispose(() => {
			this.remove(resource);
			this._onModelDisposed.fire(resource);
		}));
	}

	remove(resource: URI): void {
		this.mapResourceToModel.delete(resource);

		const disposeListener = this.mapResourceToDisposeListener.get(resource);
		if (disposeListener) {
			dispose(disposeListener);
			this.mapResourceToDisposeListener.delete(resource);
		}

		const stateChangeListener = this.mapResourceToStateChangeListener.get(resource);
		if (stateChangeListener) {
			dispose(stateChangeListener);
			this.mapResourceToStateChangeListener.delete(resource);
		}

		const modelContentChangeListener = this.mapResourceToModelContentChangeListener.get(resource);
		if (modelContentChangeListener) {
			dispose(modelContentChangeListener);
			this.mapResourceToModelContentChangeListener.delete(resource);
		}
	}

	clear(): void {

		// model caches
		this.mapResourceToModel.clear();
		this.mapResourceToPendingModelLoaders.clear();

		// dispose dispose listeners
		this.mapResourceToDisposeListener.forEach(l => l.dispose());
		this.mapResourceToDisposeListener.clear();

		// dispose state change listeners
		this.mapResourceToStateChangeListener.forEach(l => l.dispose());
		this.mapResourceToStateChangeListener.clear();

		// dispose model content change listeners
		this.mapResourceToModelContentChangeListener.forEach(l => l.dispose());
		this.mapResourceToModelContentChangeListener.clear();
	}

	disposeModel(model: TextFileEditorModel): void {
		if (!model) {
			return; // we need data!
		}

		if (model.isDisposed()) {
			return; // already disposed
		}

		if (this.mapResourceToPendingModelLoaders.has(model.getResource())) {
			return; // not yet loaded
		}

		if (model.isDirty()) {
			return; // not saved
		}

		model.dispose();
	}
}