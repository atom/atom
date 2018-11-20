/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import * as dom from 'vs/base/browser/dom';
import { StandardMouseEvent } from 'vs/base/browser/mouseEvent';
import { BreadcrumbsItem, BreadcrumbsWidget, IBreadcrumbsItemEvent } from 'vs/base/browser/ui/breadcrumbs/breadcrumbsWidget';
import { IconLabel } from 'vs/base/browser/ui/iconLabel/iconLabel';
import { tail } from 'vs/base/common/arrays';
import { timeout } from 'vs/base/common/async';
import { KeyCode, KeyMod } from 'vs/base/common/keyCodes';
import { combinedDisposable, dispose, IDisposable } from 'vs/base/common/lifecycle';
import { Schemas } from 'vs/base/common/network';
import { isEqual } from 'vs/base/common/resources';
import { URI } from 'vs/base/common/uri';
import 'vs/css!./media/breadcrumbscontrol';
import { ICodeEditor, isCodeEditor, isDiffEditor } from 'vs/editor/browser/editorBrowser';
import { Range } from 'vs/editor/common/core/range';
import { ICodeEditorViewState, ScrollType } from 'vs/editor/common/editorCommon';
import { symbolKindToCssClass } from 'vs/editor/common/modes';
import { OutlineElement, OutlineGroup, OutlineModel, TreeElement } from 'vs/editor/contrib/documentSymbols/outlineModel';
import { localize } from 'vs/nls';
import { MenuId, MenuRegistry } from 'vs/platform/actions/common/actions';
import { CommandsRegistry } from 'vs/platform/commands/common/commands';
import { IConfigurationService } from 'vs/platform/configuration/common/configuration';
import { ContextKeyExpr, IContextKey, IContextKeyService, RawContextKey } from 'vs/platform/contextkey/common/contextkey';
import { IContextViewService } from 'vs/platform/contextview/browser/contextView';
import { FileKind, IFileService, IFileStat } from 'vs/platform/files/common/files';
import { IInstantiationService, ServicesAccessor } from 'vs/platform/instantiation/common/instantiation';
import { KeybindingsRegistry, KeybindingWeight } from 'vs/platform/keybinding/common/keybindingsRegistry';
import { IListService, WorkbenchListFocusContextKey } from 'vs/platform/list/browser/listService';
import { IQuickOpenService } from 'vs/platform/quickOpen/common/quickOpen';
import { ColorIdentifier, ColorFunction } from 'vs/platform/theme/common/colorRegistry';
import { attachBreadcrumbsStyler } from 'vs/platform/theme/common/styler';
import { IThemeService } from 'vs/platform/theme/common/themeService';
import { IWorkspaceContextService } from 'vs/platform/workspace/common/workspace';
import { FileLabel } from 'vs/workbench/browser/labels';
import { BreadcrumbsConfig, IBreadcrumbsService } from 'vs/workbench/browser/parts/editor/breadcrumbs';
import { BreadcrumbElement, EditorBreadcrumbsModel, FileElement } from 'vs/workbench/browser/parts/editor/breadcrumbsModel';
import { BreadcrumbsPicker, createBreadcrumbsPicker } from 'vs/workbench/browser/parts/editor/breadcrumbsPicker';
import { SideBySideEditorInput } from 'vs/workbench/common/editor';
import { ACTIVE_GROUP, ACTIVE_GROUP_TYPE, IEditorService, SIDE_GROUP, SIDE_GROUP_TYPE } from 'vs/workbench/services/editor/common/editorService';
import { IEditorGroupsService } from 'vs/workbench/services/group/common/editorGroupsService';
import { ITelemetryService } from 'vs/platform/telemetry/common/telemetry';
import { ICodeEditorService } from 'vs/editor/browser/services/codeEditorService';
import { IEditorGroupView } from 'vs/workbench/browser/parts/editor/editor';

class Item extends BreadcrumbsItem {

	private readonly _disposables: IDisposable[] = [];

	constructor(
		readonly element: BreadcrumbElement,
		readonly options: IBreadcrumbsControlOptions,
		@IInstantiationService private readonly _instantiationService: IInstantiationService
	) {
		super();
	}

	dispose(): void {
		dispose(this._disposables);
	}

	equals(other: BreadcrumbsItem): boolean {
		if (!(other instanceof Item)) {
			return false;
		}
		if (this.element instanceof FileElement && other.element instanceof FileElement) {
			return isEqual(this.element.uri, other.element.uri);
		}
		if (this.element instanceof TreeElement && other.element instanceof TreeElement) {
			return this.element.id === other.element.id;
		}
		return false;
	}

	render(container: HTMLElement): void {
		if (this.element instanceof FileElement) {
			// file/folder
			let label = this._instantiationService.createInstance(FileLabel, container, {});
			label.setFile(this.element.uri, {
				hidePath: true,
				hideIcon: this.element.kind === FileKind.FOLDER || !this.options.showFileIcons,
				fileKind: this.element.kind,
				fileDecorations: { colors: this.options.showDecorationColors, badges: false },
			});
			dom.addClass(container, FileKind[this.element.kind].toLowerCase());
			this._disposables.push(label);

		} else if (this.element instanceof OutlineModel) {
			// has outline element but not in one
			let label = document.createElement('div');
			label.innerHTML = '&hellip;';
			label.className = 'hint-more';
			container.appendChild(label);

		} else if (this.element instanceof OutlineGroup) {
			// provider
			let label = new IconLabel(container);
			label.setValue(this.element.provider.displayName);
			this._disposables.push(label);

		} else if (this.element instanceof OutlineElement) {
			// symbol
			if (this.options.showSymbolIcons) {
				let icon = document.createElement('div');
				icon.className = symbolKindToCssClass(this.element.symbol.kind);
				container.appendChild(icon);
				dom.addClass(container, 'shows-symbol-icon');
			}
			let label = new IconLabel(container);
			let title = this.element.symbol.name.replace(/\r|\n|\r\n/g, '\u23CE');
			label.setValue(title);
			this._disposables.push(label);
		}
	}
}

export interface IBreadcrumbsControlOptions {
	showFileIcons: boolean;
	showSymbolIcons: boolean;
	showDecorationColors: boolean;
	breadcrumbsBackground: ColorIdentifier | ColorFunction;
}

export class BreadcrumbsControl {

	static HEIGHT = 22;

	static readonly Payload_Reveal = {};
	static readonly Payload_RevealAside = {};
	static readonly Payload_Pick = {};

	static CK_BreadcrumbsPossible = new RawContextKey('breadcrumbsPossible', false);
	static CK_BreadcrumbsVisible = new RawContextKey('breadcrumbsVisible', false);
	static CK_BreadcrumbsActive = new RawContextKey('breadcrumbsActive', false);

	private readonly _ckBreadcrumbsPossible: IContextKey<boolean>;
	private readonly _ckBreadcrumbsVisible: IContextKey<boolean>;
	private readonly _ckBreadcrumbsActive: IContextKey<boolean>;

	private readonly _cfUseQuickPick: BreadcrumbsConfig<boolean>;

	readonly domNode: HTMLDivElement;
	private readonly _widget: BreadcrumbsWidget;

	private _disposables = new Array<IDisposable>();
	private _breadcrumbsDisposables = new Array<IDisposable>();
	private _breadcrumbsPickerShowing = false;

	constructor(
		container: HTMLElement,
		private readonly _options: IBreadcrumbsControlOptions,
		private readonly _editorGroup: IEditorGroupView,
		@IContextKeyService private readonly _contextKeyService: IContextKeyService,
		@IContextViewService private readonly _contextViewService: IContextViewService,
		@IEditorService private readonly _editorService: IEditorService,
		@ICodeEditorService private readonly _codeEditorService: ICodeEditorService,
		@IWorkspaceContextService private readonly _workspaceService: IWorkspaceContextService,
		@IInstantiationService private readonly _instantiationService: IInstantiationService,
		@IThemeService private readonly _themeService: IThemeService,
		@IQuickOpenService private readonly _quickOpenService: IQuickOpenService,
		@IConfigurationService private readonly _configurationService: IConfigurationService,
		@IFileService private readonly _fileService: IFileService,
		@ITelemetryService private readonly _telemetryService: ITelemetryService,
		@IBreadcrumbsService breadcrumbsService: IBreadcrumbsService,
	) {
		this.domNode = document.createElement('div');
		dom.addClass(this.domNode, 'breadcrumbs-control');
		dom.append(container, this.domNode);

		this._widget = new BreadcrumbsWidget(this.domNode);
		this._widget.onDidSelectItem(this._onSelectEvent, this, this._disposables);
		this._widget.onDidFocusItem(this._onFocusEvent, this, this._disposables);
		this._widget.onDidChangeFocus(this._updateCkBreadcrumbsActive, this, this._disposables);
		this._disposables.push(attachBreadcrumbsStyler(this._widget, this._themeService, { breadcrumbsBackground: _options.breadcrumbsBackground }));

		this._ckBreadcrumbsPossible = BreadcrumbsControl.CK_BreadcrumbsPossible.bindTo(this._contextKeyService);
		this._ckBreadcrumbsVisible = BreadcrumbsControl.CK_BreadcrumbsVisible.bindTo(this._contextKeyService);
		this._ckBreadcrumbsActive = BreadcrumbsControl.CK_BreadcrumbsActive.bindTo(this._contextKeyService);

		this._cfUseQuickPick = BreadcrumbsConfig.UseQuickPick.bindTo(_configurationService);

		this._disposables.push(breadcrumbsService.register(this._editorGroup.id, this._widget));
		this._disposables.push(_fileService.onDidChangeFileSystemProviderRegistrations(this.update, this));
	}

	dispose(): void {
		this._disposables = dispose(this._disposables);
		this._breadcrumbsDisposables = dispose(this._breadcrumbsDisposables);
		this._ckBreadcrumbsPossible.reset();
		this._ckBreadcrumbsVisible.reset();
		this._ckBreadcrumbsActive.reset();
		this._cfUseQuickPick.dispose();
		this._widget.dispose();
		this.domNode.remove();
	}

	layout(dim: dom.Dimension): void {
		this._widget.layout(dim);
	}

	isHidden(): boolean {
		return dom.hasClass(this.domNode, 'hidden');
	}

	hide(): void {
		this._breadcrumbsDisposables = dispose(this._breadcrumbsDisposables);
		this._ckBreadcrumbsVisible.set(false);
		dom.toggleClass(this.domNode, 'hidden', true);
	}

	update(): boolean {
		this._breadcrumbsDisposables = dispose(this._breadcrumbsDisposables);

		// honor diff editors and such
		let input = this._editorGroup.activeEditor;
		if (input instanceof SideBySideEditorInput) {
			input = input.master;
		}

		if (!input || !input.getResource() || (input.getResource().scheme !== Schemas.untitled && !this._fileService.canHandleResource(input.getResource()))) {
			// cleanup and return when there is no input or when
			// we cannot handle this input
			this._ckBreadcrumbsPossible.set(false);
			if (!this.isHidden()) {
				this.hide();
				return true;
			} else {
				return false;
			}
		}

		dom.toggleClass(this.domNode, 'hidden', false);
		this._ckBreadcrumbsVisible.set(true);
		this._ckBreadcrumbsPossible.set(true);

		let editor = this._getActiveCodeEditor();
		let model = new EditorBreadcrumbsModel(input.getResource(), editor, this._workspaceService, this._configurationService);
		dom.toggleClass(this.domNode, 'relative-path', model.isRelative());

		let updateBreadcrumbs = () => {
			let items = model.getElements().map(element => new Item(element, this._options, this._instantiationService));
			this._widget.setItems(items);
			this._widget.reveal(items[items.length - 1]);
		};
		let listener = model.onDidUpdate(updateBreadcrumbs);
		updateBreadcrumbs();
		this._breadcrumbsDisposables = [model, listener];

		// close picker on hide/update
		this._breadcrumbsDisposables.push({
			dispose: () => {
				if (this._breadcrumbsPickerShowing) {
					this._contextViewService.hideContextView(this);
				}
			}
		});

		return true;
	}

	private _getActiveCodeEditor(): ICodeEditor {
		let control = this._editorGroup.activeControl.getControl();
		let editor: ICodeEditor;
		if (isCodeEditor(control)) {
			editor = control as ICodeEditor;
		} else if (isDiffEditor(control)) {
			editor = control.getModifiedEditor();
		}
		return editor;
	}

	private _onFocusEvent(event: IBreadcrumbsItemEvent): void {
		if (event.item && this._breadcrumbsPickerShowing) {
			return this._widget.setSelection(event.item);
		}
	}

	private _onSelectEvent(event: IBreadcrumbsItemEvent): void {
		if (!event.item) {
			return;
		}

		const { element } = event.item as Item;
		this._editorGroup.focus();

		/* __GDPR__
			"breadcrumbs/select" : {
				"type": { "classification": "SystemMetaData", "purpose": "FeatureInsight" }
			}
		*/
		this._telemetryService.publicLog('breadcrumbs/select', { type: element instanceof TreeElement ? 'symbol' : 'file' });

		const group = this._getEditorGroup(event.payload);
		if (group !== undefined) {
			// reveal the item
			this._widget.setFocused(undefined);
			this._widget.setSelection(undefined);
			this._revealInEditor(event, element, group);
			return;
		}

		if (this._cfUseQuickPick.getValue()) {
			// using quick pick
			this._widget.setFocused(undefined);
			this._widget.setSelection(undefined);
			this._quickOpenService.show(element instanceof TreeElement ? '@' : '');
			return;
		}

		// show picker
		let picker: BreadcrumbsPicker;
		let editor = this._getActiveCodeEditor();
		let editorDecorations: string[] = [];
		let editorViewState: ICodeEditorViewState;

		this._contextViewService.showContextView({
			render: (parent: HTMLElement) => {
				picker = createBreadcrumbsPicker(this._instantiationService, parent, element);
				let selectListener = picker.onDidPickElement(data => {
					if (data.target) {
						editorViewState = undefined;
					}
					this._contextViewService.hideContextView(this);
					this._revealInEditor(event, data.target, this._getEditorGroup(data.payload && data.payload.originalEvent), (data.payload && data.payload.originalEvent && data.payload.originalEvent.middleButton));
					/* __GDPR__
						"breadcrumbs/open" : {
							"type": { "classification": "SystemMetaData", "purpose": "FeatureInsight" }
						}
					*/
					this._telemetryService.publicLog('breadcrumbs/open', { type: !data ? 'nothing' : data.target instanceof TreeElement ? 'symbol' : 'file' });
				});
				let focusListener = picker.onDidFocusElement(data => {
					if (!editor || !(data.target instanceof OutlineElement)) {
						return;
					}
					if (!editorViewState) {
						editorViewState = editor.saveViewState();
					}
					const { symbol } = data.target;
					editor.revealRangeInCenter(symbol.range, ScrollType.Smooth);
					editorDecorations = editor.deltaDecorations(editorDecorations, [{
						range: symbol.range,
						options: {
							className: 'rangeHighlight',
							isWholeLine: true
						}
					}]);

				});
				this._breadcrumbsPickerShowing = true;
				this._updateCkBreadcrumbsActive();

				return combinedDisposable([selectListener, focusListener, picker]);
			},
			getAnchor: () => {
				let maxInnerWidth = window.innerWidth - 8 /*a little less the full widget*/;
				let maxHeight = Math.min(window.innerHeight * .7, 300);

				let pickerWidth = Math.min(maxInnerWidth, Math.max(240, maxInnerWidth / 4.17));
				let pickerArrowSize = 8;
				let pickerArrowOffset: number;

				let data = dom.getDomNodePagePosition(event.node.firstChild as HTMLElement);
				let y = data.top + data.height + pickerArrowSize;
				if (y + maxHeight >= window.innerHeight) {
					maxHeight = window.innerHeight - y - 30 /* room for shadow and status bar*/;
				}
				let x = data.left;
				if (x + pickerWidth >= maxInnerWidth) {
					x = maxInnerWidth - pickerWidth;
				}
				if (event.payload instanceof StandardMouseEvent) {
					let maxPickerArrowOffset = pickerWidth - 2 * pickerArrowSize;
					pickerArrowOffset = event.payload.posx - x;
					if (pickerArrowOffset > maxPickerArrowOffset) {
						x = Math.min(maxInnerWidth - pickerWidth, x + pickerArrowOffset - maxPickerArrowOffset);
						pickerArrowOffset = maxPickerArrowOffset;
					}
				} else {
					pickerArrowOffset = (data.left + (data.width * .3)) - x;
				}
				picker.setInput(element, maxHeight, pickerWidth, pickerArrowSize, Math.max(0, pickerArrowOffset));
				return { x, y };
			},
			onHide: (data) => {
				if (editor) {
					editor.deltaDecorations(editorDecorations, []);
					if (editorViewState) {
						editor.restoreViewState(editorViewState);
					}
				}
				this._breadcrumbsPickerShowing = false;
				this._updateCkBreadcrumbsActive();
				if (data === this) {
					this._widget.setFocused(undefined);
					this._widget.setSelection(undefined);
				}
			}
		});
	}

	private _updateCkBreadcrumbsActive(): void {
		const value = this._widget.isDOMFocused() || this._breadcrumbsPickerShowing;
		this._ckBreadcrumbsActive.set(value);
	}

	private _revealInEditor(event: IBreadcrumbsItemEvent, element: any, group: SIDE_GROUP_TYPE | ACTIVE_GROUP_TYPE, pinned: boolean = false): void {
		if (element instanceof FileElement) {
			if (element.kind === FileKind.FILE) {
				// open file in any editor
				this._editorService.openEditor({ resource: element.uri, options: { pinned: pinned } }, group);
			} else {
				// show next picker
				let items = this._widget.getItems();
				let idx = items.indexOf(event.item);
				this._widget.setFocused(items[idx + 1]);
				this._widget.setSelection(items[idx + 1], BreadcrumbsControl.Payload_Pick);
			}

		} else if (element instanceof OutlineElement) {
			// open symbol in code editor
			let model = OutlineModel.get(element);
			this._codeEditorService.openCodeEditor({
				resource: model.textModel.uri,
				options: {
					selection: Range.collapseToStart(element.symbol.selectionRange),
					revealInCenterIfOutsideViewport: true
				}
			}, this._getActiveCodeEditor(), group === SIDE_GROUP);
		}
	}

	private _getEditorGroup(data: StandardMouseEvent | object): SIDE_GROUP_TYPE | ACTIVE_GROUP_TYPE | undefined {
		if (data === BreadcrumbsControl.Payload_RevealAside || (data instanceof StandardMouseEvent && data.altKey)) {
			return SIDE_GROUP;
		} else if (data === BreadcrumbsControl.Payload_Reveal || (data instanceof StandardMouseEvent && data.metaKey)) {
			return ACTIVE_GROUP;
		} else {
			return undefined;
		}
	}
}

//#region commands

// toggle command
MenuRegistry.appendMenuItem(MenuId.CommandPalette, {
	command: {
		id: 'breadcrumbs.toggle',
		title: { value: localize('cmd.toggle', "Toggle Breadcrumbs"), original: 'Toggle Breadcrumbs' },
		category: localize('cmd.category', "View")
	}
});
MenuRegistry.appendMenuItem(MenuId.MenubarViewMenu, {
	group: '5_editor',
	order: 99,
	command: {
		id: 'breadcrumbs.toggle',
		title: localize('miToggleBreadcrumbs', "Toggle &&Breadcrumbs"),
		toggled: ContextKeyExpr.equals('config.breadcrumbs.enabled', true)
	}
});
CommandsRegistry.registerCommand('breadcrumbs.toggle', accessor => {
	let config = accessor.get(IConfigurationService);
	let value = BreadcrumbsConfig.IsEnabled.bindTo(config).getValue();
	BreadcrumbsConfig.IsEnabled.bindTo(config).updateValue(!value);
});

// focus/focus-and-select
function focusAndSelectHandler(accessor: ServicesAccessor, select: boolean): void {
	// find widget and focus/select
	const groups = accessor.get(IEditorGroupsService);
	const breadcrumbs = accessor.get(IBreadcrumbsService);
	const widget = breadcrumbs.getWidget(groups.activeGroup.id);
	if (widget) {
		const item = tail(widget.getItems());
		widget.setFocused(item);
		if (select) {
			widget.setSelection(item, BreadcrumbsControl.Payload_Pick);
		}
	}
}
MenuRegistry.appendMenuItem(MenuId.CommandPalette, {
	command: {
		id: 'breadcrumbs.focusAndSelect',
		title: { value: localize('cmd.focus', "Focus Breadcrumbs"), original: 'Focus Breadcrumbs' },
		precondition: BreadcrumbsControl.CK_BreadcrumbsVisible
	}
});
KeybindingsRegistry.registerCommandAndKeybindingRule({
	id: 'breadcrumbs.focusAndSelect',
	weight: KeybindingWeight.WorkbenchContrib,
	primary: KeyMod.CtrlCmd | KeyMod.Shift | KeyCode.US_DOT,
	when: BreadcrumbsControl.CK_BreadcrumbsPossible,
	handler: accessor => focusAndSelectHandler(accessor, true)
});
KeybindingsRegistry.registerCommandAndKeybindingRule({
	id: 'breadcrumbs.focus',
	weight: KeybindingWeight.WorkbenchContrib,
	primary: KeyMod.CtrlCmd | KeyMod.Shift | KeyCode.US_SEMICOLON,
	when: BreadcrumbsControl.CK_BreadcrumbsPossible,
	handler: accessor => focusAndSelectHandler(accessor, false)
});

// this commands is only enabled when breadcrumbs are
// disabled which it then enables and focuses
KeybindingsRegistry.registerCommandAndKeybindingRule({
	id: 'breadcrumbs.toggleToOn',
	weight: KeybindingWeight.WorkbenchContrib,
	primary: KeyMod.CtrlCmd | KeyMod.Shift | KeyCode.US_DOT,
	when: ContextKeyExpr.not('config.breadcrumbs.enabled'),
	handler: async accessor => {
		const instant = accessor.get(IInstantiationService);
		const config = accessor.get(IConfigurationService);
		// check if enabled and iff not enable
		const isEnabled = BreadcrumbsConfig.IsEnabled.bindTo(config);
		if (!isEnabled.getValue()) {
			await isEnabled.updateValue(true);
			await timeout(50); // hacky - the widget might not be ready yet...
		}
		return instant.invokeFunction(focusAndSelectHandler, true);
	}
});

// navigation
KeybindingsRegistry.registerCommandAndKeybindingRule({
	id: 'breadcrumbs.focusNext',
	weight: KeybindingWeight.WorkbenchContrib,
	primary: KeyCode.RightArrow,
	secondary: [KeyMod.CtrlCmd | KeyCode.RightArrow],
	mac: {
		primary: KeyCode.RightArrow,
		secondary: [KeyMod.Alt | KeyCode.RightArrow],
	},
	when: ContextKeyExpr.and(BreadcrumbsControl.CK_BreadcrumbsVisible, BreadcrumbsControl.CK_BreadcrumbsActive),
	handler(accessor) {
		const groups = accessor.get(IEditorGroupsService);
		const breadcrumbs = accessor.get(IBreadcrumbsService);
		breadcrumbs.getWidget(groups.activeGroup.id).focusNext();
	}
});
KeybindingsRegistry.registerCommandAndKeybindingRule({
	id: 'breadcrumbs.focusPrevious',
	weight: KeybindingWeight.WorkbenchContrib,
	primary: KeyCode.LeftArrow,
	secondary: [KeyMod.CtrlCmd | KeyCode.LeftArrow],
	mac: {
		primary: KeyCode.LeftArrow,
		secondary: [KeyMod.Alt | KeyCode.LeftArrow],
	},
	when: ContextKeyExpr.and(BreadcrumbsControl.CK_BreadcrumbsVisible, BreadcrumbsControl.CK_BreadcrumbsActive),
	handler(accessor) {
		const groups = accessor.get(IEditorGroupsService);
		const breadcrumbs = accessor.get(IBreadcrumbsService);
		breadcrumbs.getWidget(groups.activeGroup.id).focusPrev();
	}
});
KeybindingsRegistry.registerCommandAndKeybindingRule({
	id: 'breadcrumbs.selectFocused',
	weight: KeybindingWeight.WorkbenchContrib,
	primary: KeyCode.Enter,
	secondary: [KeyCode.DownArrow],
	when: ContextKeyExpr.and(BreadcrumbsControl.CK_BreadcrumbsVisible, BreadcrumbsControl.CK_BreadcrumbsActive),
	handler(accessor) {
		const groups = accessor.get(IEditorGroupsService);
		const breadcrumbs = accessor.get(IBreadcrumbsService);
		const widget = breadcrumbs.getWidget(groups.activeGroup.id);
		widget.setSelection(widget.getFocused(), BreadcrumbsControl.Payload_Pick);
	}
});
KeybindingsRegistry.registerCommandAndKeybindingRule({
	id: 'breadcrumbs.revealFocused',
	weight: KeybindingWeight.WorkbenchContrib,
	primary: KeyCode.Space,
	secondary: [KeyMod.CtrlCmd | KeyCode.Enter],
	when: ContextKeyExpr.and(BreadcrumbsControl.CK_BreadcrumbsVisible, BreadcrumbsControl.CK_BreadcrumbsActive),
	handler(accessor) {
		const groups = accessor.get(IEditorGroupsService);
		const breadcrumbs = accessor.get(IBreadcrumbsService);
		const widget = breadcrumbs.getWidget(groups.activeGroup.id);
		widget.setSelection(widget.getFocused(), BreadcrumbsControl.Payload_Reveal);
	}
});
KeybindingsRegistry.registerCommandAndKeybindingRule({
	id: 'breadcrumbs.selectEditor',
	weight: KeybindingWeight.WorkbenchContrib + 1,
	primary: KeyCode.Escape,
	when: ContextKeyExpr.and(BreadcrumbsControl.CK_BreadcrumbsVisible, BreadcrumbsControl.CK_BreadcrumbsActive),
	handler(accessor) {
		const groups = accessor.get(IEditorGroupsService);
		const breadcrumbs = accessor.get(IBreadcrumbsService);
		breadcrumbs.getWidget(groups.activeGroup.id).setFocused(undefined);
		breadcrumbs.getWidget(groups.activeGroup.id).setSelection(undefined);
		groups.activeGroup.activeControl.focus();
	}
});
KeybindingsRegistry.registerCommandAndKeybindingRule({
	id: 'breadcrumbs.revealFocusedFromTreeAside',
	weight: KeybindingWeight.WorkbenchContrib,
	primary: KeyMod.CtrlCmd | KeyCode.Enter,
	when: ContextKeyExpr.and(BreadcrumbsControl.CK_BreadcrumbsVisible, BreadcrumbsControl.CK_BreadcrumbsActive, WorkbenchListFocusContextKey),
	handler(accessor) {
		const editors = accessor.get(IEditorService);
		const lists = accessor.get(IListService);
		const element = <OutlineElement | IFileStat>lists.lastFocusedList.getFocus();
		if (element instanceof OutlineElement) {
			// open symbol in editor
			return editors.openEditor({
				resource: OutlineModel.get(element).textModel.uri,
				options: { selection: Range.collapseToStart(element.symbol.selectionRange) }
			}, SIDE_GROUP);

		} else if (URI.isUri(element.resource)) {
			// open file in editor
			return editors.openEditor({
				resource: element.resource,
			}, SIDE_GROUP);

		} else {
			// ignore
			return undefined;
		}
	}
});
//#endregion
