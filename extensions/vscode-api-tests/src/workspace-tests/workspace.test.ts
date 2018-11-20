/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import * as assert from 'assert';
import * as vscode from 'vscode';
import { closeAllEditors, pathEquals } from '../utils';
import { join } from 'path';

suite('workspace-namespace', () => {

	teardown(closeAllEditors);

	test('rootPath', () => {
		if (vscode.workspace.rootPath) {
			assert.ok(pathEquals(vscode.workspace.rootPath, join(__dirname, '../../testWorkspace')));
		}
	});

	test('workspaceFolders', () => {
		if (vscode.workspace.workspaceFolders) {
			assert.equal(vscode.workspace.workspaceFolders.length, 2);
			assert.ok(pathEquals(vscode.workspace.workspaceFolders[0].uri.fsPath, join(__dirname, '../../testWorkspace')));
			assert.ok(pathEquals(vscode.workspace.workspaceFolders[1].uri.fsPath, join(__dirname, '../../testWorkspace2')));
			assert.ok(pathEquals(vscode.workspace.workspaceFolders[1].name, 'Test Workspace 2'));
		}
	});

	test('getWorkspaceFolder', () => {
		const folder = vscode.workspace.getWorkspaceFolder(vscode.Uri.file(join(__dirname, '../../testWorkspace2/far.js')));
		assert.ok(!!folder);

		if (folder) {
			assert.ok(pathEquals(folder.uri.fsPath, join(__dirname, '../../testWorkspace2')));
		}
	});
});
