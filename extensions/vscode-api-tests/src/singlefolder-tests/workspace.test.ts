/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import * as assert from 'assert';
import * as vscode from 'vscode';
import { createRandomFile, deleteFile, closeAllEditors, pathEquals, rndName, disposeAll } from '../utils';
import { join, posix, basename } from 'path';
import * as fs from 'fs';
import * as os from 'os';

suite('workspace-namespace', () => {

	teardown(closeAllEditors);

	test('MarkdownString', function () {
		let md = new vscode.MarkdownString();
		assert.equal(md.value, '');
		assert.equal(md.isTrusted, undefined);

		md = new vscode.MarkdownString('**bold**');
		assert.equal(md.value, '**bold**');

		md.appendText('**bold?**');
		assert.equal(md.value, '**bold**\\*\\*bold?\\*\\*');

		md.appendMarkdown('**bold**');
		assert.equal(md.value, '**bold**\\*\\*bold?\\*\\***bold**');
	});


	test('textDocuments', () => {
		assert.ok(Array.isArray(vscode.workspace.textDocuments));
		assert.throws(() => (<any>vscode.workspace).textDocuments = null);
	});

	test('rootPath', () => {
		if (vscode.workspace.rootPath) {
			assert.ok(pathEquals(vscode.workspace.rootPath, join(__dirname, '../../testWorkspace')));
		}
		assert.throws(() => vscode.workspace.rootPath = 'farboo');
	});

	test('workspaceFolders', () => {
		if (vscode.workspace.workspaceFolders) {
			assert.equal(vscode.workspace.workspaceFolders.length, 1);
			assert.ok(pathEquals(vscode.workspace.workspaceFolders[0].uri.fsPath, join(__dirname, '../../testWorkspace')));
		}
	});

	test('getWorkspaceFolder', () => {
		const folder = vscode.workspace.getWorkspaceFolder(vscode.Uri.file(join(__dirname, '../../testWorkspace/far.js')));
		assert.ok(!!folder);

		if (folder) {
			assert.ok(pathEquals(folder.uri.fsPath, join(__dirname, '../../testWorkspace')));
		}
	});

	test('openTextDocument', () => {
		let len = vscode.workspace.textDocuments.length;
		return vscode.workspace.openTextDocument(join(vscode.workspace.rootPath || '', './simple.txt')).then(doc => {
			assert.ok(doc);
			assert.equal(vscode.workspace.textDocuments.length, len + 1);
		});
	});

	test('openTextDocument, illegal path', () => {
		return vscode.workspace.openTextDocument('funkydonky.txt').then(_doc => {
			throw new Error('missing error');
		}, _err => {
			// good!
		});
	});

	test('openTextDocument, untitled is dirty', function () {
		return vscode.workspace.openTextDocument(vscode.Uri.parse('untitled:' + join(vscode.workspace.rootPath || '', './newfile.txt'))).then(doc => {
			assert.equal(doc.uri.scheme, 'untitled');
			assert.ok(doc.isDirty);
		});
	});

	test('openTextDocument, untitled with host', function () {
		const uri = vscode.Uri.parse('untitled://localhost/c%24/Users/jrieken/code/samples/foobar.txt');
		return vscode.workspace.openTextDocument(uri).then(doc => {
			assert.equal(doc.uri.scheme, 'untitled');
		});
	});

	test('openTextDocument, untitled without path', function () {
		return vscode.workspace.openTextDocument().then(doc => {
			assert.equal(doc.uri.scheme, 'untitled');
			assert.ok(doc.isDirty);
		});
	});

	test('openTextDocument, untitled without path but language ID', function () {
		return vscode.workspace.openTextDocument({ language: 'xml' }).then(doc => {
			assert.equal(doc.uri.scheme, 'untitled');
			assert.equal(doc.languageId, 'xml');
			assert.ok(doc.isDirty);
		});
	});

	test('openTextDocument, untitled without path but language ID and content', function () {
		return vscode.workspace.openTextDocument({ language: 'html', content: '<h1>Hello world!</h1>' }).then(doc => {
			assert.equal(doc.uri.scheme, 'untitled');
			assert.equal(doc.languageId, 'html');
			assert.ok(doc.isDirty);
			assert.equal(doc.getText(), '<h1>Hello world!</h1>');
		});
	});

	test('openTextDocument, untitled closes on save', function () {
		const path = join(vscode.workspace.rootPath || '', './newfile.txt');

		return vscode.workspace.openTextDocument(vscode.Uri.parse('untitled:' + path)).then(doc => {
			assert.equal(doc.uri.scheme, 'untitled');
			assert.ok(doc.isDirty);

			let closed: vscode.TextDocument;
			let d0 = vscode.workspace.onDidCloseTextDocument(e => closed = e);

			return vscode.window.showTextDocument(doc).then(() => {
				return doc.save().then(() => {
					assert.ok(closed === doc);
					assert.ok(!doc.isDirty);
					assert.ok(fs.existsSync(path));

					d0.dispose();

					return deleteFile(vscode.Uri.file(join(vscode.workspace.rootPath || '', './newfile.txt')));
				});
			});

		});
	});

	test('openTextDocument, uri scheme/auth/path', function () {

		let registration = vscode.workspace.registerTextDocumentContentProvider('sc', {
			provideTextDocumentContent() {
				return 'SC';
			}
		});

		return Promise.all([
			vscode.workspace.openTextDocument(vscode.Uri.parse('sc://auth')).then(doc => {
				assert.equal(doc.uri.authority, 'auth');
				assert.equal(doc.uri.path, '');
			}),
			vscode.workspace.openTextDocument(vscode.Uri.parse('sc:///path')).then(doc => {
				assert.equal(doc.uri.authority, '');
				assert.equal(doc.uri.path, '/path');
			}),
			vscode.workspace.openTextDocument(vscode.Uri.parse('sc://auth/path')).then(doc => {
				assert.equal(doc.uri.authority, 'auth');
				assert.equal(doc.uri.path, '/path');
			})
		]).then(() => {
			registration.dispose();
		});
	});

	test('eol, read', () => {
		const a = createRandomFile('foo\nbar\nbar').then(file => {
			return vscode.workspace.openTextDocument(file).then(doc => {
				assert.equal(doc.eol, vscode.EndOfLine.LF);
			});
		});
		const b = createRandomFile('foo\nbar\nbar\r\nbaz').then(file => {
			return vscode.workspace.openTextDocument(file).then(doc => {
				assert.equal(doc.eol, vscode.EndOfLine.LF);
			});
		});
		const c = createRandomFile('foo\r\nbar\r\nbar').then(file => {
			return vscode.workspace.openTextDocument(file).then(doc => {
				assert.equal(doc.eol, vscode.EndOfLine.CRLF);
			});
		});
		return Promise.all([a, b, c]);
	});

	test('eol, change via editor', () => {
		return createRandomFile('foo\nbar\nbar').then(file => {
			return vscode.workspace.openTextDocument(file).then(doc => {
				assert.equal(doc.eol, vscode.EndOfLine.LF);
				return vscode.window.showTextDocument(doc).then(editor => {
					return editor.edit(builder => builder.setEndOfLine(vscode.EndOfLine.CRLF));

				}).then(value => {
					assert.ok(value);
					assert.ok(doc.isDirty);
					assert.equal(doc.eol, vscode.EndOfLine.CRLF);
				});
			});
		});
	});

	test('eol, change via applyEdit', () => {
		return createRandomFile('foo\nbar\nbar').then(file => {
			return vscode.workspace.openTextDocument(file).then(doc => {
				assert.equal(doc.eol, vscode.EndOfLine.LF);

				const edit = new vscode.WorkspaceEdit();
				edit.set(file, [vscode.TextEdit.setEndOfLine(vscode.EndOfLine.CRLF)]);
				return vscode.workspace.applyEdit(edit).then(value => {
					assert.ok(value);
					assert.ok(doc.isDirty);
					assert.equal(doc.eol, vscode.EndOfLine.CRLF);
				});
			});
		});
	});

	test('eol, change via onWillSave', () => {

		let called = false;
		let sub = vscode.workspace.onWillSaveTextDocument(e => {
			called = true;
			e.waitUntil(Promise.resolve([vscode.TextEdit.setEndOfLine(vscode.EndOfLine.LF)]));
		});

		return createRandomFile('foo\r\nbar\r\nbar').then(file => {
			return vscode.workspace.openTextDocument(file).then(doc => {
				assert.equal(doc.eol, vscode.EndOfLine.CRLF);
				const edit = new vscode.WorkspaceEdit();
				edit.set(file, [vscode.TextEdit.insert(new vscode.Position(0, 0), '-changes-')]);

				return vscode.workspace.applyEdit(edit).then(success => {
					assert.ok(success);
					return doc.save();

				}).then(success => {
					assert.ok(success);
					assert.ok(called);
					assert.ok(!doc.isDirty);
					assert.equal(doc.eol, vscode.EndOfLine.LF);
					sub.dispose();
				});
			});
		});
	});

	test('events: onDidOpenTextDocument, onDidChangeTextDocument, onDidSaveTextDocument', () => {
		return createRandomFile().then(file => {
			let disposables: vscode.Disposable[] = [];

			let onDidOpenTextDocument = false;
			disposables.push(vscode.workspace.onDidOpenTextDocument(e => {
				assert.ok(pathEquals(e.uri.fsPath, file.fsPath));
				onDidOpenTextDocument = true;
			}));

			let onDidChangeTextDocument = false;
			disposables.push(vscode.workspace.onDidChangeTextDocument(e => {
				assert.ok(pathEquals(e.document.uri.fsPath, file.fsPath));
				onDidChangeTextDocument = true;
			}));

			let onDidSaveTextDocument = false;
			disposables.push(vscode.workspace.onDidSaveTextDocument(e => {
				assert.ok(pathEquals(e.uri.fsPath, file.fsPath));
				onDidSaveTextDocument = true;
			}));

			return vscode.workspace.openTextDocument(file).then(doc => {
				return vscode.window.showTextDocument(doc).then((editor) => {
					return editor.edit((builder) => {
						builder.insert(new vscode.Position(0, 0), 'Hello World');
					}).then(_applied => {
						return doc.save().then(_saved => {
							assert.ok(onDidOpenTextDocument);
							assert.ok(onDidChangeTextDocument);
							assert.ok(onDidSaveTextDocument);

							disposeAll(disposables);

							return deleteFile(file);
						});
					});
				});
			});
		});
	});

	test('openTextDocument, with selection', function () {
		return createRandomFile('foo\nbar\nbar').then(file => {
			return vscode.workspace.openTextDocument(file).then(doc => {
				return vscode.window.showTextDocument(doc, { selection: new vscode.Range(new vscode.Position(1, 1), new vscode.Position(1, 2)) }).then(editor => {
					assert.equal(editor.selection.start.line, 1);
					assert.equal(editor.selection.start.character, 1);
					assert.equal(editor.selection.end.line, 1);
					assert.equal(editor.selection.end.character, 2);
				});
			});
		});
	});

	test('registerTextDocumentContentProvider, simple', function () {

		let registration = vscode.workspace.registerTextDocumentContentProvider('foo', {
			provideTextDocumentContent(uri) {
				return uri.toString();
			}
		});

		const uri = vscode.Uri.parse('foo://testing/virtual.js');
		return vscode.workspace.openTextDocument(uri).then(doc => {
			assert.equal(doc.getText(), uri.toString());
			assert.equal(doc.isDirty, false);
			assert.equal(doc.uri.toString(), uri.toString());
			registration.dispose();
		});
	});

	test('registerTextDocumentContentProvider, constrains', function () {

		// built-in
		assert.throws(function () {
			vscode.workspace.registerTextDocumentContentProvider('untitled', { provideTextDocumentContent() { return null; } });
		});
		// built-in
		assert.throws(function () {
			vscode.workspace.registerTextDocumentContentProvider('file', { provideTextDocumentContent() { return null; } });
		});

		// missing scheme
		return vscode.workspace.openTextDocument(vscode.Uri.parse('notThere://foo/far/boo/bar')).then(() => {
			assert.ok(false, 'expected failure');
		}, _err => {
			// expected
		});
	});

	test('registerTextDocumentContentProvider, multiple', function () {

		// duplicate registration
		let registration1 = vscode.workspace.registerTextDocumentContentProvider('foo', {
			provideTextDocumentContent(uri) {
				if (uri.authority === 'foo') {
					return '1';
				}
				return undefined;
			}
		});
		let registration2 = vscode.workspace.registerTextDocumentContentProvider('foo', {
			provideTextDocumentContent(uri) {
				if (uri.authority === 'bar') {
					return '2';
				}
				return undefined;
			}
		});

		return Promise.all([
			vscode.workspace.openTextDocument(vscode.Uri.parse('foo://foo/bla')).then(doc => { assert.equal(doc.getText(), '1'); }),
			vscode.workspace.openTextDocument(vscode.Uri.parse('foo://bar/bla')).then(doc => { assert.equal(doc.getText(), '2'); })
		]).then(() => {
			registration1.dispose();
			registration2.dispose();
		});
	});

	test('registerTextDocumentContentProvider, evil provider', function () {

		// duplicate registration
		let registration1 = vscode.workspace.registerTextDocumentContentProvider('foo', {
			provideTextDocumentContent(_uri) {
				return '1';
			}
		});
		let registration2 = vscode.workspace.registerTextDocumentContentProvider('foo', {
			provideTextDocumentContent(_uri): string {
				throw new Error('fail');
			}
		});

		return vscode.workspace.openTextDocument(vscode.Uri.parse('foo://foo/bla')).then(doc => {
			assert.equal(doc.getText(), '1');
			registration1.dispose();
			registration2.dispose();
		});
	});

	test('registerTextDocumentContentProvider, invalid text', function () {

		let registration = vscode.workspace.registerTextDocumentContentProvider('foo', {
			provideTextDocumentContent(_uri) {
				return <any>123;
			}
		});
		return vscode.workspace.openTextDocument(vscode.Uri.parse('foo://auth/path')).then(() => {
			assert.ok(false, 'expected failure');
		}, _err => {
			// expected
			registration.dispose();
		});
	});

	test('registerTextDocumentContentProvider, show virtual document', function () {

		let registration = vscode.workspace.registerTextDocumentContentProvider('foo', {
			provideTextDocumentContent(_uri) {
				return 'I am virtual';
			}
		});

		return vscode.workspace.openTextDocument(vscode.Uri.parse('foo://something/path')).then(doc => {
			return vscode.window.showTextDocument(doc).then(editor => {

				assert.ok(editor.document === doc);
				assert.equal(editor.document.getText(), 'I am virtual');
				registration.dispose();
			});
		});
	});

	test('registerTextDocumentContentProvider, open/open document', function () {

		let callCount = 0;
		let registration = vscode.workspace.registerTextDocumentContentProvider('foo', {
			provideTextDocumentContent(_uri) {
				callCount += 1;
				return 'I am virtual';
			}
		});

		const uri = vscode.Uri.parse('foo://testing/path');

		return Promise.all([vscode.workspace.openTextDocument(uri), vscode.workspace.openTextDocument(uri)]).then(docs => {
			let [first, second] = docs;
			assert.ok(first === second);
			assert.ok(vscode.workspace.textDocuments.some(doc => doc.uri.toString() === uri.toString()));
			assert.equal(callCount, 1);
			registration.dispose();
		});
	});

	test('registerTextDocumentContentProvider, empty doc', function () {

		let registration = vscode.workspace.registerTextDocumentContentProvider('foo', {
			provideTextDocumentContent(_uri) {
				return '';
			}
		});

		const uri = vscode.Uri.parse('foo:doc/empty');

		return vscode.workspace.openTextDocument(uri).then(doc => {
			assert.equal(doc.getText(), '');
			assert.equal(doc.uri.toString(), uri.toString());
			registration.dispose();
		});
	});

	test('registerTextDocumentContentProvider, change event', async function () {

		let callCount = 0;
		let emitter = new vscode.EventEmitter<vscode.Uri>();

		let registration = vscode.workspace.registerTextDocumentContentProvider('foo', {
			onDidChange: emitter.event,
			provideTextDocumentContent(_uri) {
				return 'call' + (callCount++);
			}
		});

		const uri = vscode.Uri.parse('foo://testing/path3');
		const doc = await vscode.workspace.openTextDocument(uri);

		assert.equal(callCount, 1);
		assert.equal(doc.getText(), 'call0');

		return new Promise(resolve => {

			let subscription = vscode.workspace.onDidChangeTextDocument(event => {
				assert.ok(event.document === doc);
				assert.equal(event.document.getText(), 'call1');
				subscription.dispose();
				registration.dispose();
				resolve();
			});

			emitter.fire(doc.uri);
		});
	});

	test('findFiles', () => {
		return vscode.workspace.findFiles('*.js').then((res) => {
			assert.equal(res.length, 1);
			assert.equal(basename(vscode.workspace.asRelativePath(res[0])), 'far.js');
		});
	});

	test('findFiles, cancellation', () => {

		const source = new vscode.CancellationTokenSource();
		const token = source.token; // just to get an instance first
		source.cancel();

		return vscode.workspace.findFiles('*.js', null, 100, token).then((res) => {
			assert.deepEqual(res, []);
		});
	});

	test('findTextInFiles', async () => {
		const options: vscode.FindTextInFilesOptions = {
			include: '*.ts',
			previewOptions: {
				matchLines: 1,
				charsPerLine: 100
			}
		};

		const results: vscode.TextSearchResult[] = [];
		await vscode.workspace.findTextInFiles({ pattern: 'foo' }, options, result => {
			results.push(result);
		});

		assert.equal(results.length, 1);
		const match = <vscode.TextSearchMatch>results[0];
		assert(match.preview.text.indexOf('foo') >= 0);
		assert.equal(vscode.workspace.asRelativePath(match.uri), '10linefile.ts');
	});

	test('findTextInFiles, cancellation', async () => {
		const results: vscode.TextSearchResult[] = [];
		const cancellation = new vscode.CancellationTokenSource();
		cancellation.cancel();

		await vscode.workspace.findTextInFiles({ pattern: 'foo' }, result => {
			results.push(result);
		}, cancellation.token);
	});

	test('applyEdit', () => {

		return vscode.workspace.openTextDocument(vscode.Uri.parse('untitled:' + join(vscode.workspace.rootPath || '', './new2.txt'))).then(doc => {
			let edit = new vscode.WorkspaceEdit();
			edit.insert(doc.uri, new vscode.Position(0, 0), new Array(1000).join('Hello World'));
			return vscode.workspace.applyEdit(edit);
		});
	});

	test('applyEdit should fail when editing deleted resource', async () => {
		const resource = await createRandomFile();

		const edit = new vscode.WorkspaceEdit();
		edit.deleteFile(resource);
		edit.insert(resource, new vscode.Position(0, 0), '');

		let success = await vscode.workspace.applyEdit(edit);
		assert.equal(success, false);
	});

	test('applyEdit should fail when renaming deleted resource', async () => {
		const resource = await createRandomFile();

		const edit = new vscode.WorkspaceEdit();
		edit.deleteFile(resource);
		edit.renameFile(resource, resource);

		let success = await vscode.workspace.applyEdit(edit);
		assert.equal(success, false);
	});

	test('applyEdit should fail when editing renamed from resource', async () => {
		const resource = await createRandomFile();
		const newResource = vscode.Uri.parse(resource.fsPath + '.1');
		const edit = new vscode.WorkspaceEdit();
		edit.renameFile(resource, newResource);
		edit.insert(resource, new vscode.Position(0, 0), '');

		let success = await vscode.workspace.applyEdit(edit);
		assert.equal(success, false);
	});

	test('applyEdit "edit A -> rename A to B -> edit B"', async () => {
		const oldUri = await createRandomFile();
		const newUri = oldUri.with({ path: oldUri.path + 'NEW' });
		const edit = new vscode.WorkspaceEdit();
		edit.insert(oldUri, new vscode.Position(0, 0), 'BEFORE');
		edit.renameFile(oldUri, newUri);
		edit.insert(newUri, new vscode.Position(0, 0), 'AFTER');

		let success = await vscode.workspace.applyEdit(edit);
		assert.equal(success, true);

		let doc = await vscode.workspace.openTextDocument(newUri);
		assert.equal(doc.getText(), 'AFTERBEFORE');
	});

	function nameWithUnderscore(uri: vscode.Uri) {
		return uri.with({ path: posix.join(posix.dirname(uri.path), `_${posix.basename(uri.path)}`) });
	}

	test('WorkspaceEdit: applying edits before and after rename duplicates resource #42633', async function () {
		let docUri = await createRandomFile();
		let newUri = nameWithUnderscore(docUri);

		let we = new vscode.WorkspaceEdit();
		we.insert(docUri, new vscode.Position(0, 0), 'Hello');
		we.insert(docUri, new vscode.Position(0, 0), 'Foo');
		we.renameFile(docUri, newUri);
		we.insert(newUri, new vscode.Position(0, 0), 'Bar');

		assert.ok(await vscode.workspace.applyEdit(we));
		let doc = await vscode.workspace.openTextDocument(newUri);
		assert.equal(doc.getText(), 'BarHelloFoo');
	});

	test('WorkspaceEdit: Problem recreating a renamed resource #42634', async function () {
		let docUri = await createRandomFile();
		let newUri = nameWithUnderscore(docUri);

		let we = new vscode.WorkspaceEdit();
		we.insert(docUri, new vscode.Position(0, 0), 'Hello');
		we.insert(docUri, new vscode.Position(0, 0), 'Foo');
		we.renameFile(docUri, newUri);

		we.createFile(docUri);
		we.insert(docUri, new vscode.Position(0, 0), 'Bar');

		assert.ok(await vscode.workspace.applyEdit(we));

		let newDoc = await vscode.workspace.openTextDocument(newUri);
		assert.equal(newDoc.getText(), 'HelloFoo');
		let doc = await vscode.workspace.openTextDocument(docUri);
		assert.equal(doc.getText(), 'Bar');
	});

	test('WorkspaceEdit api - after saving a deleted file, it still shows up as deleted. #42667', async function () {
		let docUri = await createRandomFile();
		let we = new vscode.WorkspaceEdit();
		we.deleteFile(docUri);
		we.insert(docUri, new vscode.Position(0, 0), 'InsertText');

		assert.ok(!(await vscode.workspace.applyEdit(we)));
		try {
			await vscode.workspace.openTextDocument(docUri);
			assert.ok(false);
		} catch (e) {
			assert.ok(true);
		}
	});

	test('WorkspaceEdit: edit and rename parent folder duplicates resource #42641', async function () {

		let dir = join(os.tmpdir(), 'before-' + rndName());
		if (!fs.existsSync(dir)) {
			fs.mkdirSync(dir);
		}

		let docUri = await createRandomFile('', dir);
		let docParent = docUri.with({ path: posix.dirname(docUri.path) });
		let newParent = nameWithUnderscore(docParent);

		let we = new vscode.WorkspaceEdit();
		we.insert(docUri, new vscode.Position(0, 0), 'Hello');
		we.renameFile(docParent, newParent);

		assert.ok(await vscode.workspace.applyEdit(we));

		try {
			await vscode.workspace.openTextDocument(docUri);
			assert.ok(false);
		} catch (e) {
			assert.ok(true);
		}

		let newUri = newParent.with({ path: posix.join(newParent.path, posix.basename(docUri.path)) });
		let doc = await vscode.workspace.openTextDocument(newUri);
		assert.ok(doc);

		assert.equal(doc.getText(), 'Hello');
	});

	test('WorkspaceEdit: rename resource followed by edit does not work #42638', async function () {
		let docUri = await createRandomFile();
		let newUri = nameWithUnderscore(docUri);

		let we = new vscode.WorkspaceEdit();
		we.renameFile(docUri, newUri);
		we.insert(newUri, new vscode.Position(0, 0), 'Hello');

		assert.ok(await vscode.workspace.applyEdit(we));

		let doc = await vscode.workspace.openTextDocument(newUri);
		assert.equal(doc.getText(), 'Hello');
	});

	test('WorkspaceEdit: create & override', async function () {

		let docUri = await createRandomFile('before');

		let we = new vscode.WorkspaceEdit();
		we.createFile(docUri);
		assert.ok(!await vscode.workspace.applyEdit(we));
		assert.equal((await vscode.workspace.openTextDocument(docUri)).getText(), 'before');

		we = new vscode.WorkspaceEdit();
		we.createFile(docUri, { overwrite: true });
		assert.ok(await vscode.workspace.applyEdit(we));
		assert.equal((await vscode.workspace.openTextDocument(docUri)).getText(), '');
	});

	test('WorkspaceEdit: create & ignoreIfExists', async function () {
		let docUri = await createRandomFile('before');

		let we = new vscode.WorkspaceEdit();
		we.createFile(docUri, { ignoreIfExists: true });
		assert.ok(await vscode.workspace.applyEdit(we));
		assert.equal((await vscode.workspace.openTextDocument(docUri)).getText(), 'before');

		we = new vscode.WorkspaceEdit();
		we.createFile(docUri, { overwrite: true, ignoreIfExists: true });
		assert.ok(await vscode.workspace.applyEdit(we));
		assert.equal((await vscode.workspace.openTextDocument(docUri)).getText(), '');
	});

	test('WorkspaceEdit: rename & ignoreIfExists', async function () {
		let aUri = await createRandomFile('aaa');
		let bUri = await createRandomFile('bbb');

		let we = new vscode.WorkspaceEdit();
		we.renameFile(aUri, bUri);
		assert.ok(!await vscode.workspace.applyEdit(we));

		we = new vscode.WorkspaceEdit();
		we.renameFile(aUri, bUri, { ignoreIfExists: true });
		assert.ok(await vscode.workspace.applyEdit(we));

		we = new vscode.WorkspaceEdit();
		we.renameFile(aUri, bUri, { overwrite: false, ignoreIfExists: true });
		assert.ok(!await vscode.workspace.applyEdit(we));

		we = new vscode.WorkspaceEdit();
		we.renameFile(aUri, bUri, { overwrite: true, ignoreIfExists: true });
		assert.ok(await vscode.workspace.applyEdit(we));
	});

	test('WorkspaceEdit: delete & ignoreIfNotExists', async function () {

		let docUri = await createRandomFile();
		let we = new vscode.WorkspaceEdit();
		we.deleteFile(docUri, { ignoreIfNotExists: false });
		assert.ok(await vscode.workspace.applyEdit(we));

		we = new vscode.WorkspaceEdit();
		we.deleteFile(docUri, { ignoreIfNotExists: false });
		assert.ok(!await vscode.workspace.applyEdit(we));

		we = new vscode.WorkspaceEdit();
		we.deleteFile(docUri, { ignoreIfNotExists: true });
		assert.ok(await vscode.workspace.applyEdit(we));
	});
});
