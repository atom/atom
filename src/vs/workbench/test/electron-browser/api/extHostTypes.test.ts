/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import * as assert from 'assert';
import { URI } from 'vs/base/common/uri';
import * as types from 'vs/workbench/api/node/extHostTypes';
import { isWindows } from 'vs/base/common/platform';

function assertToJSON(a: any, expected: any) {
	const raw = JSON.stringify(a);
	const actual = JSON.parse(raw);
	assert.deepEqual(actual, expected);
}

suite('ExtHostTypes', function () {

	test('URI, toJSON', function () {

		let uri = URI.parse('file:///path/test.file');
		assert.deepEqual(uri.toJSON(), {
			$mid: 1,
			scheme: 'file',
			path: '/path/test.file'
		});

		assert.ok(uri.fsPath);
		assert.deepEqual(uri.toJSON(), {
			$mid: 1,
			scheme: 'file',
			path: '/path/test.file',
			fsPath: '/path/test.file'.replace(/\//g, isWindows ? '\\' : '/'),
		});

		assert.ok(uri.toString());
		assert.deepEqual(uri.toJSON(), {
			$mid: 1,
			scheme: 'file',
			path: '/path/test.file',
			fsPath: '/path/test.file'.replace(/\//g, isWindows ? '\\' : '/'),
			external: 'file:///path/test.file'
		});
	});

	test('Disposable', () => {

		let count = 0;
		let d = new types.Disposable(() => {
			count += 1;
			return 12;
		});
		d.dispose();
		assert.equal(count, 1);

		d.dispose();
		assert.equal(count, 1);

		types.Disposable.from(undefined, { dispose() { count += 1; } }).dispose();
		assert.equal(count, 2);


		assert.throws(() => {
			new types.Disposable(() => {
				throw new Error();
			}).dispose();
		});

		new types.Disposable(undefined).dispose();

	});

	test('Position', () => {
		assert.throws(() => new types.Position(-1, 0));
		assert.throws(() => new types.Position(0, -1));

		let pos = new types.Position(0, 0);
		assert.throws(() => (pos as any).line = -1);
		assert.throws(() => (pos as any).character = -1);
		assert.throws(() => (pos as any).line = 12);

		let { line, character } = pos.toJSON();
		assert.equal(line, 0);
		assert.equal(character, 0);
	});

	test('Position, toJSON', function () {
		let pos = new types.Position(4, 2);
		assertToJSON(pos, { line: 4, character: 2 });
	});

	test('Position, isBefore(OrEqual)?', function () {
		let p1 = new types.Position(1, 3);
		let p2 = new types.Position(1, 2);
		let p3 = new types.Position(0, 4);

		assert.ok(p1.isBeforeOrEqual(p1));
		assert.ok(!p1.isBefore(p1));
		assert.ok(p2.isBefore(p1));
		assert.ok(p3.isBefore(p2));
	});

	test('Position, isAfter(OrEqual)?', function () {
		let p1 = new types.Position(1, 3);
		let p2 = new types.Position(1, 2);
		let p3 = new types.Position(0, 4);

		assert.ok(p1.isAfterOrEqual(p1));
		assert.ok(!p1.isAfter(p1));
		assert.ok(p1.isAfter(p2));
		assert.ok(p2.isAfter(p3));
		assert.ok(p1.isAfter(p3));
	});

	test('Position, compareTo', function () {
		let p1 = new types.Position(1, 3);
		let p2 = new types.Position(1, 2);
		let p3 = new types.Position(0, 4);

		assert.equal(p1.compareTo(p1), 0);
		assert.equal(p2.compareTo(p1), -1);
		assert.equal(p1.compareTo(p2), 1);
		assert.equal(p2.compareTo(p3), 1);
		assert.equal(p1.compareTo(p3), 1);
	});

	test('Position, translate', function () {
		let p1 = new types.Position(1, 3);

		assert.ok(p1.translate() === p1);
		assert.ok(p1.translate({}) === p1);
		assert.ok(p1.translate(0, 0) === p1);
		assert.ok(p1.translate(0) === p1);
		assert.ok(p1.translate(undefined, 0) === p1);
		assert.ok(p1.translate(undefined) === p1);

		let res = p1.translate(-1);
		assert.equal(res.line, 0);
		assert.equal(res.character, 3);

		res = p1.translate({ lineDelta: -1 });
		assert.equal(res.line, 0);
		assert.equal(res.character, 3);

		res = p1.translate(undefined, -1);
		assert.equal(res.line, 1);
		assert.equal(res.character, 2);

		res = p1.translate({ characterDelta: -1 });
		assert.equal(res.line, 1);
		assert.equal(res.character, 2);

		res = p1.translate(11);
		assert.equal(res.line, 12);
		assert.equal(res.character, 3);

		assert.throws(() => p1.translate(null));
		assert.throws(() => p1.translate(null, null));
		assert.throws(() => p1.translate(-2));
		assert.throws(() => p1.translate({ lineDelta: -2 }));
		assert.throws(() => p1.translate(-2, null));
		assert.throws(() => p1.translate(0, -4));
	});

	test('Position, with', function () {
		let p1 = new types.Position(1, 3);

		assert.ok(p1.with() === p1);
		assert.ok(p1.with(1) === p1);
		assert.ok(p1.with(undefined, 3) === p1);
		assert.ok(p1.with(1, 3) === p1);
		assert.ok(p1.with(undefined) === p1);
		assert.ok(p1.with({ line: 1 }) === p1);
		assert.ok(p1.with({ character: 3 }) === p1);
		assert.ok(p1.with({ line: 1, character: 3 }) === p1);

		let p2 = p1.with({ line: 0, character: 11 });
		assert.equal(p2.line, 0);
		assert.equal(p2.character, 11);

		assert.throws(() => p1.with(null));
		assert.throws(() => p1.with(-9));
		assert.throws(() => p1.with(0, -9));
		assert.throws(() => p1.with({ line: -1 }));
		assert.throws(() => p1.with({ character: -1 }));
	});

	test('Range', () => {
		assert.throws(() => new types.Range(-1, 0, 0, 0));
		assert.throws(() => new types.Range(0, -1, 0, 0));
		assert.throws(() => new types.Range(new types.Position(0, 0), undefined));
		assert.throws(() => new types.Range(new types.Position(0, 0), null));
		assert.throws(() => new types.Range(undefined, new types.Position(0, 0)));
		assert.throws(() => new types.Range(null, new types.Position(0, 0)));

		let range = new types.Range(1, 0, 0, 0);
		assert.throws(() => { (range as any).start = null; });
		assert.throws(() => { (range as any).start = new types.Position(0, 3); });
	});

	test('Range, toJSON', function () {

		let range = new types.Range(1, 2, 3, 4);
		assertToJSON(range, [{ line: 1, character: 2 }, { line: 3, character: 4 }]);
	});

	test('Range, sorting', function () {
		// sorts start/end
		let range = new types.Range(1, 0, 0, 0);
		assert.equal(range.start.line, 0);
		assert.equal(range.end.line, 1);

		range = new types.Range(0, 0, 1, 0);
		assert.equal(range.start.line, 0);
		assert.equal(range.end.line, 1);
	});

	test('Range, isEmpty|isSingleLine', function () {
		let range = new types.Range(1, 0, 0, 0);
		assert.ok(!range.isEmpty);
		assert.ok(!range.isSingleLine);

		range = new types.Range(1, 1, 1, 1);
		assert.ok(range.isEmpty);
		assert.ok(range.isSingleLine);

		range = new types.Range(0, 1, 0, 11);
		assert.ok(!range.isEmpty);
		assert.ok(range.isSingleLine);

		range = new types.Range(0, 0, 1, 1);
		assert.ok(!range.isEmpty);
		assert.ok(!range.isSingleLine);
	});

	test('Range, contains', function () {
		let range = new types.Range(1, 1, 2, 11);

		assert.ok(range.contains(range.start));
		assert.ok(range.contains(range.end));
		assert.ok(range.contains(range));

		assert.ok(!range.contains(new types.Range(1, 0, 2, 11)));
		assert.ok(!range.contains(new types.Range(0, 1, 2, 11)));
		assert.ok(!range.contains(new types.Range(1, 1, 2, 12)));
		assert.ok(!range.contains(new types.Range(1, 1, 3, 11)));
	});

	test('Range, intersection', function () {
		let range = new types.Range(1, 1, 2, 11);
		let res: types.Range;

		res = range.intersection(range);
		assert.equal(res.start.line, 1);
		assert.equal(res.start.character, 1);
		assert.equal(res.end.line, 2);
		assert.equal(res.end.character, 11);

		res = range.intersection(new types.Range(2, 12, 4, 0));
		assert.equal(res, undefined);

		res = range.intersection(new types.Range(0, 0, 1, 0));
		assert.equal(res, undefined);

		res = range.intersection(new types.Range(0, 0, 1, 1));
		assert.ok(res.isEmpty);
		assert.equal(res.start.line, 1);
		assert.equal(res.start.character, 1);

		res = range.intersection(new types.Range(2, 11, 61, 1));
		assert.ok(res.isEmpty);
		assert.equal(res.start.line, 2);
		assert.equal(res.start.character, 11);

		assert.throws(() => range.intersection(null));
		assert.throws(() => range.intersection(undefined));
	});

	test('Range, union', function () {
		let ran1 = new types.Range(0, 0, 5, 5);
		assert.ok(ran1.union(new types.Range(0, 0, 1, 1)) === ran1);

		let res: types.Range;
		res = ran1.union(new types.Range(2, 2, 9, 9));
		assert.ok(res.start === ran1.start);
		assert.equal(res.end.line, 9);
		assert.equal(res.end.character, 9);

		ran1 = new types.Range(2, 1, 5, 3);
		res = ran1.union(new types.Range(1, 0, 4, 2));
		assert.ok(res.end === ran1.end);
		assert.equal(res.start.line, 1);
		assert.equal(res.start.character, 0);
	});

	test('Range, with', function () {
		let range = new types.Range(1, 1, 2, 11);

		assert.ok(range.with(range.start) === range);
		assert.ok(range.with(undefined, range.end) === range);
		assert.ok(range.with(range.start, range.end) === range);
		assert.ok(range.with(new types.Position(1, 1)) === range);
		assert.ok(range.with(undefined, new types.Position(2, 11)) === range);
		assert.ok(range.with() === range);
		assert.ok(range.with({ start: range.start }) === range);
		assert.ok(range.with({ start: new types.Position(1, 1) }) === range);
		assert.ok(range.with({ end: range.end }) === range);
		assert.ok(range.with({ end: new types.Position(2, 11) }) === range);

		let res = range.with(undefined, new types.Position(9, 8));
		assert.equal(res.end.line, 9);
		assert.equal(res.end.character, 8);
		assert.equal(res.start.line, 1);
		assert.equal(res.start.character, 1);

		res = range.with({ end: new types.Position(9, 8) });
		assert.equal(res.end.line, 9);
		assert.equal(res.end.character, 8);
		assert.equal(res.start.line, 1);
		assert.equal(res.start.character, 1);

		res = range.with({ end: new types.Position(9, 8), start: new types.Position(2, 3) });
		assert.equal(res.end.line, 9);
		assert.equal(res.end.character, 8);
		assert.equal(res.start.line, 2);
		assert.equal(res.start.character, 3);

		assert.throws(() => range.with(null));
		assert.throws(() => range.with(undefined, null));
	});

	test('TextEdit', () => {

		let range = new types.Range(1, 1, 2, 11);
		let edit = new types.TextEdit(range, undefined);
		assert.equal(edit.newText, '');
		assertToJSON(edit, { range: [{ line: 1, character: 1 }, { line: 2, character: 11 }], newText: '' });

		edit = new types.TextEdit(range, null);
		assert.equal(edit.newText, '');

		edit = new types.TextEdit(range, '');
		assert.equal(edit.newText, '');
	});

	test('WorkspaceEdit', () => {

		let a = URI.file('a.ts');
		let b = URI.file('b.ts');

		let edit = new types.WorkspaceEdit();
		assert.ok(!edit.has(a));

		edit.set(a, [types.TextEdit.insert(new types.Position(0, 0), 'fff')]);
		assert.ok(edit.has(a));
		assert.equal(edit.size, 1);
		assertToJSON(edit, [[a.toJSON(), [{ range: [{ line: 0, character: 0 }, { line: 0, character: 0 }], newText: 'fff' }]]]);

		edit.insert(b, new types.Position(1, 1), 'fff');
		edit.delete(b, new types.Range(0, 0, 0, 0));
		assert.ok(edit.has(b));
		assert.equal(edit.size, 2);
		assertToJSON(edit, [
			[a.toJSON(), [{ range: [{ line: 0, character: 0 }, { line: 0, character: 0 }], newText: 'fff' }]],
			[b.toJSON(), [{ range: [{ line: 1, character: 1 }, { line: 1, character: 1 }], newText: 'fff' }, { range: [{ line: 0, character: 0 }, { line: 0, character: 0 }], newText: '' }]]
		]);

		edit.set(b, undefined);
		assert.ok(!edit.has(b));
		assert.equal(edit.size, 1);

		edit.set(b, [types.TextEdit.insert(new types.Position(0, 0), 'ffff')]);
		assert.equal(edit.get(b).length, 1);
	});

	test('WorkspaceEdit - keep order of text and file changes', function () {

		const edit = new types.WorkspaceEdit();
		edit.replace(URI.parse('foo:a'), new types.Range(1, 1, 1, 1), 'foo');
		edit.renameFile(URI.parse('foo:a'), URI.parse('foo:b'));
		edit.replace(URI.parse('foo:a'), new types.Range(2, 1, 2, 1), 'bar');
		edit.replace(URI.parse('foo:b'), new types.Range(3, 1, 3, 1), 'bazz');

		const all = edit._allEntries();
		assert.equal(all.length, 4);

		function isFileChange(thing: [URI, types.TextEdit[]] | [URI?, URI?, { overwrite?: boolean }?]): thing is [URI?, URI?, { overwrite?: boolean }?] {
			const [f, s] = thing;
			return URI.isUri(f) && URI.isUri(s);
		}

		function isTextChange(thing: [URI, types.TextEdit[]] | [URI?, URI?, { overwrite?: boolean }?]): thing is [URI, types.TextEdit[]] {
			const [f, s] = thing;
			return URI.isUri(f) && Array.isArray(s);
		}

		const [first, second, third, fourth] = all;
		assert.equal(first[0].toString(), 'foo:a');
		assert.ok(!isFileChange(first));
		assert.ok(isTextChange(first) && first[1].length === 1);

		assert.equal(second[0].toString(), 'foo:a');
		assert.ok(isFileChange(second));

		assert.equal(third[0].toString(), 'foo:a');
		assert.ok(isTextChange(third) && third[1].length === 1);

		assert.equal(fourth[0].toString(), 'foo:b');
		assert.ok(!isFileChange(fourth));
		assert.ok(isTextChange(fourth) && fourth[1].length === 1);
	});

	test('WorkspaceEdit - two edits for one resource', function () {
		let edit = new types.WorkspaceEdit();
		let uri = URI.parse('foo:bar');
		edit.insert(uri, new types.Position(0, 0), 'Hello');
		edit.insert(uri, new types.Position(0, 0), 'Foo');

		assert.equal(edit._allEntries().length, 2);
		let [first, second] = edit._allEntries();
		assert.equal((first as [URI, types.TextEdit[]])[1][0].newText, 'Hello');
		assert.equal((second as [URI, types.TextEdit[]])[1][0].newText, 'Foo');
	});

	test('DocumentLink', () => {
		assert.throws(() => new types.DocumentLink(null, null));
		assert.throws(() => new types.DocumentLink(new types.Range(1, 1, 1, 1), null));
	});

	test('toJSON & stringify', function () {

		assertToJSON(new types.Selection(3, 4, 2, 1), { start: { line: 2, character: 1 }, end: { line: 3, character: 4 }, anchor: { line: 3, character: 4 }, active: { line: 2, character: 1 } });

		assertToJSON(new types.Location(URI.file('u.ts'), new types.Position(3, 4)), { uri: URI.parse('file:///u.ts').toJSON(), range: [{ line: 3, character: 4 }, { line: 3, character: 4 }] });
		assertToJSON(new types.Location(URI.file('u.ts'), new types.Range(1, 2, 3, 4)), { uri: URI.parse('file:///u.ts').toJSON(), range: [{ line: 1, character: 2 }, { line: 3, character: 4 }] });

		let diag = new types.Diagnostic(new types.Range(0, 1, 2, 3), 'hello');
		assertToJSON(diag, { severity: 'Error', message: 'hello', range: [{ line: 0, character: 1 }, { line: 2, character: 3 }] });
		diag.source = 'me';
		assertToJSON(diag, { severity: 'Error', message: 'hello', range: [{ line: 0, character: 1 }, { line: 2, character: 3 }], source: 'me' });

		assertToJSON(new types.DocumentHighlight(new types.Range(2, 3, 4, 5)), { range: [{ line: 2, character: 3 }, { line: 4, character: 5 }], kind: 'Text' });
		assertToJSON(new types.DocumentHighlight(new types.Range(2, 3, 4, 5), types.DocumentHighlightKind.Read), { range: [{ line: 2, character: 3 }, { line: 4, character: 5 }], kind: 'Read' });

		assertToJSON(new types.SymbolInformation('test', types.SymbolKind.Boolean, new types.Range(0, 1, 2, 3)), {
			name: 'test',
			kind: 'Boolean',
			location: {
				range: [{ line: 0, character: 1 }, { line: 2, character: 3 }]
			}
		});

		assertToJSON(new types.CodeLens(new types.Range(7, 8, 9, 10)), { range: [{ line: 7, character: 8 }, { line: 9, character: 10 }] });
		assertToJSON(new types.CodeLens(new types.Range(7, 8, 9, 10), { command: 'id', title: 'title' }), {
			range: [{ line: 7, character: 8 }, { line: 9, character: 10 }],
			command: { command: 'id', title: 'title' }
		});

		assertToJSON(new types.CompletionItem('complete'), { label: 'complete' });

		let item = new types.CompletionItem('complete');
		item.kind = types.CompletionItemKind.Interface;
		assertToJSON(item, { label: 'complete', kind: 'Interface' });

	});

	test('SymbolInformation, old ctor', function () {

		let info = new types.SymbolInformation('foo', types.SymbolKind.Array, new types.Range(1, 1, 2, 3));
		assert.ok(info.location instanceof types.Location);
		assert.equal(info.location.uri, undefined);
	});

	test('SnippetString, builder-methods', function () {

		let string: types.SnippetString;

		string = new types.SnippetString();
		assert.equal(string.appendText('I need $ and $').value, 'I need \\$ and \\$');

		string = new types.SnippetString();
		assert.equal(string.appendText('I need \\$').value, 'I need \\\\\\$');

		string = new types.SnippetString();
		string.appendPlaceholder('fo$o}');
		assert.equal(string.value, '${1:fo\\$o\\}}');

		string = new types.SnippetString();
		string.appendText('foo').appendTabstop(0).appendText('bar');
		assert.equal(string.value, 'foo$0bar');

		string = new types.SnippetString();
		string.appendText('foo').appendTabstop().appendText('bar');
		assert.equal(string.value, 'foo$1bar');

		string = new types.SnippetString();
		string.appendText('foo').appendTabstop(42).appendText('bar');
		assert.equal(string.value, 'foo$42bar');

		string = new types.SnippetString();
		string.appendText('foo').appendPlaceholder('farboo').appendText('bar');
		assert.equal(string.value, 'foo${1:farboo}bar');

		string = new types.SnippetString();
		string.appendText('foo').appendPlaceholder('far$boo').appendText('bar');
		assert.equal(string.value, 'foo${1:far\\$boo}bar');

		string = new types.SnippetString();
		string.appendText('foo').appendPlaceholder(b => b.appendText('abc').appendPlaceholder('nested')).appendText('bar');
		assert.equal(string.value, 'foo${1:abc${2:nested}}bar');

		string = new types.SnippetString();
		string.appendVariable('foo');
		assert.equal(string.value, '${foo}');

		string = new types.SnippetString();
		string.appendText('foo').appendVariable('TM_SELECTED_TEXT').appendText('bar');
		assert.equal(string.value, 'foo${TM_SELECTED_TEXT}bar');

		string = new types.SnippetString();
		string.appendVariable('BAR', b => b.appendPlaceholder('ops'));
		assert.equal(string.value, '${BAR:${1:ops}}');

		string = new types.SnippetString();
		string.appendVariable('BAR', b => { });
		assert.equal(string.value, '${BAR}');

	});

	test('instanceof doesn\'t work for FileSystemError #49386', function () {
		const error = types.FileSystemError.Unavailable('foo');
		assert.ok(error instanceof Error);
		assert.ok(error instanceof types.FileSystemError);
	});
});
