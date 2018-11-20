/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import { URI } from 'vs/base/common/uri';
import { MainThreadDiaglogsShape, MainContext, IExtHostContext, MainThreadDialogOpenOptions, MainThreadDialogSaveOptions } from '../node/extHost.protocol';
import { extHostNamedCustomer } from 'vs/workbench/api/electron-browser/extHostCustomers';
import { forEach } from 'vs/base/common/collections';
import { IFileDialogService, IOpenDialogOptions, ISaveDialogOptions } from 'vs/platform/dialogs/common/dialogs';

@extHostNamedCustomer(MainContext.MainThreadDialogs)
export class MainThreadDialogs implements MainThreadDiaglogsShape {

	constructor(
		context: IExtHostContext,
		@IFileDialogService private readonly _fileDialogService: IFileDialogService,
	) {
		//
	}

	dispose(): void {
		//
	}

	$showOpenDialog(options: MainThreadDialogOpenOptions): Promise<URI[]> {
		return Promise.resolve(this._fileDialogService.showOpenDialog(MainThreadDialogs._convertOpenOptions(options)));
	}

	$showSaveDialog(options: MainThreadDialogSaveOptions): Promise<URI> {
		return Promise.resolve(this._fileDialogService.showSaveDialog(MainThreadDialogs._convertSaveOptions(options)));
	}

	private static _convertOpenOptions(options: MainThreadDialogOpenOptions): IOpenDialogOptions {
		const result: IOpenDialogOptions = {
			openLabel: options.openLabel,
			canSelectFiles: options.canSelectFiles || (!options.canSelectFiles && !options.canSelectFolders),
			canSelectFolders: options.canSelectFolders,
			canSelectMany: options.canSelectMany,
			defaultUri: URI.revive(options.defaultUri)
		};
		if (options.filters) {
			result.filters = [];
			forEach(options.filters, entry => result.filters.push({ name: entry.key, extensions: entry.value }));
		}
		return result;
	}

	private static _convertSaveOptions(options: MainThreadDialogSaveOptions): ISaveDialogOptions {
		const result: ISaveDialogOptions = {
			defaultUri: URI.revive(options.defaultUri),
			saveLabel: options.saveLabel
		};
		if (options.filters) {
			result.filters = [];
			forEach(options.filters, entry => result.filters.push({ name: entry.key, extensions: entry.value }));
		}
		return result;
	}
}
