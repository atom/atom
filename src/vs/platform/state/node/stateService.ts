/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import * as path from 'path';
import * as fs from 'fs';
import { IEnvironmentService } from 'vs/platform/environment/common/environment';
import { writeFileAndFlushSync } from 'vs/base/node/extfs';
import { isUndefined, isUndefinedOrNull } from 'vs/base/common/types';
import { IStateService } from 'vs/platform/state/common/state';
import { ILogService } from 'vs/platform/log/common/log';

export class FileStorage {

	private _lazyDatabase: object | null = null;

	constructor(private dbPath: string, private onError: (error) => void) { }

	private get database(): object {
		if (!this._lazyDatabase) {
			this._lazyDatabase = this.loadSync();
		}
		return this._lazyDatabase;
	}

	getItem<T>(key: string, defaultValue: T): T;
	getItem<T>(key: string, defaultValue?: T): T | undefined;
	getItem<T>(key: string, defaultValue?: T): T | undefined {
		const res = this.database[key];
		if (isUndefinedOrNull(res)) {
			return defaultValue;
		}

		return res;
	}

	setItem(key: string, data: any): void {
		// Remove an item when it is undefined or null
		if (isUndefinedOrNull(data)) {
			return this.removeItem(key);
		}

		// Shortcut for primitives that did not change
		if (typeof data === 'string' || typeof data === 'number' || typeof data === 'boolean') {
			if (this.database[key] === data) {
				return;
			}
		}

		this.database[key] = data;
		this.saveSync();
	}

	removeItem(key: string): void {
		// Only update if the key is actually present (not undefined)
		if (!isUndefined(this.database[key])) {
			this.database[key] = void 0;
			this.saveSync();
		}
	}

	private loadSync(): object {
		try {
			return JSON.parse(fs.readFileSync(this.dbPath).toString()); // invalid JSON or permission issue can happen here
		} catch (error) {
			if (error && error.code !== 'ENOENT') {
				this.onError(error);
			}

			return {};
		}
	}

	private saveSync(): void {
		try {
			writeFileAndFlushSync(this.dbPath, JSON.stringify(this.database, null, 4)); // permission issue can happen here
		} catch (error) {
			this.onError(error);
		}
	}
}

export class StateService implements IStateService {

	_serviceBrand: any;

	private fileStorage: FileStorage;

	constructor(@IEnvironmentService environmentService: IEnvironmentService, @ILogService logService: ILogService) {
		this.fileStorage = new FileStorage(path.join(environmentService.userDataPath, 'storage.json'), error => logService.error(error));
	}

	getItem<T>(key: string, defaultValue: T): T;
	getItem<T>(key: string, defaultValue: T | undefined): T | undefined;
	getItem<T>(key: string, defaultValue?: T): T | undefined {
		return this.fileStorage.getItem(key, defaultValue);
	}

	setItem(key: string, data: any): void {
		this.fileStorage.setItem(key, data);
	}

	removeItem(key: string): void {
		this.fileStorage.removeItem(key);
	}
}
