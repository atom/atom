/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import 'mocha';
import * as assert from 'assert';
import { join } from 'path';
import { commands, workspace, window, Uri, ViewColumn, Range, Position } from 'vscode';

suite('commands namespace tests', () => {

	test('getCommands', function (done) {

		let p1 = commands.getCommands().then(commands => {
			let hasOneWithUnderscore = false;
			for (let command of commands) {
				if (command[0] === '_') {
					hasOneWithUnderscore = true;
					break;
				}
			}
			assert.ok(hasOneWithUnderscore);
		}, done);

		let p2 = commands.getCommands(true).then(commands => {
			let hasOneWithUnderscore = false;
			for (let command of commands) {
				if (command[0] === '_') {
					hasOneWithUnderscore = true;
					break;
				}
			}
			assert.ok(!hasOneWithUnderscore);
		}, done);

		Promise.all([p1, p2]).then(() => {
			done();
		}, done);
	});

	test('command with args', async function () {

		let args: IArguments;
		let registration = commands.registerCommand('t1', function () {
			args = arguments;
		});

		await commands.executeCommand('t1', 'start');
		registration.dispose();
		assert.ok(args!);
		assert.equal(args!.length, 1);
		assert.equal(args![0], 'start');
	});

	test('editorCommand with extra args', function () {

		let args: IArguments;
		let registration = commands.registerTextEditorCommand('t1', function () {
			args = arguments;
		});

		return workspace.openTextDocument(join(workspace.rootPath || '', './far.js')).then(doc => {
			return window.showTextDocument(doc).then(_editor => {
				return commands.executeCommand('t1', 12345, commands);
			}).then(() => {
				assert.ok(args);
				assert.equal(args.length, 4);
				assert.ok(args[2] === 12345);
				assert.ok(args[3] === commands);
				registration.dispose();
			});
		});

	});

	test('api-command: vscode.previewHtml', async function () {

		let registration = workspace.registerTextDocumentContentProvider('speciale', {
			provideTextDocumentContent(uri) {
				return `content of URI <b>${uri.toString()}</b>`;
			}
		});

		let virtualDocumentUri = Uri.parse('speciale://authority/path');
		let title = 'A title';

		const success = await commands.executeCommand('vscode.previewHtml', virtualDocumentUri, ViewColumn.Three, title);
		assert.ok(success);
		registration.dispose();

	});

	test('api-command: vscode.diff', function () {

		let registration = workspace.registerTextDocumentContentProvider('sc', {
			provideTextDocumentContent(uri) {
				return `content of URI <b>${uri.toString()}</b>#${Math.random()}`;
			}
		});


		let a = commands.executeCommand('vscode.diff', Uri.parse('sc:a'), Uri.parse('sc:b'), 'DIFF').then(value => {
			assert.ok(value === void 0);
			registration.dispose();
		});

		let b = commands.executeCommand('vscode.diff', Uri.parse('sc:a'), Uri.parse('sc:b')).then(value => {
			assert.ok(value === void 0);
			registration.dispose();
		});

		let c = commands.executeCommand('vscode.diff', Uri.parse('sc:a'), Uri.parse('sc:b'), 'Title', { selection: new Range(new Position(1, 1), new Position(1, 2)) }).then(value => {
			assert.ok(value === void 0);
			registration.dispose();
		});

		let d = commands.executeCommand('vscode.diff').then(() => assert.ok(false), () => assert.ok(true));
		let e = commands.executeCommand('vscode.diff', 1, 2, 3).then(() => assert.ok(false), () => assert.ok(true));

		return Promise.all([a, b, c, d, e]);
	});

	test('api-command: vscode.open', function () {
		let uri = Uri.file(join(workspace.rootPath || '', './image.png'));
		let a = commands.executeCommand('vscode.open', uri).then(() => assert.ok(true), () => assert.ok(false));
		let b = commands.executeCommand('vscode.open', uri, ViewColumn.Two).then(() => assert.ok(true), () => assert.ok(false));
		let c = commands.executeCommand('vscode.open').then(() => assert.ok(false), () => assert.ok(true));
		let d = commands.executeCommand('vscode.open', uri, true).then(() => assert.ok(false), () => assert.ok(true));

		return Promise.all([a, b, c, d]);
	});
});