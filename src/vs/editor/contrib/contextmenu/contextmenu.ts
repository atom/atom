/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import * as nls from 'vs/nls';
import * as dom from 'vs/base/browser/dom';
import { IKeyboardEvent } from 'vs/base/browser/keyboardEvent';
import { ActionItem, Separator } from 'vs/base/browser/ui/actionbar/actionbar';
import { IAnchor } from 'vs/base/browser/ui/contextview/contextview';
import { IAction } from 'vs/base/common/actions';
import { KeyCode, KeyMod, ResolvedKeybinding } from 'vs/base/common/keyCodes';
import { IDisposable, dispose } from 'vs/base/common/lifecycle';
import { ICodeEditor, IEditorMouseEvent, MouseTargetType } from 'vs/editor/browser/editorBrowser';
import { EditorAction, ServicesAccessor, registerEditorAction, registerEditorContribution } from 'vs/editor/browser/editorExtensions';
import { IEditorContribution, IScrollEvent, ScrollType } from 'vs/editor/common/editorCommon';
import { EditorContextKeys } from 'vs/editor/common/editorContextKeys';
import { IMenuService, MenuId } from 'vs/platform/actions/common/actions';
import { IContextKeyService } from 'vs/platform/contextkey/common/contextkey';
import { IContextMenuService, IContextViewService } from 'vs/platform/contextview/browser/contextView';
import { IKeybindingService } from 'vs/platform/keybinding/common/keybinding';
import { KeybindingWeight } from 'vs/platform/keybinding/common/keybindingsRegistry';

export interface IPosition {
	x: number;
	y: number;
}

export class ContextMenuController implements IEditorContribution {

	private static readonly ID = 'editor.contrib.contextmenu';

	public static get(editor: ICodeEditor): ContextMenuController {
		return editor.getContribution<ContextMenuController>(ContextMenuController.ID);
	}

	private _toDispose: IDisposable[] = [];
	private _contextMenuIsBeingShownCount: number = 0;
	private _editor: ICodeEditor;

	constructor(
		editor: ICodeEditor,
		@IContextMenuService private readonly _contextMenuService: IContextMenuService,
		@IContextViewService private readonly _contextViewService: IContextViewService,
		@IContextKeyService private readonly _contextKeyService: IContextKeyService,
		@IKeybindingService private readonly _keybindingService: IKeybindingService,
		@IMenuService private readonly _menuService: IMenuService
	) {
		this._editor = editor;

		this._toDispose.push(this._editor.onContextMenu((e: IEditorMouseEvent) => this._onContextMenu(e)));
		this._toDispose.push(this._editor.onDidScrollChange((e: IScrollEvent) => {
			if (this._contextMenuIsBeingShownCount > 0) {
				this._contextViewService.hideContextView();
			}
		}));
		this._toDispose.push(this._editor.onKeyDown((e: IKeyboardEvent) => {
			if (e.keyCode === KeyCode.ContextMenu) {
				// Chrome is funny like that
				e.preventDefault();
				e.stopPropagation();
				this.showContextMenu();
			}
		}));
	}

	private _onContextMenu(e: IEditorMouseEvent): void {
		if (!this._editor.getConfiguration().contribInfo.contextmenu) {
			this._editor.focus();
			// Ensure the cursor is at the position of the mouse click
			if (e.target.position && !this._editor.getSelection().containsPosition(e.target.position)) {
				this._editor.setPosition(e.target.position);
			}
			return; // Context menu is turned off through configuration
		}

		if (e.target.type === MouseTargetType.OVERLAY_WIDGET) {
			return; // allow native menu on widgets to support right click on input field for example in find
		}

		e.event.preventDefault();

		if (e.target.type !== MouseTargetType.CONTENT_TEXT && e.target.type !== MouseTargetType.CONTENT_EMPTY && e.target.type !== MouseTargetType.TEXTAREA) {
			return; // only support mouse click into text or native context menu key for now
		}

		// Ensure the editor gets focus if it hasn't, so the right events are being sent to other contributions
		this._editor.focus();

		// Ensure the cursor is at the position of the mouse click
		if (e.target.position && !this._editor.getSelection().containsPosition(e.target.position)) {
			this._editor.setPosition(e.target.position);
		}

		// Unless the user triggerd the context menu through Shift+F10, use the mouse position as menu position
		let forcedPosition: IPosition;
		if (e.target.type !== MouseTargetType.TEXTAREA) {
			forcedPosition = { x: e.event.posx, y: e.event.posy + 1 };
		}

		// Show the context menu
		this.showContextMenu(forcedPosition);
	}

	public showContextMenu(forcedPosition?: IPosition): void {
		if (!this._editor.getConfiguration().contribInfo.contextmenu) {
			return; // Context menu is turned off through configuration
		}

		if (!this._contextMenuService) {
			this._editor.focus();
			return;	// We need the context menu service to function
		}

		// Find actions available for menu
		const menuActions = this._getMenuActions();

		// Show menu if we have actions to show
		if (menuActions.length > 0) {
			this._doShowContextMenu(menuActions, forcedPosition);
		}
	}

	private _getMenuActions(): IAction[] {
		const result: IAction[] = [];

		let contextMenu = this._menuService.createMenu(MenuId.EditorContext, this._contextKeyService);
		const groups = contextMenu.getActions({ arg: this._editor.getModel().uri });
		contextMenu.dispose();

		for (let group of groups) {
			const [, actions] = group;
			result.push(...actions);
			result.push(new Separator());
		}
		result.pop(); // remove last separator
		return result;
	}

	private _doShowContextMenu(actions: IAction[], forcedPosition: IPosition | null = null): void {

		// Disable hover
		const oldHoverSetting = this._editor.getConfiguration().contribInfo.hover;
		this._editor.updateOptions({
			hover: {
				enabled: false
			}
		});

		let anchor: IAnchor = forcedPosition;
		if (!anchor) {
			// Ensure selection is visible
			this._editor.revealPosition(this._editor.getPosition(), ScrollType.Immediate);

			this._editor.render();
			const cursorCoords = this._editor.getScrolledVisiblePosition(this._editor.getPosition());

			// Translate to absolute editor position
			const editorCoords = dom.getDomNodePagePosition(this._editor.getDomNode());
			const posx = editorCoords.left + cursorCoords.left;
			const posy = editorCoords.top + cursorCoords.top + cursorCoords.height;

			anchor = { x: posx, y: posy };
		}

		// Show menu
		this._contextMenuIsBeingShownCount++;
		this._contextMenuService.showContextMenu({
			getAnchor: () => anchor,

			getActions: () => actions,

			getActionItem: (action) => {
				const keybinding = this._keybindingFor(action);
				if (keybinding) {
					return new ActionItem(action, action, { label: true, keybinding: keybinding.getLabel(), isMenu: true });
				}

				const customActionItem = <any>action;
				if (typeof customActionItem.getActionItem === 'function') {
					return customActionItem.getActionItem();
				}

				return new ActionItem(action, action, { icon: true, label: true, isMenu: true });
			},

			getKeyBinding: (action): ResolvedKeybinding => {
				return this._keybindingFor(action);
			},

			onHide: (wasCancelled: boolean) => {
				this._contextMenuIsBeingShownCount--;
				this._editor.focus();
				this._editor.updateOptions({
					hover: oldHoverSetting
				});
			}
		});
	}

	private _keybindingFor(action: IAction): ResolvedKeybinding {
		return this._keybindingService.lookupKeybinding(action.id);
	}

	public getId(): string {
		return ContextMenuController.ID;
	}

	public dispose(): void {
		if (this._contextMenuIsBeingShownCount > 0) {
			this._contextViewService.hideContextView();
		}

		this._toDispose = dispose(this._toDispose);
	}
}

class ShowContextMenu extends EditorAction {

	constructor() {
		super({
			id: 'editor.action.showContextMenu',
			label: nls.localize('action.showContextMenu.label', "Show Editor Context Menu"),
			alias: 'Show Editor Context Menu',
			precondition: null,
			kbOpts: {
				kbExpr: EditorContextKeys.textInputFocus,
				primary: KeyMod.Shift | KeyCode.F10,
				weight: KeybindingWeight.EditorContrib
			}
		});
	}

	public run(accessor: ServicesAccessor, editor: ICodeEditor): void {
		let contribution = ContextMenuController.get(editor);
		contribution.showContextMenu();
	}
}

registerEditorContribution(ContextMenuController);
registerEditorAction(ShowContextMenu);
