/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import { Event, Emitter, filterEvent, debounceEvent } from 'vs/base/common/event';
import { IDisposable, dispose } from 'vs/base/common/lifecycle';
import { ContextKeyExpr, IContextKeyService } from 'vs/platform/contextkey/common/contextkey';
import { MenuId, MenuRegistry, MenuItemAction, IMenu, IMenuItem, IMenuActionOptions, ISubmenuItem, SubmenuItemAction, isIMenuItem } from 'vs/platform/actions/common/actions';
import { ICommandService } from 'vs/platform/commands/common/commands';

type MenuItemGroup = [string, (IMenuItem | ISubmenuItem)[]];

export class Menu implements IMenu {

	private readonly _onDidChange = new Emitter<IMenu>();
	private readonly _disposables: IDisposable[] = [];

	private _menuGroups: MenuItemGroup[];
	private _contextKeys: Set<string>;

	constructor(
		private readonly _id: MenuId,
		@ICommandService private readonly _commandService: ICommandService,
		@IContextKeyService private readonly _contextKeyService: IContextKeyService
	) {
		this._build();

		// rebuild this menu whenever the menu registry reports an
		// event for this MenuId
		debounceEvent(
			filterEvent(MenuRegistry.onDidChangeMenu, menuId => menuId === this._id),
			() => { },
			100
		)(this._build, this, this._disposables);

		// when context keys change we need to change if the menu also
		// has changed
		this._contextKeyService.onDidChangeContext(event => {
			if (event.affectsSome(this._contextKeys)) {
				this._onDidChange.fire();
			}
		}, this, this._disposables);
	}

	private _build(): void {

		// reset
		this._menuGroups = [];
		this._contextKeys = new Set();

		const menuItems = MenuRegistry.getMenuItems(this._id);

		let group: MenuItemGroup | undefined;
		menuItems.sort(Menu._compareMenuItems);

		for (let item of menuItems) {
			// group by groupId
			const groupName = item.group || '';
			if (!group || group[0] !== groupName) {
				group = [groupName, []];
				this._menuGroups.push(group);
			}
			group![1].push(item);

			// keep keys for eventing
			Menu._fillInKbExprKeys(item.when, this._contextKeys);

			// keep precondition keys for event if applicable
			if (isIMenuItem(item) && item.command.precondition) {
				Menu._fillInKbExprKeys(item.command.precondition, this._contextKeys);
			}

			// keep toggled keys for event if applicable
			if (isIMenuItem(item) && item.command.toggled) {
				Menu._fillInKbExprKeys(item.command.toggled, this._contextKeys);
			}
		}
		this._onDidChange.fire(this);
	}

	dispose() {
		dispose(this._disposables);
		this._onDidChange.dispose();
	}

	get onDidChange(): Event<IMenu> {
		return this._onDidChange.event;
	}

	getActions(options: IMenuActionOptions): [string, (MenuItemAction | SubmenuItemAction)[]][] {
		const result: [string, (MenuItemAction | SubmenuItemAction)[]][] = [];
		for (let group of this._menuGroups) {
			const [id, items] = group;
			const activeActions: (MenuItemAction | SubmenuItemAction)[] = [];
			for (const item of items) {
				if (this._contextKeyService.contextMatchesRules(item.when || null)) {
					const action = isIMenuItem(item) ? new MenuItemAction(item.command, item.alt, options, this._contextKeyService, this._commandService) : new SubmenuItemAction(item);
					activeActions.push(action);
				}
			}
			if (activeActions.length > 0) {
				result.push([id, activeActions]);
			}
		}
		return result;
	}

	private static _fillInKbExprKeys(exp: ContextKeyExpr | undefined, set: Set<string>): void {
		if (exp) {
			for (let key of exp.keys()) {
				set.add(key);
			}
		}
	}

	private static _compareMenuItems(a: IMenuItem, b: IMenuItem): number {

		let aGroup = a.group;
		let bGroup = b.group;

		if (aGroup !== bGroup) {

			// Falsy groups come last
			if (!aGroup) {
				return 1;
			} else if (!bGroup) {
				return -1;
			}

			// 'navigation' group comes first
			if (aGroup === 'navigation') {
				return -1;
			} else if (bGroup === 'navigation') {
				return 1;
			}

			// lexical sort for groups
			let value = aGroup.localeCompare(bGroup);
			if (value !== 0) {
				return value;
			}
		}

		// sort on priority - default is 0
		let aPrio = a.order || 0;
		let bPrio = b.order || 0;
		if (aPrio < bPrio) {
			return -1;
		} else if (aPrio > bPrio) {
			return 1;
		}

		// sort on titles
		const aTitle = typeof a.command.title === 'string' ? a.command.title : a.command.title.value;
		const bTitle = typeof b.command.title === 'string' ? b.command.title : b.command.title.value;
		return aTitle.localeCompare(bTitle);
	}
}
