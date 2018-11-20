/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import { IMainContext, MainContext, MainThreadClipboardShape } from 'vs/workbench/api/node/extHost.protocol';
import * as vscode from 'vscode';

export class ExtHostClipboard implements vscode.Clipboard {

	private readonly _proxy: MainThreadClipboardShape;

	constructor(mainContext: IMainContext) {
		this._proxy = mainContext.getProxy(MainContext.MainThreadClipboard);
	}

	readText(): Promise<string> {
		return this._proxy.$readText();
	}

	writeText(value: string): Promise<void> {
		return this._proxy.$writeText(value);
	}
}
