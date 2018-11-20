/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import { MainContext, MainThreadStorageShape, IMainContext, ExtHostStorageShape } from './extHost.protocol';
import { Emitter } from 'vs/base/common/event';

export interface IStorageChangeEvent {
	shared: boolean;
	key: string;
	value: object;
}

export class ExtHostStorage implements ExtHostStorageShape {

	private _proxy: MainThreadStorageShape;

	private _onDidChangeStorage = new Emitter<IStorageChangeEvent>();
	readonly onDidChangeStorage = this._onDidChangeStorage.event;

	constructor(mainContext: IMainContext) {
		this._proxy = mainContext.getProxy(MainContext.MainThreadStorage);
	}

	getValue<T>(shared: boolean, key: string, defaultValue?: T): Thenable<T> {
		return this._proxy.$getValue<T>(shared, key).then(value => value || defaultValue);
	}

	setValue(shared: boolean, key: string, value: object): Thenable<void> {
		return this._proxy.$setValue(shared, key, value);
	}

	$acceptValue(shared: boolean, key: string, value: object): void {
		this._onDidChangeStorage.fire({ shared, key, value });
	}
}
