/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import 'vs/css!./dropdown';
import { Gesture, EventType as GestureEventType } from 'vs/base/browser/touch';
import { ActionRunner, IAction, IActionRunner } from 'vs/base/common/actions';
import { BaseActionItem, IActionItemProvider } from 'vs/base/browser/ui/actionbar/actionbar';
import { IDisposable } from 'vs/base/common/lifecycle';
import { IContextViewProvider, IAnchor } from 'vs/base/browser/ui/contextview/contextview';
import { IMenuOptions } from 'vs/base/browser/ui/menu/menu';
import { ResolvedKeybinding, KeyCode } from 'vs/base/common/keyCodes';
import { EventHelper, EventType, removeClass, addClass, append, $, addDisposableListener, addClasses } from 'vs/base/browser/dom';
import { IContextMenuDelegate } from 'vs/base/browser/contextmenu';
import { StandardKeyboardEvent } from 'vs/base/browser/keyboardEvent';

export interface ILabelRenderer {
	(container: HTMLElement): IDisposable;
}

export interface IBaseDropdownOptions {
	label?: string;
	labelRenderer?: ILabelRenderer;
}

export class BaseDropdown extends ActionRunner {
	private _element: HTMLElement;
	private boxContainer: HTMLElement;
	private _label: HTMLElement;
	private contents: HTMLElement;
	private visible: boolean;

	constructor(container: HTMLElement, options: IBaseDropdownOptions) {
		super();

		this._element = append(container, $('.monaco-dropdown'));

		this._label = append(this._element, $('.dropdown-label'));

		let labelRenderer = options.labelRenderer;
		if (!labelRenderer) {
			labelRenderer = (container: HTMLElement): IDisposable => {
				container.textContent = options.label || '';

				return null;
			};
		}

		[EventType.CLICK, EventType.MOUSE_DOWN, GestureEventType.Tap].forEach(event => {
			this._register(addDisposableListener(this._label, event, e => EventHelper.stop(e, true))); // prevent default click behaviour to trigger
		});

		[EventType.MOUSE_DOWN, GestureEventType.Tap].forEach(event => {
			this._register(addDisposableListener(this._label, event, e => {
				if (e instanceof MouseEvent && e.detail > 1) {
					return; // prevent multiple clicks to open multiple context menus (https://github.com/Microsoft/vscode/issues/41363)
				}

				if (this.visible) {
					this.hide();
				} else {
					this.show();
				}
			}));
		});

		this._register(addDisposableListener(this._label, EventType.KEY_UP, e => {
			const event = new StandardKeyboardEvent(e as KeyboardEvent);
			if (event.equals(KeyCode.Enter) || event.equals(KeyCode.Space)) {
				EventHelper.stop(e, true); // https://github.com/Microsoft/vscode/issues/57997

				if (this.visible) {
					this.hide();
				} else {
					this.show();
				}
			}
		}));

		const cleanupFn = labelRenderer(this._label);
		if (cleanupFn) {
			this._register(cleanupFn);
		}

		Gesture.addTarget(this._label);
	}

	get element(): HTMLElement {
		return this._element;
	}

	get label(): HTMLElement {
		return this._label;
	}

	set tooltip(tooltip: string) {
		this._label.title = tooltip;
	}

	show(): void {
		this.visible = true;
	}

	hide(): void {
		this.visible = false;
	}

	protected onEvent(e: Event, activeElement: HTMLElement): void {
		this.hide();
	}

	dispose(): void {
		super.dispose();
		this.hide();

		if (this.boxContainer) {
			this.boxContainer.remove();
			this.boxContainer = null;
		}

		if (this.contents) {
			this.contents.remove();
			this.contents = null;
		}

		if (this._label) {
			this._label.remove();
			this._label = null;
		}
	}
}

export interface IDropdownOptions extends IBaseDropdownOptions {
	contextViewProvider: IContextViewProvider;
}

export class Dropdown extends BaseDropdown {
	private contextViewProvider: IContextViewProvider;

	constructor(container: HTMLElement, options: IDropdownOptions) {
		super(container, options);

		this.contextViewProvider = options.contextViewProvider;
	}

	show(): void {
		super.show();

		addClass(this.element, 'active');

		this.contextViewProvider.showContextView({
			getAnchor: () => this.getAnchor(),

			render: (container) => {
				return this.renderContents(container);
			},

			onDOMEvent: (e, activeElement) => {
				this.onEvent(e, activeElement);
			},

			onHide: () => this.onHide()
		});
	}

	protected getAnchor(): HTMLElement | IAnchor {
		return this.element;
	}

	protected onHide(): void {
		removeClass(this.element, 'active');
	}

	hide(): void {
		super.hide();

		if (this.contextViewProvider) {
			this.contextViewProvider.hideContextView();
		}
	}

	protected renderContents(container: HTMLElement): IDisposable {
		return null;
	}
}

export interface IContextMenuProvider {
	showContextMenu(delegate: IContextMenuDelegate): void;
}

export interface IActionProvider {
	getActions(): IAction[];
}

export interface IDropdownMenuOptions extends IBaseDropdownOptions {
	contextMenuProvider: IContextMenuProvider;
	actions?: IAction[];
	actionProvider?: IActionProvider;
	menuClassName?: string;
}

export class DropdownMenu extends BaseDropdown {
	private _contextMenuProvider: IContextMenuProvider;
	private _menuOptions: IMenuOptions;
	private _actions: IAction[];
	private actionProvider: IActionProvider;
	private menuClassName: string;

	constructor(container: HTMLElement, options: IDropdownMenuOptions) {
		super(container, options);

		this._contextMenuProvider = options.contextMenuProvider;
		this.actions = options.actions || [];
		this.actionProvider = options.actionProvider;
		this.menuClassName = options.menuClassName || '';
	}

	set menuOptions(options: IMenuOptions) {
		this._menuOptions = options;
	}

	get menuOptions(): IMenuOptions {
		return this._menuOptions;
	}

	private get actions(): IAction[] {
		if (this.actionProvider) {
			return this.actionProvider.getActions();
		}

		return this._actions;
	}

	private set actions(actions: IAction[]) {
		this._actions = actions;
	}

	show(): void {
		super.show();

		addClass(this.element, 'active');

		this._contextMenuProvider.showContextMenu({
			getAnchor: () => this.element,
			getActions: () => this.actions,
			getActionsContext: () => this.menuOptions ? this.menuOptions.context : null,
			getActionItem: action => this.menuOptions && this.menuOptions.actionItemProvider ? this.menuOptions.actionItemProvider(action) : null,
			getKeyBinding: action => this.menuOptions && this.menuOptions.getKeyBinding ? this.menuOptions.getKeyBinding(action) : null,
			getMenuClassName: () => this.menuClassName,
			onHide: () => this.onHide(),
			actionRunner: this.menuOptions ? this.menuOptions.actionRunner : null
		});
	}

	hide(): void {
		super.hide();
	}

	private onHide(): void {
		this.hide();
		removeClass(this.element, 'active');
	}
}

export class DropdownMenuActionItem extends BaseActionItem {
	private menuActionsOrProvider: any;
	private dropdownMenu: DropdownMenu;
	private contextMenuProvider: IContextMenuProvider;
	private actionItemProvider: IActionItemProvider;
	private keybindings: (action: IAction) => ResolvedKeybinding;
	private clazz: string;

	constructor(action: IAction, menuActions: IAction[], contextMenuProvider: IContextMenuProvider, actionItemProvider: IActionItemProvider, actionRunner: IActionRunner, keybindings: (action: IAction) => ResolvedKeybinding, clazz: string);
	constructor(action: IAction, actionProvider: IActionProvider, contextMenuProvider: IContextMenuProvider, actionItemProvider: IActionItemProvider, actionRunner: IActionRunner, keybindings: (action: IAction) => ResolvedKeybinding, clazz: string);
	constructor(action: IAction, menuActionsOrProvider: any, contextMenuProvider: IContextMenuProvider, actionItemProvider: IActionItemProvider, actionRunner: IActionRunner, keybindings: (action: IAction) => ResolvedKeybinding, clazz: string) {
		super(null, action);

		this.menuActionsOrProvider = menuActionsOrProvider;
		this.contextMenuProvider = contextMenuProvider;
		this.actionItemProvider = actionItemProvider;
		this.actionRunner = actionRunner;
		this.keybindings = keybindings;
		this.clazz = clazz;
	}

	render(container: HTMLElement): void {
		const labelRenderer: ILabelRenderer = (el: HTMLElement): IDisposable => {
			this.element = append(el, $('a.action-label.icon'));
			addClasses(this.element, this.clazz);

			this.element.tabIndex = 0;
			this.element.setAttribute('role', 'button');
			this.element.setAttribute('aria-haspopup', 'true');
			this.element.title = this._action.label || '';

			return null;
		};

		const options: IDropdownMenuOptions = {
			contextMenuProvider: this.contextMenuProvider,
			labelRenderer: labelRenderer
		};

		// Render the DropdownMenu around a simple action to toggle it
		if (Array.isArray(this.menuActionsOrProvider)) {
			options.actions = this.menuActionsOrProvider;
		} else {
			options.actionProvider = this.menuActionsOrProvider;
		}

		this.dropdownMenu = this._register(new DropdownMenu(container, options));

		this.dropdownMenu.menuOptions = {
			actionItemProvider: this.actionItemProvider,
			actionRunner: this.actionRunner,
			getKeyBinding: this.keybindings,
			context: this._context
		};
	}

	setActionContext(newContext: any): void {
		super.setActionContext(newContext);

		if (this.dropdownMenu) {
			this.dropdownMenu.menuOptions.context = newContext;
		}
	}

	show(): void {
		if (this.dropdownMenu) {
			this.dropdownMenu.show();
		}
	}
}
