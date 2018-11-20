/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import { IAction, IActionRunner } from 'vs/base/common/actions';
import { IActionItem } from 'vs/base/browser/ui/actionbar/actionbar';
import { ResolvedKeybinding } from 'vs/base/common/keyCodes';
import { SubmenuAction } from 'vs/base/browser/ui/menu/menu';

export interface IContextMenuEvent {
	shiftKey?: boolean;
	ctrlKey?: boolean;
	altKey?: boolean;
	metaKey?: boolean;
}

export class ContextSubMenu extends SubmenuAction {
	constructor(label: string, public entries: (ContextSubMenu | IAction)[]) {
		super(label, entries, 'contextsubmenu');
	}
}

export interface IContextMenuDelegate {
	getAnchor(): HTMLElement | { x: number; y: number; width?: number; height?: number; };
	getActions(): (IAction | ContextSubMenu)[];
	getActionItem?(action: IAction): IActionItem;
	getActionsContext?(event?: IContextMenuEvent): any;
	getKeyBinding?(action: IAction): ResolvedKeybinding;
	getMenuClassName?(): string;
	onHide?(didCancel: boolean): void;
	actionRunner?: IActionRunner;
	autoSelectFirstItem?: boolean;
}
