/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import 'vs/css!./menu';
import * as nls from 'vs/nls';
import * as strings from 'vs/base/common/strings';
import { IActionRunner, IAction, Action } from 'vs/base/common/actions';
import { ActionBar, IActionItemProvider, ActionsOrientation, Separator, ActionItem, IActionItemOptions, BaseActionItem } from 'vs/base/browser/ui/actionbar/actionbar';
import { ResolvedKeybinding, KeyCode, KeyCodeUtils } from 'vs/base/common/keyCodes';
import { addClass, EventType, EventHelper, EventLike, removeTabIndexAndUpdateFocus, isAncestor, hasClass, addDisposableListener, removeClass, append, $, addClasses, getClientArea, removeClasses } from 'vs/base/browser/dom';
import { StandardKeyboardEvent } from 'vs/base/browser/keyboardEvent';
import { RunOnceScheduler } from 'vs/base/common/async';
import { IDisposable, dispose } from 'vs/base/common/lifecycle';
import { Color } from 'vs/base/common/color';

export const MENU_MNEMONIC_REGEX: RegExp = /\(&{1,2}(.)\)|&{1,2}(.)/;
export const MENU_ESCAPED_MNEMONIC_REGEX: RegExp = /(?:&amp;){1,2}(.)/;

export interface IMenuOptions {
	context?: any;
	actionItemProvider?: IActionItemProvider;
	actionRunner?: IActionRunner;
	getKeyBinding?: (action: IAction) => ResolvedKeybinding;
	ariaLabel?: string;
	enableMnemonics?: boolean;
}

export interface IMenuStyles {
	shadowColor?: Color;
	borderColor?: Color;
	foregroundColor?: Color;
	backgroundColor?: Color;
	selectionForegroundColor?: Color;
	selectionBackgroundColor?: Color;
	selectionBorderColor?: Color;
	separatorColor?: Color;
}

export class SubmenuAction extends Action {
	constructor(label: string, public entries: (SubmenuAction | IAction)[], cssClass?: string) {
		super(!!cssClass ? cssClass : 'submenu', label, '', true);
	}
}

interface ISubMenuData {
	parent: Menu;
	submenu?: Menu;
}

export class Menu extends ActionBar {
	private mnemonics: Map<KeyCode, Array<MenuActionItem>>;
	private menuDisposables: IDisposable[];

	constructor(container: HTMLElement, actions: IAction[], options: IMenuOptions = {}) {

		addClass(container, 'monaco-menu-container');
		container.setAttribute('role', 'presentation');
		let menuContainer = document.createElement('div');
		addClass(menuContainer, 'monaco-menu');
		menuContainer.setAttribute('role', 'presentation');
		container.appendChild(menuContainer);

		super(menuContainer, {
			orientation: ActionsOrientation.VERTICAL,
			actionItemProvider: action => this.doGetActionItem(action, options, parentData),
			context: options.context,
			actionRunner: options.actionRunner,
			ariaLabel: options.ariaLabel,
			triggerKeys: { keys: [KeyCode.Enter], keyDown: true }
		});

		this.actionsList.setAttribute('role', 'menu');

		this.actionsList.tabIndex = 0;

		this.menuDisposables = [];

		if (options.enableMnemonics) {
			this.menuDisposables.push(addDisposableListener(menuContainer, EventType.KEY_DOWN, (e) => {
				const key = KeyCodeUtils.fromString(e.key);
				if (this.mnemonics.has(key)) {
					EventHelper.stop(e, true);
					const actions = this.mnemonics.get(key);

					if (actions.length === 1) {
						if (actions[0] instanceof SubmenuActionItem) {
							this.focusItemByElement(actions[0].container);
						}

						actions[0].onClick(event);
					}

					if (actions.length > 1) {
						const action = actions.shift();
						this.focusItemByElement(action.container);

						actions.push(action);
						this.mnemonics.set(key, actions);
					}
				}
			}));
		}

		this._register(addDisposableListener(this.domNode, EventType.MOUSE_OUT, e => {
			let relatedTarget = (e as MouseEvent).relatedTarget as HTMLElement;
			if (!isAncestor(relatedTarget, this.domNode)) {
				this.focusedItem = undefined;
				this.updateFocus();
				e.stopPropagation();
			}
		}));

		this._register(addDisposableListener(this.actionsList, EventType.MOUSE_OVER, e => {
			let target = e.target as HTMLElement;
			if (!target || !isAncestor(target, this.actionsList) || target === this.actionsList) {
				return;
			}

			while (target.parentElement !== this.actionsList) {
				target = target.parentElement;
			}

			if (hasClass(target, 'action-item')) {
				const lastFocusedItem = this.focusedItem;
				this.setFocusedItem(target);

				if (lastFocusedItem !== this.focusedItem) {
					this.updateFocus();
				}
			}
		}));

		let parentData: ISubMenuData = {
			parent: this
		};

		this.mnemonics = new Map<KeyCode, Array<MenuActionItem>>();

		this.push(actions, { icon: true, label: true, isMenu: true });

		this.items.filter(item => !(item instanceof MenuSeparatorActionItem)).forEach((item: MenuActionItem, index: number, array: any[]) => {
			item.updatePositionInSet(index + 1, array.length);
		});
	}

	style(style: IMenuStyles): void {
		const container = this.getContainer();

		const fgColor = style.foregroundColor ? `${style.foregroundColor}` : null;
		const bgColor = style.backgroundColor ? `${style.backgroundColor}` : null;
		const border = style.borderColor ? `2px solid ${style.borderColor}` : null;
		const shadow = style.shadowColor ? `0 2px 4px ${style.shadowColor}` : null;

		container.style.border = border;
		this.domNode.style.color = fgColor;
		this.domNode.style.backgroundColor = bgColor;
		container.style.boxShadow = shadow;

		if (this.items) {
			this.items.forEach(item => {
				if (item instanceof MenuActionItem || item instanceof MenuSeparatorActionItem) {
					item.style(style);
				}
			});
		}
	}

	private focusItemByElement(element: HTMLElement) {
		const lastFocusedItem = this.focusedItem;
		this.setFocusedItem(element);

		if (lastFocusedItem !== this.focusedItem) {
			this.updateFocus();
		}
	}

	private setFocusedItem(element: HTMLElement): void {
		for (let i = 0; i < this.actionsList.children.length; i++) {
			let elem = this.actionsList.children[i];
			if (element === elem) {
				this.focusedItem = i;
				break;
			}
		}
	}

	private doGetActionItem(action: IAction, options: IMenuOptions, parentData: ISubMenuData): BaseActionItem {
		if (action instanceof Separator) {
			return new MenuSeparatorActionItem(options.context, action, { icon: true });
		} else if (action instanceof SubmenuAction) {
			const menuActionItem = new SubmenuActionItem(action, action.entries, parentData, options);

			if (options.enableMnemonics) {
				const mnemonic = menuActionItem.getMnemonic();
				if (mnemonic && menuActionItem.isEnabled()) {
					let actionItems: MenuActionItem[] = [];
					if (this.mnemonics.has(mnemonic)) {
						actionItems = this.mnemonics.get(mnemonic);
					}

					actionItems.push(menuActionItem);

					this.mnemonics.set(mnemonic, actionItems);
				}
			}

			return menuActionItem;
		} else {
			const menuItemOptions: IMenuItemOptions = { enableMnemonics: options.enableMnemonics };
			if (options.getKeyBinding) {
				const keybinding = options.getKeyBinding(action);
				if (keybinding) {
					menuItemOptions.keybinding = keybinding.getLabel();
				}
			}

			const menuActionItem = new MenuActionItem(options.context, action, menuItemOptions);

			if (options.enableMnemonics) {
				const mnemonic = menuActionItem.getMnemonic();
				if (mnemonic && menuActionItem.isEnabled()) {
					let actionItems: MenuActionItem[] = [];
					if (this.mnemonics.has(mnemonic)) {
						actionItems = this.mnemonics.get(mnemonic);
					}

					actionItems.push(menuActionItem);

					this.mnemonics.set(mnemonic, actionItems);
				}
			}

			return menuActionItem;
		}
	}

	public focus(selectFirst = true) {
		super.focus(selectFirst);
	}
}

interface IMenuItemOptions extends IActionItemOptions {
	enableMnemonics?: boolean;
}

class MenuActionItem extends BaseActionItem {

	public container: HTMLElement;

	protected options: IMenuItemOptions;
	protected item: HTMLElement;

	private label: HTMLElement;
	private check: HTMLElement;
	private mnemonic: KeyCode;
	private cssClass: string;
	protected menuStyle: IMenuStyles;

	constructor(ctx: any, action: IAction, options: IMenuItemOptions = {}) {
		options.isMenu = true;
		super(action, action, options);

		this.options = options;
		this.options.icon = options.icon !== undefined ? options.icon : false;
		this.options.label = options.label !== undefined ? options.label : true;
		this.cssClass = '';

		// Set mnemonic
		if (this.options.label && options.enableMnemonics) {
			let label = this.getAction().label;
			if (label) {
				let matches = MENU_MNEMONIC_REGEX.exec(label);
				if (matches) {
					this.mnemonic = KeyCodeUtils.fromString((!!matches[1] ? matches[1] : matches[2]).toLocaleLowerCase());
				}
			}
		}
	}

	render(container: HTMLElement): void {
		super.render(container);

		this.container = container;

		this.item = append(this.element, $('a.action-menu-item'));
		if (this._action.id === Separator.ID) {
			// A separator is a presentation item
			this.item.setAttribute('role', 'presentation');
		} else {
			this.item.setAttribute('role', 'menuitem');
			if (this.mnemonic) {
				this.item.setAttribute('aria-keyshortcuts', `${this.mnemonic}`);
			}
		}

		this.check = append(this.item, $('span.menu-item-check'));
		this.check.setAttribute('role', 'none');

		this.label = append(this.item, $('span.action-label'));

		if (this.options.label && this.options.keybinding) {
			append(this.item, $('span.keybinding')).textContent = this.options.keybinding;
		}

		this._register(addDisposableListener(this.element, EventType.MOUSE_UP, e => {
			EventHelper.stop(e, true);
			this.onClick(e);
		}));

		this.updateClass();
		this.updateLabel();
		this.updateTooltip();
		this.updateEnabled();
		this.updateChecked();
	}

	blur(): void {
		super.blur();
		this.applyStyle();
	}

	focus(): void {
		super.focus();
		this.item.focus();
		this.applyStyle();
	}

	updatePositionInSet(pos: number, setSize: number): void {
		this.item.setAttribute('aria-posinset', `${pos}`);
		this.item.setAttribute('aria-setsize', `${setSize}`);
	}

	updateLabel(): void {
		if (this.options.label) {
			let label = this.getAction().label;
			if (label) {
				const cleanLabel = cleanMnemonic(label);
				if (!this.options.enableMnemonics) {
					label = cleanLabel;
				}

				this.label.setAttribute('aria-label', cleanLabel);

				const matches = MENU_MNEMONIC_REGEX.exec(label);

				if (matches) {
					label = strings.escape(label).replace(MENU_ESCAPED_MNEMONIC_REGEX, '<u aria-hidden="true">$1</u>');
					this.item.setAttribute('aria-keyshortcuts', (!!matches[1] ? matches[1] : matches[2]).toLocaleLowerCase());
				}
			}

			this.label.innerHTML = label.trim();
		}
	}

	updateTooltip(): void {
		let title: string | null = null;

		if (this.getAction().tooltip) {
			title = this.getAction().tooltip;

		} else if (!this.options.label && this.getAction().label && this.options.icon) {
			title = this.getAction().label;

			if (this.options.keybinding) {
				title = nls.localize({ key: 'titleLabel', comment: ['action title', 'action keybinding'] }, "{0} ({1})", title, this.options.keybinding);
			}
		}

		if (title) {
			this.item.title = title;
		}
	}

	updateClass(): void {
		if (this.cssClass) {
			removeClasses(this.item, this.cssClass);
		}
		if (this.options.icon) {
			this.cssClass = this.getAction().class;
			addClass(this.label, 'icon');
			if (this.cssClass) {
				addClasses(this.label, this.cssClass);
			}
			this.updateEnabled();
		} else {
			removeClass(this.label, 'icon');
		}
	}

	updateEnabled(): void {
		if (this.getAction().enabled) {
			removeClass(this.element, 'disabled');
			removeClass(this.item, 'disabled');
			this.item.tabIndex = 0;
		} else {
			addClass(this.element, 'disabled');
			addClass(this.item, 'disabled');
			removeTabIndexAndUpdateFocus(this.item);
		}
	}

	updateChecked(): void {
		if (this.getAction().checked) {
			addClass(this.item, 'checked');
			this.item.setAttribute('role', 'menuitemcheckbox');
			this.item.setAttribute('aria-checked', 'true');
		} else {
			removeClass(this.item, 'checked');
			this.item.setAttribute('role', 'menuitem');
			this.item.setAttribute('aria-checked', 'false');
		}
	}

	getMnemonic(): KeyCode {
		return this.mnemonic;
	}

	protected applyStyle(): void {
		const isSelected = hasClass(this.element, 'focused');
		const fgColor = isSelected && this.menuStyle.selectionForegroundColor ? this.menuStyle.selectionForegroundColor : this.menuStyle.foregroundColor;
		const bgColor = isSelected && this.menuStyle.selectionBackgroundColor ? this.menuStyle.selectionBackgroundColor : this.menuStyle.backgroundColor;
		const border = isSelected && this.menuStyle.selectionBorderColor ? `1px solid ${this.menuStyle.selectionBorderColor}` : null;

		this.item.style.color = fgColor ? `${fgColor}` : null;
		this.check.style.backgroundColor = fgColor ? `${fgColor}` : null;
		this.item.style.backgroundColor = bgColor ? `${bgColor}` : null;
		this.container.style.border = border;
	}

	style(style: IMenuStyles): void {
		this.menuStyle = style;
		this.applyStyle();
	}
}

class SubmenuActionItem extends MenuActionItem {
	private mysubmenu: Menu;
	private submenuContainer: HTMLElement;
	private submenuIndicator: HTMLElement;
	private submenuDisposables: IDisposable[] = [];
	private mouseOver: boolean;
	private showScheduler: RunOnceScheduler;
	private hideScheduler: RunOnceScheduler;

	constructor(
		action: IAction,
		private submenuActions: IAction[],
		private parentData: ISubMenuData,
		private submenuOptions?: IMenuOptions
	) {
		super(action, action, submenuOptions);

		this.showScheduler = new RunOnceScheduler(() => {
			if (this.mouseOver) {
				this.cleanupExistingSubmenu(false);
				this.createSubmenu(false);
			}
		}, 250);

		this.hideScheduler = new RunOnceScheduler(() => {
			if ((!isAncestor(document.activeElement, this.element) && this.parentData.submenu === this.mysubmenu)) {
				this.parentData.parent.focus(false);
				this.cleanupExistingSubmenu(true);
			}
		}, 750);
	}

	render(container: HTMLElement): void {
		super.render(container);

		addClass(this.item, 'monaco-submenu-item');
		this.item.setAttribute('aria-haspopup', 'true');

		this.submenuIndicator = append(this.item, $('span.submenu-indicator'));
		this.submenuIndicator.setAttribute('aria-hidden', 'true');

		this._register(addDisposableListener(this.element, EventType.KEY_UP, e => {
			let event = new StandardKeyboardEvent(e as KeyboardEvent);
			if (event.equals(KeyCode.RightArrow) || event.equals(KeyCode.Enter)) {
				EventHelper.stop(e, true);

				this.createSubmenu(true);
			}
		}));

		this._register(addDisposableListener(this.element, EventType.KEY_DOWN, e => {
			let event = new StandardKeyboardEvent(e as KeyboardEvent);
			if (event.equals(KeyCode.RightArrow) || event.equals(KeyCode.Enter)) {
				EventHelper.stop(e, true);
			}
		}));

		this._register(addDisposableListener(this.element, EventType.MOUSE_OVER, e => {
			if (!this.mouseOver) {
				this.mouseOver = true;

				this.showScheduler.schedule();
			}
		}));

		this._register(addDisposableListener(this.element, EventType.MOUSE_LEAVE, e => {
			this.mouseOver = false;
		}));

		this._register(addDisposableListener(this.element, EventType.FOCUS_OUT, e => {
			if (!isAncestor(document.activeElement, this.element)) {
				this.hideScheduler.schedule();
			}
		}));
	}

	onClick(e: EventLike): void {
		// stop clicking from trying to run an action
		EventHelper.stop(e, true);

		this.cleanupExistingSubmenu(false);
		this.createSubmenu(false);
	}

	private cleanupExistingSubmenu(force: boolean): void {
		if (this.parentData.submenu && (force || (this.parentData.submenu !== this.mysubmenu))) {
			this.parentData.submenu.dispose();
			this.parentData.submenu = null;

			if (this.submenuContainer) {
				this.submenuDisposables = dispose(this.submenuDisposables);
				this.submenuContainer = null;
			}
		}
	}

	private createSubmenu(selectFirstItem = true): void {
		if (!this.parentData.submenu) {
			this.submenuContainer = append(this.element, $('div.monaco-submenu'));
			addClasses(this.submenuContainer, 'menubar-menu-items-holder', 'context-view');
			this.submenuContainer.style.left = `${getClientArea(this.element).width}px`;

			this.submenuDisposables.push(addDisposableListener(this.submenuContainer, EventType.KEY_UP, e => {
				let event = new StandardKeyboardEvent(e as KeyboardEvent);
				if (event.equals(KeyCode.LeftArrow)) {
					EventHelper.stop(e, true);

					this.parentData.parent.focus();
					this.parentData.submenu.dispose();
					this.parentData.submenu = null;

					this.submenuDisposables = dispose(this.submenuDisposables);
					this.submenuContainer = null;
				}
			}));

			this.submenuDisposables.push(addDisposableListener(this.submenuContainer, EventType.KEY_DOWN, e => {
				let event = new StandardKeyboardEvent(e as KeyboardEvent);
				if (event.equals(KeyCode.LeftArrow)) {
					EventHelper.stop(e, true);
				}
			}));

			this.parentData.submenu = new Menu(this.submenuContainer, this.submenuActions, this.submenuOptions);
			if (this.menuStyle) {
				this.parentData.submenu.style(this.menuStyle);
			}

			this.submenuDisposables.push(this.parentData.submenu.onDidCancel(() => {
				this.parentData.parent.focus();
				this.parentData.submenu.dispose();
				this.parentData.submenu = null;

				this.submenuDisposables = dispose(this.submenuDisposables);
				this.submenuContainer = null;
			}));

			this.parentData.submenu.focus(selectFirstItem);

			this.mysubmenu = this.parentData.submenu;
		} else {
			this.parentData.submenu.focus(false);
		}
	}

	protected applyStyle(): void {
		super.applyStyle();
		const isSelected = hasClass(this.element, 'focused');
		const fgColor = isSelected && this.menuStyle.selectionForegroundColor ? this.menuStyle.selectionForegroundColor : this.menuStyle.foregroundColor;

		this.submenuIndicator.style.backgroundColor = fgColor ? `${fgColor}` : null;

		if (this.parentData.submenu) {
			this.parentData.submenu.style(this.menuStyle);
		}
	}

	dispose(): void {
		super.dispose();

		this.hideScheduler.dispose();

		if (this.mysubmenu) {
			this.mysubmenu.dispose();
			this.mysubmenu = null;
		}

		if (this.submenuContainer) {
			this.submenuDisposables = dispose(this.submenuDisposables);
			this.submenuContainer = null;
		}
	}
}

class MenuSeparatorActionItem extends ActionItem {
	style(style: IMenuStyles): void {
		this.label.style.borderBottomColor = style.separatorColor ? `${style.separatorColor}` : null;
	}
}

export function cleanMnemonic(label: string): string {
	const regex = MENU_MNEMONIC_REGEX;

	const matches = regex.exec(label);
	if (!matches) {
		return label;
	}

	const mnemonicInText = matches[0].charAt(0) === '&';

	return label.replace(regex, mnemonicInText ? '$2' : '').trim();
}