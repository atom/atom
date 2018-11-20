/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import 'vs/css!./standalone-tokens';
import { IDisposable } from 'vs/base/common/lifecycle';
import { URI } from 'vs/base/common/uri';
import { ICodeEditor } from 'vs/editor/browser/editorBrowser';
import { ICodeEditorService } from 'vs/editor/browser/services/codeEditorService';
import { OpenerService } from 'vs/editor/browser/services/openerService';
import { DiffNavigator } from 'vs/editor/browser/widget/diffNavigator';
import * as editorOptions from 'vs/editor/common/config/editorOptions';
import { BareFontInfo, FontInfo } from 'vs/editor/common/config/fontInfo';
import { Token } from 'vs/editor/common/core/token';
import * as editorCommon from 'vs/editor/common/editorCommon';
import { FindMatch, ITextModel, TextModelResolvedOptions } from 'vs/editor/common/model';
import * as modes from 'vs/editor/common/modes';
import { NULL_STATE, nullTokenize } from 'vs/editor/common/modes/nullMode';
import { IEditorWorkerService } from 'vs/editor/common/services/editorWorkerService';
import { ILanguageSelection } from 'vs/editor/common/services/modeService';
import { ITextModelService } from 'vs/editor/common/services/resolverService';
import { IWebWorkerOptions, MonacoWebWorker, createWebWorker as actualCreateWebWorker } from 'vs/editor/common/services/webWorker';
import * as standaloneEnums from 'vs/editor/common/standalone/standaloneEnums';
import { Colorizer, IColorizerElementOptions, IColorizerOptions } from 'vs/editor/standalone/browser/colorizer';
import { SimpleEditorModelResolverService } from 'vs/editor/standalone/browser/simpleServices';
import { IDiffEditorConstructionOptions, IEditorConstructionOptions, IStandaloneCodeEditor, IStandaloneDiffEditor, StandaloneDiffEditor, StandaloneEditor } from 'vs/editor/standalone/browser/standaloneCodeEditor';
import { DynamicStandaloneServices, IEditorOverrideServices, StaticServices } from 'vs/editor/standalone/browser/standaloneServices';
import { IStandaloneThemeData, IStandaloneThemeService } from 'vs/editor/standalone/common/standaloneThemeService';
import { ICommandService } from 'vs/platform/commands/common/commands';
import { IConfigurationService } from 'vs/platform/configuration/common/configuration';
import { IContextKeyService } from 'vs/platform/contextkey/common/contextkey';
import { IContextViewService } from 'vs/platform/contextview/browser/contextView';
import { IInstantiationService } from 'vs/platform/instantiation/common/instantiation';
import { IKeybindingService } from 'vs/platform/keybinding/common/keybinding';
import { IMarker, IMarkerData } from 'vs/platform/markers/common/markers';
import { INotificationService } from 'vs/platform/notification/common/notification';
import { IOpenerService } from 'vs/platform/opener/common/opener';

function withAllStandaloneServices<T extends editorCommon.IEditor>(domElement: HTMLElement, override: IEditorOverrideServices, callback: (services: DynamicStandaloneServices) => T): T {
	let services = new DynamicStandaloneServices(domElement, override);

	let simpleEditorModelResolverService: SimpleEditorModelResolverService | null = null;
	if (!services.has(ITextModelService)) {
		simpleEditorModelResolverService = new SimpleEditorModelResolverService();
		services.set(ITextModelService, simpleEditorModelResolverService);
	}

	if (!services.has(IOpenerService)) {
		services.set(IOpenerService, new OpenerService(services.get(ICodeEditorService), services.get(ICommandService)));
	}

	let result = callback(services);

	if (simpleEditorModelResolverService) {
		simpleEditorModelResolverService.setEditor(result);
	}

	return result;
}

/**
 * Create a new editor under `domElement`.
 * `domElement` should be empty (not contain other dom nodes).
 * The editor will read the size of `domElement`.
 */
export function create(domElement: HTMLElement, options?: IEditorConstructionOptions, override?: IEditorOverrideServices): IStandaloneCodeEditor {
	return withAllStandaloneServices(domElement, override || {}, (services) => {
		return new StandaloneEditor(
			domElement,
			options,
			services,
			services.get(IInstantiationService),
			services.get(ICodeEditorService),
			services.get(ICommandService),
			services.get(IContextKeyService),
			services.get(IKeybindingService),
			services.get(IContextViewService),
			services.get(IStandaloneThemeService),
			services.get(INotificationService),
			services.get(IConfigurationService),
		);
	});
}

/**
 * Emitted when an editor is created.
 * Creating a diff editor might cause this listener to be invoked with the two editors.
 * @event
 */
export function onDidCreateEditor(listener: (codeEditor: ICodeEditor) => void): IDisposable {
	return StaticServices.codeEditorService.get().onCodeEditorAdd((editor) => {
		listener(<ICodeEditor>editor);
	});
}

/**
 * Create a new diff editor under `domElement`.
 * `domElement` should be empty (not contain other dom nodes).
 * The editor will read the size of `domElement`.
 */
export function createDiffEditor(domElement: HTMLElement, options?: IDiffEditorConstructionOptions, override?: IEditorOverrideServices): IStandaloneDiffEditor {
	return withAllStandaloneServices(domElement, override, (services) => {
		return new StandaloneDiffEditor(
			domElement,
			options,
			services,
			services.get(IInstantiationService),
			services.get(IContextKeyService),
			services.get(IKeybindingService),
			services.get(IContextViewService),
			services.get(IEditorWorkerService),
			services.get(ICodeEditorService),
			services.get(IStandaloneThemeService),
			services.get(INotificationService),
			services.get(IConfigurationService),
		);
	});
}

export interface IDiffNavigator {
	canNavigate(): boolean;
	next(): void;
	previous(): void;
	dispose(): void;
}

export interface IDiffNavigatorOptions {
	readonly followsCaret?: boolean;
	readonly ignoreCharChanges?: boolean;
	readonly alwaysRevealFirst?: boolean;
}

export function createDiffNavigator(diffEditor: IStandaloneDiffEditor, opts?: IDiffNavigatorOptions): IDiffNavigator {
	return new DiffNavigator(diffEditor, opts);
}

function doCreateModel(value: string, languageSelection: ILanguageSelection, uri?: URI): ITextModel {
	return StaticServices.modelService.get().createModel(value, languageSelection, uri);
}

/**
 * Create a new editor model.
 * You can specify the language that should be set for this model or let the language be inferred from the `uri`.
 */
export function createModel(value: string, language?: string, uri?: URI): ITextModel {
	value = value || '';

	if (!language) {
		let path = uri ? uri.path : null;

		let firstLF = value.indexOf('\n');
		let firstLine = value;
		if (firstLF !== -1) {
			firstLine = value.substring(0, firstLF);
		}

		return doCreateModel(value, StaticServices.modeService.get().createByFilepathOrFirstLine(path, firstLine), uri);
	}
	return doCreateModel(value, StaticServices.modeService.get().create(language), uri);
}

/**
 * Change the language for a model.
 */
export function setModelLanguage(model: ITextModel, languageId: string): void {
	StaticServices.modelService.get().setMode(model, StaticServices.modeService.get().create(languageId));
}

/**
 * Set the markers for a model.
 */
export function setModelMarkers(model: ITextModel, owner: string, markers: IMarkerData[]): void {
	if (model) {
		StaticServices.markerService.get().changeOne(owner, model.uri, markers);
	}
}

/**
 * Get markers for owner and/or resource
 * @returns {IMarker[]} list of markers
 * @param filter
 */
export function getModelMarkers(filter: { owner?: string, resource?: URI, take?: number }): IMarker[] {
	return StaticServices.markerService.get().read(filter);
}

/**
 * Get the model that has `uri` if it exists.
 */
export function getModel(uri: URI): ITextModel | null {
	return StaticServices.modelService.get().getModel(uri);
}

/**
 * Get all the created models.
 */
export function getModels(): ITextModel[] {
	return StaticServices.modelService.get().getModels();
}

/**
 * Emitted when a model is created.
 * @event
 */
export function onDidCreateModel(listener: (model: ITextModel) => void): IDisposable {
	return StaticServices.modelService.get().onModelAdded(listener);
}

/**
 * Emitted right before a model is disposed.
 * @event
 */
export function onWillDisposeModel(listener: (model: ITextModel) => void): IDisposable {
	return StaticServices.modelService.get().onModelRemoved(listener);
}

/**
 * Emitted when a different language is set to a model.
 * @event
 */
export function onDidChangeModelLanguage(listener: (e: { readonly model: ITextModel; readonly oldLanguage: string; }) => void): IDisposable {
	return StaticServices.modelService.get().onModelModeChanged((e) => {
		listener({
			model: e.model,
			oldLanguage: e.oldModeId
		});
	});
}

/**
 * Create a new web worker that has model syncing capabilities built in.
 * Specify an AMD module to load that will `create` an object that will be proxied.
 */
export function createWebWorker<T>(opts: IWebWorkerOptions): MonacoWebWorker<T> {
	return actualCreateWebWorker<T>(StaticServices.modelService.get(), opts);
}

/**
 * Colorize the contents of `domNode` using attribute `data-lang`.
 */
export function colorizeElement(domNode: HTMLElement, options: IColorizerElementOptions): Promise<void> {
	return Colorizer.colorizeElement(StaticServices.standaloneThemeService.get(), StaticServices.modeService.get(), domNode, options);
}

/**
 * Colorize `text` using language `languageId`.
 */
export function colorize(text: string, languageId: string, options: IColorizerOptions): Promise<string> {
	return Colorizer.colorize(StaticServices.modeService.get(), text, languageId, options);
}

/**
 * Colorize a line in a model.
 */
export function colorizeModelLine(model: ITextModel, lineNumber: number, tabSize: number = 4): string {
	return Colorizer.colorizeModelLine(model, lineNumber, tabSize);
}

/**
 * @internal
 */
function getSafeTokenizationSupport(language: string): modes.ITokenizationSupport {
	let tokenizationSupport = modes.TokenizationRegistry.get(language);
	if (tokenizationSupport) {
		return tokenizationSupport;
	}
	return {
		getInitialState: () => NULL_STATE,
		tokenize: (line: string, state: modes.IState, deltaOffset: number) => nullTokenize(language, line, state, deltaOffset),
		tokenize2: undefined,
	};
}

/**
 * Tokenize `text` using language `languageId`
 */
export function tokenize(text: string, languageId: string): Token[][] {
	let modeService = StaticServices.modeService.get();
	// Needed in order to get the mode registered for subsequent look-ups
	modeService.triggerMode(languageId);

	let tokenizationSupport = getSafeTokenizationSupport(languageId);
	let lines = text.split(/\r\n|\r|\n/);
	let result: Token[][] = [];
	let state = tokenizationSupport.getInitialState();
	for (let i = 0, len = lines.length; i < len; i++) {
		let line = lines[i];
		let tokenizationResult = tokenizationSupport.tokenize(line, state, 0);

		result[i] = tokenizationResult.tokens;
		state = tokenizationResult.endState;
	}
	return result;
}

/**
 * Define a new theme or update an existing theme.
 */
export function defineTheme(themeName: string, themeData: IStandaloneThemeData): void {
	StaticServices.standaloneThemeService.get().defineTheme(themeName, themeData);
}

/**
 * Switches to a theme.
 */
export function setTheme(themeName: string): void {
	StaticServices.standaloneThemeService.get().setTheme(themeName);
}

/**
 * @internal
 */
export function createMonacoEditorAPI(): typeof monaco.editor {
	return {
		// methods
		create: <any>create,
		onDidCreateEditor: <any>onDidCreateEditor,
		createDiffEditor: <any>createDiffEditor,
		createDiffNavigator: <any>createDiffNavigator,

		createModel: <any>createModel,
		setModelLanguage: <any>setModelLanguage,
		setModelMarkers: <any>setModelMarkers,
		getModelMarkers: <any>getModelMarkers,
		getModels: <any>getModels,
		getModel: <any>getModel,
		onDidCreateModel: <any>onDidCreateModel,
		onWillDisposeModel: <any>onWillDisposeModel,
		onDidChangeModelLanguage: <any>onDidChangeModelLanguage,


		createWebWorker: <any>createWebWorker,
		colorizeElement: <any>colorizeElement,
		colorize: <any>colorize,
		colorizeModelLine: <any>colorizeModelLine,
		tokenize: <any>tokenize,
		defineTheme: <any>defineTheme,
		setTheme: <any>setTheme,

		// enums
		ScrollbarVisibility: standaloneEnums.ScrollbarVisibility,
		WrappingIndent: standaloneEnums.WrappingIndent,
		OverviewRulerLane: standaloneEnums.OverviewRulerLane,
		EndOfLinePreference: standaloneEnums.EndOfLinePreference,
		DefaultEndOfLine: standaloneEnums.DefaultEndOfLine,
		EndOfLineSequence: standaloneEnums.EndOfLineSequence,
		TrackedRangeStickiness: standaloneEnums.TrackedRangeStickiness,
		CursorChangeReason: standaloneEnums.CursorChangeReason,
		MouseTargetType: standaloneEnums.MouseTargetType,
		TextEditorCursorStyle: standaloneEnums.TextEditorCursorStyle,
		TextEditorCursorBlinkingStyle: standaloneEnums.TextEditorCursorBlinkingStyle,
		ContentWidgetPositionPreference: standaloneEnums.ContentWidgetPositionPreference,
		OverlayWidgetPositionPreference: standaloneEnums.OverlayWidgetPositionPreference,
		RenderMinimap: standaloneEnums.RenderMinimap,
		ScrollType: standaloneEnums.ScrollType,
		RenderLineNumbersType: standaloneEnums.RenderLineNumbersType,

		// classes
		InternalEditorOptions: <any>editorOptions.InternalEditorOptions,
		BareFontInfo: <any>BareFontInfo,
		FontInfo: <any>FontInfo,
		TextModelResolvedOptions: <any>TextModelResolvedOptions,
		FindMatch: <any>FindMatch,

		// vars
		EditorType: editorCommon.EditorType

	};
}
