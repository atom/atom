/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import { Registry } from 'vs/platform/registry/common/platform';
import { IDisposable } from 'vs/base/common/lifecycle';
import { StatusbarAlignment } from 'vs/platform/statusbar/common/statusbar';
import { SyncDescriptor0, createSyncDescriptor } from 'vs/platform/instantiation/common/descriptors';
import { IConstructorSignature0 } from 'vs/platform/instantiation/common/instantiation';

export interface IStatusbarItem {
	render(element: HTMLElement): IDisposable;
}

export class StatusbarItemDescriptor {
	syncDescriptor: SyncDescriptor0<IStatusbarItem>;
	alignment: StatusbarAlignment;
	priority: number;

	constructor(ctor: IConstructorSignature0<IStatusbarItem>, alignment?: StatusbarAlignment, priority?: number) {
		this.syncDescriptor = createSyncDescriptor(ctor);
		this.alignment = alignment || StatusbarAlignment.LEFT;
		this.priority = priority || 0;
	}
}

export interface IStatusbarRegistry {
	registerStatusbarItem(descriptor: StatusbarItemDescriptor): void;
	items: StatusbarItemDescriptor[];
}

class StatusbarRegistry implements IStatusbarRegistry {

	private _items: StatusbarItemDescriptor[];

	constructor() {
		this._items = [];
	}

	get items(): StatusbarItemDescriptor[] {
		return this._items;
	}

	registerStatusbarItem(descriptor: StatusbarItemDescriptor): void {
		this._items.push(descriptor);
	}
}

export const Extensions = {
	Statusbar: 'workbench.contributions.statusbar'
};

Registry.add(Extensions.Statusbar, new StatusbarRegistry());
