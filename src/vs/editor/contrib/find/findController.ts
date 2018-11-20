/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import * as nls from 'vs/nls';
import { Delayer } from 'vs/base/common/async';
import { KeyCode, KeyMod } from 'vs/base/common/keyCodes';
import { Disposable } from 'vs/base/common/lifecycle';
import * as strings from 'vs/base/common/strings';
import { ICodeEditor } from 'vs/editor/browser/editorBrowser';
import { EditorAction, EditorCommand, ServicesAccessor, registerEditorAction, registerEditorCommand, registerEditorContribution } from 'vs/editor/browser/editorExtensions';
import * as editorCommon from 'vs/editor/common/editorCommon';
import { EditorContextKeys } from 'vs/editor/common/editorContextKeys';
import { CONTEXT_FIND_INPUT_FOCUSED, CONTEXT_FIND_WIDGET_VISIBLE, FIND_IDS, FindModelBoundToEditorModel, ToggleCaseSensitiveKeybinding, ToggleRegexKeybinding, ToggleSearchScopeKeybinding, ToggleWholeWordKeybinding } from 'vs/editor/contrib/find/findModel';
import { FindOptionsWidget } from 'vs/editor/contrib/find/findOptionsWidget';
import { FindReplaceState, FindReplaceStateChangedEvent, INewFindReplaceState } from 'vs/editor/contrib/find/findState';
import { FindWidget, IFindController } from 'vs/editor/contrib/find/findWidget';
import { MenuId } from 'vs/platform/actions/common/actions';
import { IClipboardService } from 'vs/platform/clipboard/common/clipboardService';
import { IContextKey, IContextKeyService } from 'vs/platform/contextkey/common/contextkey';
import { IContextViewService } from 'vs/platform/contextview/browser/contextView';
import { optional } from 'vs/platform/instantiation/common/instantiation';
import { IKeybindingService } from 'vs/platform/keybinding/common/keybinding';
import { KeybindingWeight } from 'vs/platform/keybinding/common/keybindingsRegistry';
import { IStorageService, StorageScope } from 'vs/platform/storage/common/storage';
import { IThemeService } from 'vs/platform/theme/common/themeService';

const SEARCH_STRING_MAX_LENGTH = 524288;

export function getSelectionSearchString(editor: ICodeEditor): string {
	let selection = editor.getSelection();

	// if selection spans multiple lines, default search string to empty
	if (selection.startLineNumber === selection.endLineNumber) {
		if (selection.isEmpty()) {
			let wordAtPosition = editor.getModel().getWordAtPosition(selection.getStartPosition());
			if (wordAtPosition) {
				return wordAtPosition.word;
			}
		} else {
			if (editor.getModel().getValueLengthInRange(selection) < SEARCH_STRING_MAX_LENGTH) {
				return editor.getModel().getValueInRange(selection);
			}
		}
	}

	return null;
}

export const enum FindStartFocusAction {
	NoFocusChange,
	FocusFindInput,
	FocusReplaceInput
}

export interface IFindStartOptions {
	forceRevealReplace: boolean;
	seedSearchStringFromSelection: boolean;
	seedSearchStringFromGlobalClipboard: boolean;
	shouldFocus: FindStartFocusAction;
	shouldAnimate: boolean;
	updateSearchScope: boolean;
}

export class CommonFindController extends Disposable implements editorCommon.IEditorContribution {

	private static readonly ID = 'editor.contrib.findController';

	protected _editor: ICodeEditor;
	private _findWidgetVisible: IContextKey<boolean>;
	protected _state: FindReplaceState;
	protected _updateHistoryDelayer: Delayer<void>;
	private _model: FindModelBoundToEditorModel;
	private _storageService: IStorageService;
	private _clipboardService: IClipboardService;
	protected readonly _contextKeyService: IContextKeyService;

	public static get(editor: ICodeEditor): CommonFindController {
		return editor.getContribution<CommonFindController>(CommonFindController.ID);
	}

	constructor(
		editor: ICodeEditor,
		@IContextKeyService contextKeyService: IContextKeyService,
		@IStorageService storageService: IStorageService,
		@IClipboardService clipboardService: IClipboardService
	) {
		super();
		this._editor = editor;
		this._findWidgetVisible = CONTEXT_FIND_WIDGET_VISIBLE.bindTo(contextKeyService);
		this._contextKeyService = contextKeyService;
		this._storageService = storageService;
		this._clipboardService = clipboardService;

		this._updateHistoryDelayer = new Delayer<void>(500);
		this._state = this._register(new FindReplaceState());
		this.loadQueryState();
		this._register(this._state.onFindReplaceStateChange((e) => this._onStateChanged(e)));

		this._model = null;

		this._register(this._editor.onDidChangeModel(() => {
			let shouldRestartFind = (this._editor.getModel() && this._state.isRevealed);

			this.disposeModel();

			this._state.change({
				searchScope: null,
				matchCase: this._storageService.getBoolean('editor.matchCase', StorageScope.WORKSPACE, false),
				wholeWord: this._storageService.getBoolean('editor.wholeWord', StorageScope.WORKSPACE, false),
				isRegex: this._storageService.getBoolean('editor.isRegex', StorageScope.WORKSPACE, false)
			}, false);

			if (shouldRestartFind) {
				this._start({
					forceRevealReplace: false,
					seedSearchStringFromSelection: false && this._editor.getConfiguration().contribInfo.find.seedSearchStringFromSelection,
					seedSearchStringFromGlobalClipboard: false,
					shouldFocus: FindStartFocusAction.NoFocusChange,
					shouldAnimate: false,
					updateSearchScope: false
				});
			}
		}));
	}

	public dispose(): void {
		this.disposeModel();
		super.dispose();
	}

	private disposeModel(): void {
		if (this._model) {
			this._model.dispose();
			this._model = null;
		}
	}

	public getId(): string {
		return CommonFindController.ID;
	}

	private _onStateChanged(e: FindReplaceStateChangedEvent): void {
		this.saveQueryState(e);

		if (e.isRevealed) {
			if (this._state.isRevealed) {
				this._findWidgetVisible.set(true);
			} else {
				this._findWidgetVisible.reset();
				this.disposeModel();
			}
		}
		if (e.searchString) {
			this.setGlobalBufferTerm(this._state.searchString);
		}
	}

	private saveQueryState(e: FindReplaceStateChangedEvent) {
		if (e.isRegex) {
			this._storageService.store('editor.isRegex', this._state.actualIsRegex, StorageScope.WORKSPACE);
		}
		if (e.wholeWord) {
			this._storageService.store('editor.wholeWord', this._state.actualWholeWord, StorageScope.WORKSPACE);
		}
		if (e.matchCase) {
			this._storageService.store('editor.matchCase', this._state.actualMatchCase, StorageScope.WORKSPACE);
		}
	}

	private loadQueryState() {
		this._state.change({
			matchCase: this._storageService.getBoolean('editor.matchCase', StorageScope.WORKSPACE, this._state.matchCase),
			wholeWord: this._storageService.getBoolean('editor.wholeWord', StorageScope.WORKSPACE, this._state.wholeWord),
			isRegex: this._storageService.getBoolean('editor.isRegex', StorageScope.WORKSPACE, this._state.isRegex)
		}, false);
	}

	public isFindInputFocused(): boolean {
		return CONTEXT_FIND_INPUT_FOCUSED.getValue(this._contextKeyService);
	}

	public getState(): FindReplaceState {
		return this._state;
	}

	public closeFindWidget(): void {
		this._state.change({
			isRevealed: false,
			searchScope: null
		}, false);
		this._editor.focus();
	}

	public toggleCaseSensitive(): void {
		this._state.change({ matchCase: !this._state.matchCase }, false);
		if (!this._state.isRevealed) {
			this.highlightFindOptions();
		}
	}

	public toggleWholeWords(): void {
		this._state.change({ wholeWord: !this._state.wholeWord }, false);
		if (!this._state.isRevealed) {
			this.highlightFindOptions();
		}
	}

	public toggleRegex(): void {
		this._state.change({ isRegex: !this._state.isRegex }, false);
		if (!this._state.isRevealed) {
			this.highlightFindOptions();
		}
	}

	public toggleSearchScope(): void {
		if (this._state.searchScope) {
			this._state.change({ searchScope: null }, true);
		} else {
			let selection = this._editor.getSelection();
			if (selection.endColumn === 1 && selection.endLineNumber > selection.startLineNumber) {
				selection = selection.setEndPosition(selection.endLineNumber - 1, this._editor.getModel().getLineMaxColumn(selection.endLineNumber - 1));
			}
			if (!selection.isEmpty()) {
				this._state.change({ searchScope: selection }, true);
			}
		}
	}

	public setSearchString(searchString: string): void {
		if (this._state.isRegex) {
			searchString = strings.escapeRegExpCharacters(searchString);
		}
		this._state.change({ searchString: searchString }, false);
	}

	public highlightFindOptions(): void {
		// overwritten in subclass
	}

	protected _start(opts: IFindStartOptions): void {
		this.disposeModel();

		if (!this._editor.getModel()) {
			// cannot do anything with an editor that doesn't have a model...
			return;
		}

		let stateChanges: INewFindReplaceState = {
			isRevealed: true
		};

		if (opts.seedSearchStringFromSelection) {
			let selectionSearchString = getSelectionSearchString(this._editor);
			if (selectionSearchString) {
				if (this._state.isRegex) {
					stateChanges.searchString = strings.escapeRegExpCharacters(selectionSearchString);
				} else {
					stateChanges.searchString = selectionSearchString;
				}
			}
		}

		if (!stateChanges.searchString && opts.seedSearchStringFromGlobalClipboard) {
			let selectionSearchString = this.getGlobalBufferTerm();
			if (selectionSearchString) {
				stateChanges.searchString = selectionSearchString;
			}
		}

		// Overwrite isReplaceRevealed
		if (opts.forceRevealReplace) {
			stateChanges.isReplaceRevealed = true;
		} else if (!this._findWidgetVisible.get()) {
			stateChanges.isReplaceRevealed = false;
		}

		if (opts.updateSearchScope) {
			let currentSelection = this._editor.getSelection();
			if (!currentSelection.isEmpty()) {
				stateChanges.searchScope = currentSelection;
			}
		}

		this._state.change(stateChanges, false);

		if (!this._model) {
			this._model = new FindModelBoundToEditorModel(this._editor, this._state);
		}
	}

	public start(opts: IFindStartOptions): void {
		this._start(opts);
	}

	public moveToNextMatch(): boolean {
		if (this._model) {
			this._model.moveToNextMatch();
			return true;
		}
		return false;
	}

	public moveToPrevMatch(): boolean {
		if (this._model) {
			this._model.moveToPrevMatch();
			return true;
		}
		return false;
	}

	public replace(): boolean {
		if (this._model) {
			this._model.replace();
			return true;
		}
		return false;
	}

	public replaceAll(): boolean {
		if (this._model) {
			this._model.replaceAll();
			return true;
		}
		return false;
	}

	public selectAllMatches(): boolean {
		if (this._model) {
			this._model.selectAllMatches();
			this._editor.focus();
			return true;
		}
		return false;
	}

	public getGlobalBufferTerm(): string {
		if (this._editor.getConfiguration().contribInfo.find.globalFindClipboard
			&& this._clipboardService
			&& !this._editor.getModel().isTooLargeForSyncing()
		) {
			return this._clipboardService.readFindText();
		}
		return '';
	}

	public setGlobalBufferTerm(text: string) {
		if (this._editor.getConfiguration().contribInfo.find.globalFindClipboard
			&& this._clipboardService
			&& !this._editor.getModel().isTooLargeForSyncing()
		) {
			this._clipboardService.writeFindText(text);
		}
	}
}

export class FindController extends CommonFindController implements IFindController {

	private _widget: FindWidget;
	private _findOptionsWidget: FindOptionsWidget;

	constructor(
		editor: ICodeEditor,
		@IContextViewService private readonly _contextViewService: IContextViewService,
		@IContextKeyService _contextKeyService: IContextKeyService,
		@IKeybindingService private readonly _keybindingService: IKeybindingService,
		@IThemeService private readonly _themeService: IThemeService,
		@IStorageService storageService: IStorageService,
		@optional(IClipboardService) clipboardService: IClipboardService
	) {
		super(editor, _contextKeyService, storageService, clipboardService);
	}

	protected _start(opts: IFindStartOptions): void {
		if (!this._widget) {
			this._createFindWidget();
		}

		if (!this._widget.getPosition() && this._editor.getConfiguration().contribInfo.find.autoFindInSelection) {
			// not visible yet so we need to set search scope if `editor.find.autoFindInSelection` is `true`
			opts.updateSearchScope = true;
		}

		super._start(opts);

		if (opts.shouldFocus === FindStartFocusAction.FocusReplaceInput) {
			this._widget.focusReplaceInput();
		} else if (opts.shouldFocus === FindStartFocusAction.FocusFindInput) {
			this._widget.focusFindInput();
		}
	}

	public highlightFindOptions(): void {
		if (!this._widget) {
			this._createFindWidget();
		}
		if (this._state.isRevealed) {
			this._widget.highlightFindOptions();
		} else {
			this._findOptionsWidget.highlightFindOptions();
		}
	}

	private _createFindWidget() {
		this._widget = this._register(new FindWidget(this._editor, this, this._state, this._contextViewService, this._keybindingService, this._contextKeyService, this._themeService));
		this._findOptionsWidget = this._register(new FindOptionsWidget(this._editor, this._state, this._keybindingService, this._themeService));
	}
}

export class StartFindAction extends EditorAction {

	constructor() {
		super({
			id: FIND_IDS.StartFindAction,
			label: nls.localize('startFindAction', "Find"),
			alias: 'Find',
			precondition: null,
			kbOpts: {
				kbExpr: null,
				primary: KeyMod.CtrlCmd | KeyCode.KEY_F,
				weight: KeybindingWeight.EditorContrib
			},
			menubarOpts: {
				menuId: MenuId.MenubarEditMenu,
				group: '3_find',
				title: nls.localize({ key: 'miFind', comment: ['&& denotes a mnemonic'] }, "&&Find"),
				order: 1
			}
		});
	}

	public run(accessor: ServicesAccessor, editor: ICodeEditor): void {
		let controller = CommonFindController.get(editor);
		if (controller) {
			controller.start({
				forceRevealReplace: false,
				seedSearchStringFromSelection: editor.getConfiguration().contribInfo.find.seedSearchStringFromSelection,
				seedSearchStringFromGlobalClipboard: editor.getConfiguration().contribInfo.find.globalFindClipboard,
				shouldFocus: FindStartFocusAction.FocusFindInput,
				shouldAnimate: true,
				updateSearchScope: false
			});
		}
	}
}

export class StartFindWithSelectionAction extends EditorAction {

	constructor() {
		super({
			id: FIND_IDS.StartFindWithSelection,
			label: nls.localize('startFindWithSelectionAction', "Find With Selection"),
			alias: 'Find With Selection',
			precondition: null,
			kbOpts: {
				kbExpr: null,
				primary: 0,
				mac: {
					primary: KeyMod.CtrlCmd | KeyCode.KEY_E,
				},
				weight: KeybindingWeight.EditorContrib
			}
		});
	}

	public run(accessor: ServicesAccessor, editor: ICodeEditor): void {
		let controller = CommonFindController.get(editor);
		if (controller) {
			controller.start({
				forceRevealReplace: false,
				seedSearchStringFromSelection: true,
				seedSearchStringFromGlobalClipboard: false,
				shouldFocus: FindStartFocusAction.FocusFindInput,
				shouldAnimate: true,
				updateSearchScope: false
			});

			controller.setGlobalBufferTerm(controller.getState().searchString);
		}
	}
}
export abstract class MatchFindAction extends EditorAction {
	public run(accessor: ServicesAccessor, editor: ICodeEditor): void {
		let controller = CommonFindController.get(editor);
		if (controller && !this._run(controller)) {
			controller.start({
				forceRevealReplace: false,
				seedSearchStringFromSelection: (controller.getState().searchString.length === 0) && editor.getConfiguration().contribInfo.find.seedSearchStringFromSelection,
				seedSearchStringFromGlobalClipboard: true,
				shouldFocus: FindStartFocusAction.NoFocusChange,
				shouldAnimate: true,
				updateSearchScope: false
			});
			this._run(controller);
		}
	}

	protected abstract _run(controller: CommonFindController): boolean;
}

export class NextMatchFindAction extends MatchFindAction {

	constructor() {
		super({
			id: FIND_IDS.NextMatchFindAction,
			label: nls.localize('findNextMatchAction', "Find Next"),
			alias: 'Find Next',
			precondition: null,
			kbOpts: {
				kbExpr: EditorContextKeys.focus,
				primary: KeyCode.F3,
				mac: { primary: KeyMod.CtrlCmd | KeyCode.KEY_G, secondary: [KeyCode.F3] },
				weight: KeybindingWeight.EditorContrib
			}
		});
	}

	protected _run(controller: CommonFindController): boolean {
		return controller.moveToNextMatch();
	}
}

export class PreviousMatchFindAction extends MatchFindAction {

	constructor() {
		super({
			id: FIND_IDS.PreviousMatchFindAction,
			label: nls.localize('findPreviousMatchAction', "Find Previous"),
			alias: 'Find Previous',
			precondition: null,
			kbOpts: {
				kbExpr: EditorContextKeys.focus,
				primary: KeyMod.Shift | KeyCode.F3,
				mac: { primary: KeyMod.CtrlCmd | KeyMod.Shift | KeyCode.KEY_G, secondary: [KeyMod.Shift | KeyCode.F3] },
				weight: KeybindingWeight.EditorContrib
			}
		});
	}

	protected _run(controller: CommonFindController): boolean {
		return controller.moveToPrevMatch();
	}
}

export abstract class SelectionMatchFindAction extends EditorAction {
	public run(accessor: ServicesAccessor, editor: ICodeEditor): void {
		let controller = CommonFindController.get(editor);
		if (!controller) {
			return;
		}
		let selectionSearchString = getSelectionSearchString(editor);
		if (selectionSearchString) {
			controller.setSearchString(selectionSearchString);
		}
		if (!this._run(controller)) {
			controller.start({
				forceRevealReplace: false,
				seedSearchStringFromSelection: editor.getConfiguration().contribInfo.find.seedSearchStringFromSelection,
				seedSearchStringFromGlobalClipboard: false,
				shouldFocus: FindStartFocusAction.NoFocusChange,
				shouldAnimate: true,
				updateSearchScope: false
			});
			this._run(controller);
		}
	}

	protected abstract _run(controller: CommonFindController): boolean;
}

export class NextSelectionMatchFindAction extends SelectionMatchFindAction {

	constructor() {
		super({
			id: FIND_IDS.NextSelectionMatchFindAction,
			label: nls.localize('nextSelectionMatchFindAction', "Find Next Selection"),
			alias: 'Find Next Selection',
			precondition: null,
			kbOpts: {
				kbExpr: EditorContextKeys.focus,
				primary: KeyMod.CtrlCmd | KeyCode.F3,
				weight: KeybindingWeight.EditorContrib
			}
		});
	}

	protected _run(controller: CommonFindController): boolean {
		return controller.moveToNextMatch();
	}
}

export class PreviousSelectionMatchFindAction extends SelectionMatchFindAction {

	constructor() {
		super({
			id: FIND_IDS.PreviousSelectionMatchFindAction,
			label: nls.localize('previousSelectionMatchFindAction', "Find Previous Selection"),
			alias: 'Find Previous Selection',
			precondition: null,
			kbOpts: {
				kbExpr: EditorContextKeys.focus,
				primary: KeyMod.CtrlCmd | KeyMod.Shift | KeyCode.F3,
				weight: KeybindingWeight.EditorContrib
			}
		});
	}

	protected _run(controller: CommonFindController): boolean {
		return controller.moveToPrevMatch();
	}
}

export class StartFindReplaceAction extends EditorAction {

	constructor() {
		super({
			id: FIND_IDS.StartFindReplaceAction,
			label: nls.localize('startReplace', "Replace"),
			alias: 'Replace',
			precondition: null,
			kbOpts: {
				kbExpr: null,
				primary: KeyMod.CtrlCmd | KeyCode.KEY_H,
				mac: { primary: KeyMod.CtrlCmd | KeyMod.Alt | KeyCode.KEY_F },
				weight: KeybindingWeight.EditorContrib
			},
			menubarOpts: {
				menuId: MenuId.MenubarEditMenu,
				group: '3_find',
				title: nls.localize({ key: 'miReplace', comment: ['&& denotes a mnemonic'] }, "&&Replace"),
				order: 2
			}
		});
	}

	public run(accessor: ServicesAccessor, editor: ICodeEditor): void {
		if (editor.getConfiguration().readOnly) {
			return;
		}

		let controller = CommonFindController.get(editor);
		let currentSelection = editor.getSelection();
		let findInputFocused = controller.isFindInputFocused();
		// we only seed search string from selection when the current selection is single line and not empty,
		// + the find input is not focused
		let seedSearchStringFromSelection = !currentSelection.isEmpty()
			&& currentSelection.startLineNumber === currentSelection.endLineNumber && editor.getConfiguration().contribInfo.find.seedSearchStringFromSelection
			&& !findInputFocused;
		/*
		 * if the existing search string in find widget is empty and we don't seed search string from selection, it means the Find Input is still empty, so we should focus the Find Input instead of Replace Input.

		 * findInputFocused true -> seedSearchStringFromSelection false, FocusReplaceInput
		 * findInputFocused false, seedSearchStringFromSelection true FocusReplaceInput
		 * findInputFocused false seedSearchStringFromSelection false FocusFindInput
		 */
		let shouldFocus = (findInputFocused || seedSearchStringFromSelection) ?
			FindStartFocusAction.FocusReplaceInput : FindStartFocusAction.FocusFindInput;


		if (controller) {
			controller.start({
				forceRevealReplace: true,
				seedSearchStringFromSelection: seedSearchStringFromSelection,
				seedSearchStringFromGlobalClipboard: editor.getConfiguration().contribInfo.find.seedSearchStringFromSelection,
				shouldFocus: shouldFocus,
				shouldAnimate: true,
				updateSearchScope: false
			});
		}
	}
}

registerEditorContribution(FindController);

registerEditorAction(StartFindAction);
registerEditorAction(StartFindWithSelectionAction);
registerEditorAction(NextMatchFindAction);
registerEditorAction(PreviousMatchFindAction);
registerEditorAction(NextSelectionMatchFindAction);
registerEditorAction(PreviousSelectionMatchFindAction);
registerEditorAction(StartFindReplaceAction);

const FindCommand = EditorCommand.bindToContribution<CommonFindController>(CommonFindController.get);

registerEditorCommand(new FindCommand({
	id: FIND_IDS.CloseFindWidgetCommand,
	precondition: CONTEXT_FIND_WIDGET_VISIBLE,
	handler: x => x.closeFindWidget(),
	kbOpts: {
		weight: KeybindingWeight.EditorContrib + 5,
		kbExpr: EditorContextKeys.focus,
		primary: KeyCode.Escape,
		secondary: [KeyMod.Shift | KeyCode.Escape]
	}
}));

registerEditorCommand(new FindCommand({
	id: FIND_IDS.ToggleCaseSensitiveCommand,
	precondition: null,
	handler: x => x.toggleCaseSensitive(),
	kbOpts: {
		weight: KeybindingWeight.EditorContrib + 5,
		kbExpr: EditorContextKeys.focus,
		primary: ToggleCaseSensitiveKeybinding.primary,
		mac: ToggleCaseSensitiveKeybinding.mac,
		win: ToggleCaseSensitiveKeybinding.win,
		linux: ToggleCaseSensitiveKeybinding.linux
	}
}));

registerEditorCommand(new FindCommand({
	id: FIND_IDS.ToggleWholeWordCommand,
	precondition: null,
	handler: x => x.toggleWholeWords(),
	kbOpts: {
		weight: KeybindingWeight.EditorContrib + 5,
		kbExpr: EditorContextKeys.focus,
		primary: ToggleWholeWordKeybinding.primary,
		mac: ToggleWholeWordKeybinding.mac,
		win: ToggleWholeWordKeybinding.win,
		linux: ToggleWholeWordKeybinding.linux
	}
}));

registerEditorCommand(new FindCommand({
	id: FIND_IDS.ToggleRegexCommand,
	precondition: null,
	handler: x => x.toggleRegex(),
	kbOpts: {
		weight: KeybindingWeight.EditorContrib + 5,
		kbExpr: EditorContextKeys.focus,
		primary: ToggleRegexKeybinding.primary,
		mac: ToggleRegexKeybinding.mac,
		win: ToggleRegexKeybinding.win,
		linux: ToggleRegexKeybinding.linux
	}
}));

registerEditorCommand(new FindCommand({
	id: FIND_IDS.ToggleSearchScopeCommand,
	precondition: null,
	handler: x => x.toggleSearchScope(),
	kbOpts: {
		weight: KeybindingWeight.EditorContrib + 5,
		kbExpr: EditorContextKeys.focus,
		primary: ToggleSearchScopeKeybinding.primary,
		mac: ToggleSearchScopeKeybinding.mac,
		win: ToggleSearchScopeKeybinding.win,
		linux: ToggleSearchScopeKeybinding.linux
	}
}));

registerEditorCommand(new FindCommand({
	id: FIND_IDS.ReplaceOneAction,
	precondition: CONTEXT_FIND_WIDGET_VISIBLE,
	handler: x => x.replace(),
	kbOpts: {
		weight: KeybindingWeight.EditorContrib + 5,
		kbExpr: EditorContextKeys.focus,
		primary: KeyMod.CtrlCmd | KeyMod.Shift | KeyCode.KEY_1
	}
}));

registerEditorCommand(new FindCommand({
	id: FIND_IDS.ReplaceAllAction,
	precondition: CONTEXT_FIND_WIDGET_VISIBLE,
	handler: x => x.replaceAll(),
	kbOpts: {
		weight: KeybindingWeight.EditorContrib + 5,
		kbExpr: EditorContextKeys.focus,
		primary: KeyMod.CtrlCmd | KeyMod.Alt | KeyCode.Enter
	}
}));

registerEditorCommand(new FindCommand({
	id: FIND_IDS.SelectAllMatchesAction,
	precondition: CONTEXT_FIND_WIDGET_VISIBLE,
	handler: x => x.selectAllMatches(),
	kbOpts: {
		weight: KeybindingWeight.EditorContrib + 5,
		kbExpr: EditorContextKeys.focus,
		primary: KeyMod.Alt | KeyCode.Enter
	}
}));
