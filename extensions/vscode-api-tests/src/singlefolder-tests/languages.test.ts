/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import * as assert from 'assert';
import { join } from 'path';
import * as vscode from 'vscode';
import { createRandomFile } from '../utils';

suite('languages namespace tests', () => {

	test('setTextDocumentLanguage -> close/open event', async function () {
		const file = await createRandomFile('foo\nbar\nbar');
		const doc = await vscode.workspace.openTextDocument(file);
		const langIdNow = doc.languageId;
		let clock = 0;

		let close = new Promise(resolve => {
			vscode.workspace.onDidCloseTextDocument(e => {
				if (e === doc) {
					assert.equal(doc.languageId, langIdNow);
					assert.equal(clock, 0);
					clock += 1;
					resolve();
				}
			});
		});
		let open = new Promise(resolve => {
			vscode.workspace.onDidOpenTextDocument(e => {
				if (e === doc) { // same instance!
					assert.equal(doc.languageId, 'json');
					assert.equal(clock, 1);
					clock += 1;
					resolve();
				}
			});
		});
		let change = vscode.languages.setTextDocumentLanguage(doc, 'json');
		await Promise.all([change, close, open]);
		assert.equal(clock, 2);
		assert.equal(doc.languageId, 'json');
	});

	test('setTextDocumentLanguage -> error when language does not exist', async function () {
		const file = await createRandomFile('foo\nbar\nbar');
		const doc = await vscode.workspace.openTextDocument(file);

		try {
			await vscode.languages.setTextDocumentLanguage(doc, 'fooLangDoesNotExist');
			assert.ok(false);
		} catch (err) {
			assert.ok(err);
		}
	});

	test('diagnostics, read & event', function () {
		let uri = vscode.Uri.file('/foo/bar.txt');
		let col1 = vscode.languages.createDiagnosticCollection('foo1');
		col1.set(uri, [new vscode.Diagnostic(new vscode.Range(0, 0, 0, 12), 'error1')]);

		let col2 = vscode.languages.createDiagnosticCollection('foo2');
		col2.set(uri, [new vscode.Diagnostic(new vscode.Range(0, 0, 0, 12), 'error1')]);

		let diag = vscode.languages.getDiagnostics(uri);
		assert.equal(diag.length, 2);

		let tuples = vscode.languages.getDiagnostics();
		let found = false;
		for (let [thisUri,] of tuples) {
			if (thisUri.toString() === uri.toString()) {
				found = true;
				break;
			}
		}
		assert.ok(tuples.length >= 1);
		assert.ok(found);
	});

	test('diagnostics & CodeActionProvider', async function () {

		class D2 extends vscode.Diagnostic {
			customProp = { complex() { } };
			constructor() {
				super(new vscode.Range(0, 2, 0, 7), 'sonntag');
			}
		}

		let diag1 = new vscode.Diagnostic(new vscode.Range(0, 0, 0, 5), 'montag');
		let diag2 = new D2();

		let ran = false;
		let uri = vscode.Uri.parse('ttt:path.far');

		let r1 = vscode.languages.registerCodeActionsProvider({ pattern: '*.far', scheme: 'ttt' }, {
			provideCodeActions(_document, _range, ctx): vscode.Command[] {

				assert.equal(ctx.diagnostics.length, 2);
				let [first, second] = ctx.diagnostics;
				assert.ok(first === diag1);
				assert.ok(second === diag2);
				assert.ok(diag2 instanceof D2);
				ran = true;
				return [];
			}
		});

		let r2 = vscode.workspace.registerTextDocumentContentProvider('ttt', {
			provideTextDocumentContent() {
				return 'this is some text';
			}
		});

		let r3 = vscode.languages.createDiagnosticCollection();
		r3.set(uri, [diag1]);

		let r4 = vscode.languages.createDiagnosticCollection();
		r4.set(uri, [diag2]);

		await vscode.workspace.openTextDocument(uri);
		await vscode.commands.executeCommand('vscode.executeCodeActionProvider', uri, new vscode.Range(0, 0, 0, 10));
		assert.ok(ran);
		vscode.Disposable.from(r1, r2, r3, r4).dispose();
	});

	test('completions with document filters', async function () {
		let ran = false;
		let uri = vscode.Uri.file(join(vscode.workspace.rootPath || '', './bower.json'));

		let jsonDocumentFilter = [{ language: 'json', pattern: '**/package.json' }, { language: 'json', pattern: '**/bower.json' }, { language: 'json', pattern: '**/.bower.json' }];

		let r1 = vscode.languages.registerCompletionItemProvider(jsonDocumentFilter, {
			provideCompletionItems: (_document: vscode.TextDocument, _position: vscode.Position, _token: vscode.CancellationToken): vscode.CompletionItem[] => {
				let proposal = new vscode.CompletionItem('foo');
				proposal.kind = vscode.CompletionItemKind.Property;
				ran = true;
				return [proposal];
			}
		});

		await vscode.workspace.openTextDocument(uri);
		const result = await vscode.commands.executeCommand<vscode.CompletionList>('vscode.executeCompletionItemProvider', uri, new vscode.Position(1, 0));
		r1.dispose();
		assert.ok(ran);
		assert.equal(result!.items[0].label, 'foo');
	});
});
