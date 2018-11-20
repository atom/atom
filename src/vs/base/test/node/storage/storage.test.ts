/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import { Storage, SQLiteStorageImpl, IStorageOptions } from 'vs/base/node/storage';
import { generateUuid } from 'vs/base/common/uuid';
import { join } from 'path';
import { tmpdir } from 'os';
import { equal, ok } from 'assert';
import { mkdirp, del, exists, unlink, writeFile } from 'vs/base/node/pfs';
import { timeout } from 'vs/base/common/async';

suite('Storage Library', () => {

	function uniqueStorageDir(): string {
		const id = generateUuid();

		return join(tmpdir(), 'vsctests', id, 'storage2', id);
	}

	test('basics', async () => {
		const storageDir = uniqueStorageDir();
		await mkdirp(storageDir);

		const storage = new Storage({ path: join(storageDir, 'storage.db') });

		await storage.init();

		// Empty fallbacks
		equal(storage.get('foo', 'bar'), 'bar');
		equal(storage.getInteger('foo', 55), 55);
		equal(storage.getBoolean('foo', true), true);

		let changes = new Set<string>();
		storage.onDidChangeStorage(key => {
			changes.add(key);
		});

		// Simple updates
		const set1Promise = storage.set('bar', 'foo');
		const set2Promise = storage.set('barNumber', 55);
		const set3Promise = storage.set('barBoolean', true);

		equal(storage.get('bar'), 'foo');
		equal(storage.getInteger('barNumber'), 55);
		equal(storage.getBoolean('barBoolean'), true);

		equal(changes.size, 3);
		ok(changes.has('bar'));
		ok(changes.has('barNumber'));
		ok(changes.has('barBoolean'));

		let setPromiseResolved = false;
		await Promise.all([set1Promise, set2Promise, set3Promise]).then(() => setPromiseResolved = true);
		equal(setPromiseResolved, true);

		changes = new Set<string>();

		// Does not trigger events for same update values
		storage.set('bar', 'foo');
		storage.set('barNumber', 55);
		storage.set('barBoolean', true);
		equal(changes.size, 0);

		// Simple deletes
		const delete1Promise = storage.delete('bar');
		const delete2Promise = storage.delete('barNumber');
		const delete3Promise = storage.delete('barBoolean');

		ok(!storage.get('bar'));
		ok(!storage.getInteger('barNumber'));
		ok(!storage.getBoolean('barBoolean'));

		equal(changes.size, 3);
		ok(changes.has('bar'));
		ok(changes.has('barNumber'));
		ok(changes.has('barBoolean'));

		changes = new Set<string>();

		// Does not trigger events for same delete values
		storage.delete('bar');
		storage.delete('barNumber');
		storage.delete('barBoolean');
		equal(changes.size, 0);

		let deletePromiseResolved = false;
		await Promise.all([delete1Promise, delete2Promise, delete3Promise]).then(() => deletePromiseResolved = true);
		equal(deletePromiseResolved, true);

		await storage.close();
		await del(storageDir, tmpdir());
	});

	test('close flushes data', async () => {
		const storageDir = uniqueStorageDir();
		await mkdirp(storageDir);

		let storage = new Storage({ path: join(storageDir, 'storage.db') });
		await storage.init();

		const set1Promise = storage.set('foo', 'bar');
		const set2Promise = storage.set('bar', 'foo');

		equal(storage.get('foo'), 'bar');
		equal(storage.get('bar'), 'foo');

		let setPromiseResolved = false;
		Promise.all([set1Promise, set2Promise]).then(() => setPromiseResolved = true);

		await storage.close();

		equal(setPromiseResolved, true);

		storage = new Storage({ path: join(storageDir, 'storage.db') });
		await storage.init();

		equal(storage.get('foo'), 'bar');
		equal(storage.get('bar'), 'foo');

		await storage.close();

		storage = new Storage({ path: join(storageDir, 'storage.db') });
		await storage.init();

		const delete1Promise = storage.delete('foo');
		const delete2Promise = storage.delete('bar');

		ok(!storage.get('foo'));
		ok(!storage.get('bar'));

		let deletePromiseResolved = false;
		Promise.all([delete1Promise, delete2Promise]).then(() => deletePromiseResolved = true);

		await storage.close();

		equal(deletePromiseResolved, true);

		storage = new Storage({ path: join(storageDir, 'storage.db') });
		await storage.init();

		ok(!storage.get('foo'));
		ok(!storage.get('bar'));

		await storage.close();
		await del(storageDir, tmpdir());
	});

	test('conflicting updates', async () => {
		const storageDir = uniqueStorageDir();
		await mkdirp(storageDir);

		let storage = new Storage({ path: join(storageDir, 'storage.db') });
		await storage.init();

		let changes = new Set<string>();
		storage.onDidChangeStorage(key => {
			changes.add(key);
		});

		const set1Promise = storage.set('foo', 'bar1');
		const set2Promise = storage.set('foo', 'bar2');
		const set3Promise = storage.set('foo', 'bar3');

		equal(storage.get('foo'), 'bar3');
		equal(changes.size, 1);
		ok(changes.has('foo'));

		let setPromiseResolved = false;
		await Promise.all([set1Promise, set2Promise, set3Promise]).then(() => setPromiseResolved = true);
		ok(setPromiseResolved);

		changes = new Set<string>();

		const set4Promise = storage.set('bar', 'foo');
		const delete1Promise = storage.delete('bar');

		ok(!storage.get('bar'));

		equal(changes.size, 1);
		ok(changes.has('bar'));

		let setAndDeletePromiseResolved = false;
		await Promise.all([set4Promise, delete1Promise]).then(() => setAndDeletePromiseResolved = true);
		ok(setAndDeletePromiseResolved);

		await storage.close();
		await del(storageDir, tmpdir());
	});
});

suite('SQLite Storage Library', () => {

	function uniqueStorageDir(): string {
		const id = generateUuid();

		return join(tmpdir(), 'vsctests', id, 'storage', id);
	}

	function toSet(elements: string[]): Set<string> {
		const set = new Set<string>();
		elements.forEach(element => set.add(element));

		return set;
	}

	async function testDBBasics(path, logError?: (error) => void) {
		const options: IStorageOptions = { path };
		if (logError) {
			options.logging = {
				logError
			};
		}

		const storage = new SQLiteStorageImpl(options);

		const items = new Map<string, string>();
		items.set('foo', 'bar');
		items.set('some/foo/path', 'some/bar/path');
		items.set(JSON.stringify({ foo: 'bar' }), JSON.stringify({ bar: 'foo' }));

		let storedItems = await storage.getItems();
		equal(storedItems.size, 0);

		await storage.updateItems({ insert: items });

		storedItems = await storage.getItems();
		equal(storedItems.size, items.size);
		equal(storedItems.get('foo'), 'bar');
		equal(storedItems.get('some/foo/path'), 'some/bar/path');
		equal(storedItems.get(JSON.stringify({ foo: 'bar' })), JSON.stringify({ bar: 'foo' }));

		await storage.updateItems({ delete: toSet(['foo']) });
		storedItems = await storage.getItems();
		equal(storedItems.size, items.size - 1);
		ok(!storedItems.has('foo'));
		equal(storedItems.get('some/foo/path'), 'some/bar/path');
		equal(storedItems.get(JSON.stringify({ foo: 'bar' })), JSON.stringify({ bar: 'foo' }));

		await storage.updateItems({ insert: items });
		storedItems = await storage.getItems();
		equal(storedItems.size, items.size);
		equal(storedItems.get('foo'), 'bar');
		equal(storedItems.get('some/foo/path'), 'some/bar/path');
		equal(storedItems.get(JSON.stringify({ foo: 'bar' })), JSON.stringify({ bar: 'foo' }));

		const itemsChange = new Map<string, string>();
		itemsChange.set('foo', 'otherbar');
		await storage.updateItems({ insert: itemsChange });

		storedItems = await storage.getItems();
		equal(storedItems.get('foo'), 'otherbar');

		await storage.updateItems({ delete: toSet(['foo', 'bar', 'some/foo/path', JSON.stringify({ foo: 'bar' })]) });
		storedItems = await storage.getItems();
		equal(storedItems.size, 0);

		await storage.updateItems({ insert: items, delete: toSet(['foo', 'some/foo/path', 'other']) });
		storedItems = await storage.getItems();
		equal(storedItems.size, 1);
		equal(storedItems.get(JSON.stringify({ foo: 'bar' })), JSON.stringify({ bar: 'foo' }));

		await storage.updateItems({ delete: toSet([JSON.stringify({ foo: 'bar' })]) });
		storedItems = await storage.getItems();
		equal(storedItems.size, 0);

		await storage.close();
	}

	test('basics', async () => {
		const storageDir = uniqueStorageDir();

		await mkdirp(storageDir);

		testDBBasics(join(storageDir, 'storage.db'));

		await del(storageDir, tmpdir());
	});

	test('basics (open multiple times)', async () => {
		const storageDir = uniqueStorageDir();

		await mkdirp(storageDir);

		await testDBBasics(join(storageDir, 'storage.db'));
		await testDBBasics(join(storageDir, 'storage.db'));

		await del(storageDir, tmpdir());
	});

	test('basics (broken DB falls back to empty DB)', async () => {
		let expectedError: any;

		const brokenDBPath = join(__dirname, 'broken.db');
		if (await exists(brokenDBPath)) {
			await unlink(brokenDBPath); // cleanup previous run
		}

		await writeFile(brokenDBPath, 'This is a broken DB');

		await testDBBasics(brokenDBPath, error => {
			expectedError = error;
		});

		ok(expectedError);
	});

	test('real world example', async () => {
		const storageDir = uniqueStorageDir();

		await mkdirp(storageDir);

		let storage = new SQLiteStorageImpl({
			path: join(storageDir, 'storage.db')
		});

		const items1 = new Map<string, string>();
		items1.set('colorthemedata', '{"id":"vs vscode-theme-defaults-themes-light_plus-json","label":"Light+ (default light)","settingsId":"Default Light+","selector":"vs.vscode-theme-defaults-themes-light_plus-json","themeTokenColors":[{"settings":{"foreground":"#000000ff","background":"#ffffffff"}},{"scope":["meta.embedded","source.groovy.embedded"],"settings":{"foreground":"#000000ff"}},{"scope":"emphasis","settings":{"fontStyle":"italic"}},{"scope":"strong","settings":{"fontStyle":"bold"}},{"scope":"meta.diff.header","settings":{"foreground":"#000080"}},{"scope":"comment","settings":{"foreground":"#008000"}},{"scope":"constant.language","settings":{"foreground":"#0000ff"}},{"scope":["constant.numeric"],"settings":{"foreground":"#09885a"}},{"scope":"constant.regexp","settings":{"foreground":"#811f3f"}},{"name":"css tags in selectors, xml tags","scope":"entity.name.tag","settings":{"foreground":"#800000"}},{"scope":"entity.name.selector","settings":{"foreground":"#800000"}},{"scope":"entity.other.attribute-name","settings":{"foreground":"#ff0000"}},{"scope":["entity.other.attribute-name.class.css","entity.other.attribute-name.class.mixin.css","entity.other.attribute-name.id.css","entity.other.attribute-name.parent-selector.css","entity.other.attribute-name.pseudo-class.css","entity.other.attribute-name.pseudo-element.css","source.css.less entity.other.attribute-name.id","entity.other.attribute-name.attribute.scss","entity.other.attribute-name.scss"],"settings":{"foreground":"#800000"}},{"scope":"invalid","settings":{"foreground":"#cd3131"}},{"scope":"markup.underline","settings":{"fontStyle":"underline"}},{"scope":"markup.bold","settings":{"fontStyle":"bold","foreground":"#000080"}},{"scope":"markup.heading","settings":{"fontStyle":"bold","foreground":"#800000"}},{"scope":"markup.italic","settings":{"fontStyle":"italic"}},{"scope":"markup.inserted","settings":{"foreground":"#09885a"}},{"scope":"markup.deleted","settings":{"foreground":"#a31515"}},{"scope":"markup.changed","settings":{"foreground":"#0451a5"}},{"scope":["punctuation.definition.quote.begin.markdown","punctuation.definition.list.begin.markdown"],"settings":{"foreground":"#0451a5"}},{"scope":"markup.inline.raw","settings":{"foreground":"#800000"}},{"name":"brackets of XML/HTML tags","scope":"punctuation.definition.tag","settings":{"foreground":"#800000"}},{"scope":"meta.preprocessor","settings":{"foreground":"#0000ff"}},{"scope":"meta.preprocessor.string","settings":{"foreground":"#a31515"}},{"scope":"meta.preprocessor.numeric","settings":{"foreground":"#09885a"}},{"scope":"meta.structure.dictionary.key.python","settings":{"foreground":"#0451a5"}},{"scope":"storage","settings":{"foreground":"#0000ff"}},{"scope":"storage.type","settings":{"foreground":"#0000ff"}},{"scope":"storage.modifier","settings":{"foreground":"#0000ff"}},{"scope":"string","settings":{"foreground":"#a31515"}},{"scope":["string.comment.buffered.block.pug","string.quoted.pug","string.interpolated.pug","string.unquoted.plain.in.yaml","string.unquoted.plain.out.yaml","string.unquoted.block.yaml","string.quoted.single.yaml","string.quoted.double.xml","string.quoted.single.xml","string.unquoted.cdata.xml","string.quoted.double.html","string.quoted.single.html","string.unquoted.html","string.quoted.single.handlebars","string.quoted.double.handlebars"],"settings":{"foreground":"#0000ff"}},{"scope":"string.regexp","settings":{"foreground":"#811f3f"}},{"name":"String interpolation","scope":["punctuation.definition.template-expression.begin","punctuation.definition.template-expression.end","punctuation.section.embedded"],"settings":{"foreground":"#0000ff"}},{"name":"Reset JavaScript string interpolation expression","scope":["meta.template.expression"],"settings":{"foreground":"#000000"}},{"scope":["support.constant.property-value","support.constant.font-name","support.constant.media-type","support.constant.media","constant.other.color.rgb-value","constant.other.rgb-value","support.constant.color"],"settings":{"foreground":"#0451a5"}},{"scope":["support.type.vendored.property-name","support.type.property-name","variable.css","variable.scss","variable.other.less","source.coffee.embedded"],"settings":{"foreground":"#ff0000"}},{"scope":["support.type.property-name.json"],"settings":{"foreground":"#0451a5"}},{"scope":"keyword","settings":{"foreground":"#0000ff"}},{"scope":"keyword.control","settings":{"foreground":"#0000ff"}},{"scope":"keyword.operator","settings":{"foreground":"#000000"}},{"scope":["keyword.operator.new","keyword.operator.expression","keyword.operator.cast","keyword.operator.sizeof","keyword.operator.instanceof","keyword.operator.logical.python"],"settings":{"foreground":"#0000ff"}},{"scope":"keyword.other.unit","settings":{"foreground":"#09885a"}},{"scope":["punctuation.section.embedded.begin.php","punctuation.section.embedded.end.php"],"settings":{"foreground":"#800000"}},{"scope":"support.function.git-rebase","settings":{"foreground":"#0451a5"}},{"scope":"constant.sha.git-rebase","settings":{"foreground":"#09885a"}},{"name":"coloring of the Java import and package identifiers","scope":["storage.modifier.import.java","variable.language.wildcard.java","storage.modifier.package.java"],"settings":{"foreground":"#000000"}},{"name":"this.self","scope":"variable.language","settings":{"foreground":"#0000ff"}},{"name":"Function declarations","scope":["entity.name.function","support.function","support.constant.handlebars"],"settings":{"foreground":"#795E26"}},{"name":"Types declaration and references","scope":["meta.return-type","support.class","support.type","entity.name.type","entity.name.class","storage.type.numeric.go","storage.type.byte.go","storage.type.boolean.go","storage.type.string.go","storage.type.uintptr.go","storage.type.error.go","storage.type.rune.go","storage.type.cs","storage.type.generic.cs","storage.type.modifier.cs","storage.type.variable.cs","storage.type.annotation.java","storage.type.generic.java","storage.type.java","storage.type.object.array.java","storage.type.primitive.array.java","storage.type.primitive.java","storage.type.token.java","storage.type.groovy","storage.type.annotation.groovy","storage.type.parameters.groovy","storage.type.generic.groovy","storage.type.object.array.groovy","storage.type.primitive.array.groovy","storage.type.primitive.groovy"],"settings":{"foreground":"#267f99"}},{"name":"Types declaration and references, TS grammar specific","scope":["meta.type.cast.expr","meta.type.new.expr","support.constant.math","support.constant.dom","support.constant.json","entity.other.inherited-class"],"settings":{"foreground":"#267f99"}},{"name":"Control flow keywords","scope":"keyword.control","settings":{"foreground":"#AF00DB"}},{"name":"Variable and parameter name","scope":["variable","meta.definition.variable.name","support.variable","entity.name.variable"],"settings":{"foreground":"#001080"}},{"name":"Object keys, TS grammar specific","scope":["meta.object-literal.key"],"settings":{"foreground":"#001080"}},{"name":"CSS property value","scope":["support.constant.property-value","support.constant.font-name","support.constant.media-type","support.constant.media","constant.other.color.rgb-value","constant.other.rgb-value","support.constant.color"],"settings":{"foreground":"#0451a5"}},{"name":"Regular expression groups","scope":["punctuation.definition.group.regexp","punctuation.definition.group.assertion.regexp","punctuation.definition.character-class.regexp","punctuation.character.set.begin.regexp","punctuation.character.set.end.regexp","keyword.operator.negation.regexp","support.other.parenthesis.regexp"],"settings":{"foreground":"#d16969"}},{"scope":["constant.character.character-class.regexp","constant.other.character-class.set.regexp","constant.other.character-class.regexp","constant.character.set.regexp"],"settings":{"foreground":"#811f3f"}},{"scope":"keyword.operator.quantifier.regexp","settings":{"foreground":"#000000"}},{"scope":["keyword.operator.or.regexp","keyword.control.anchor.regexp"],"settings":{"foreground":"#ff0000"}},{"scope":"constant.character","settings":{"foreground":"#0000ff"}},{"scope":"constant.character.escape","settings":{"foreground":"#ff0000"}},{"scope":"token.info-token","settings":{"foreground":"#316bcd"}},{"scope":"token.warn-token","settings":{"foreground":"#cd9731"}},{"scope":"token.error-token","settings":{"foreground":"#cd3131"}},{"scope":"token.debug-token","settings":{"foreground":"#800080"}}],"extensionData":{"extensionId":"vscode.theme-defaults","extensionPublisher":"vscode","extensionName":"theme-defaults","extensionIsBuiltin":true},"colorMap":{"editor.background":"#ffffff","editor.foreground":"#000000","editor.inactiveSelectionBackground":"#e5ebf1","editorIndentGuide.background":"#d3d3d3","editorIndentGuide.activeBackground":"#939393","editor.selectionHighlightBackground":"#add6ff4d","editorSuggestWidget.background":"#f3f3f3","activityBarBadge.background":"#007acc","sideBarTitle.foreground":"#6f6f6f","list.hoverBackground":"#e8e8e8","input.placeholderForeground":"#767676","settings.textInputBorder":"#cecece","settings.numberInputBorder":"#cecece"}}');
		items1.set('commandpalette.mru.cache', '{"usesLRU":true,"entries":[{"key":"revealFileInOS","value":3},{"key":"extension.openInGitHub","value":4},{"key":"workbench.extensions.action.openExtensionsFolder","value":11},{"key":"workbench.action.showRuntimeExtensions","value":14},{"key":"workbench.action.toggleTabsVisibility","value":15},{"key":"extension.liveServerPreview.open","value":16},{"key":"workbench.action.openIssueReporter","value":18},{"key":"workbench.action.openProcessExplorer","value":19},{"key":"workbench.action.toggleSharedProcess","value":20},{"key":"workbench.action.configureLocale","value":21},{"key":"workbench.action.appPerf","value":22},{"key":"workbench.action.reportPerformanceIssueUsingReporter","value":23},{"key":"workbench.action.openGlobalKeybindings","value":25},{"key":"workbench.action.output.toggleOutput","value":27},{"key":"extension.sayHello","value":29}]}');
		items1.set('cpp.1.lastsessiondate', 'Fri Oct 05 2018');
		items1.set('debug.actionswidgetposition', '0.6880952380952381');

		const items2 = new Map<string, string>();
		items2.set('workbench.editors.files.textfileeditor', '{"textEditorViewState":[["file:///Users/dummy/Documents/ticino-playground/play.htm",{"0":{"cursorState":[{"inSelectionMode":false,"selectionStart":{"lineNumber":6,"column":16},"position":{"lineNumber":6,"column":16}}],"viewState":{"scrollLeft":0,"firstPosition":{"lineNumber":1,"column":1},"firstPositionDeltaTop":0},"contributionsState":{"editor.contrib.folding":{},"editor.contrib.wordHighlighter":false}}}],["file:///Users/dummy/Documents/ticino-playground/nakefile.js",{"0":{"cursorState":[{"inSelectionMode":false,"selectionStart":{"lineNumber":7,"column":81},"position":{"lineNumber":7,"column":81}}],"viewState":{"scrollLeft":0,"firstPosition":{"lineNumber":1,"column":1},"firstPositionDeltaTop":20},"contributionsState":{"editor.contrib.folding":{},"editor.contrib.wordHighlighter":false}}}],["file:///Users/dummy/Desktop/vscode2/.gitattributes",{"0":{"cursorState":[{"inSelectionMode":false,"selectionStart":{"lineNumber":9,"column":12},"position":{"lineNumber":9,"column":12}}],"viewState":{"scrollLeft":0,"firstPosition":{"lineNumber":1,"column":1},"firstPositionDeltaTop":20},"contributionsState":{"editor.contrib.folding":{},"editor.contrib.wordHighlighter":false}}}],["file:///Users/dummy/Desktop/vscode2/src/vs/workbench/parts/search/browser/openAnythingHandler.ts",{"0":{"cursorState":[{"inSelectionMode":false,"selectionStart":{"lineNumber":1,"column":1},"position":{"lineNumber":1,"column":1}}],"viewState":{"scrollLeft":0,"firstPosition":{"lineNumber":1,"column":1},"firstPositionDeltaTop":0},"contributionsState":{"editor.contrib.folding":{},"editor.contrib.wordHighlighter":false}}}]]}');

		const items3 = new Map<string, string>();
		items3.set('nps/iscandidate', 'false');
		items3.set('telemetry.instanceid', 'd52bfcd4-4be6-476b-a38f-d44c717c41d6');
		items3.set('workbench.activity.pinnedviewlets', '[{"id":"workbench.view.explorer","pinned":true,"order":0,"visible":true},{"id":"workbench.view.search","pinned":true,"order":1,"visible":true},{"id":"workbench.view.scm","pinned":true,"order":2,"visible":true},{"id":"workbench.view.debug","pinned":true,"order":3,"visible":true},{"id":"workbench.view.extensions","pinned":true,"order":4,"visible":true},{"id":"workbench.view.extension.gitlens","pinned":true,"order":7,"visible":true},{"id":"workbench.view.extension.test","pinned":false,"visible":false}]');
		items3.set('workbench.panel.height', '419');
		items3.set('very.long.key.very.long.key.very.long.key.very.long.key.very.long.key.very.long.key.very.long.key.very.long.key.very.long.key.very.long.key.very.long.key.very.long.key.very.long.key.very.long.key.very.long.key.very.long.key.very.long.key.very.long.key.very.long.key.very.long.key.very.long.key.very.long.key.very.long.key.very.long.key.very.long.key.very.long.key.very.long.key.very.long.key.very.long.key.very.long.key.very.long.key.very.long.key.very.long.key.very.long.key.very.long.key.', 'is long');

		let storedItems = await storage.getItems();
		equal(storedItems.size, 0);

		await Promise.all([
			await storage.updateItems({ insert: items1 }),
			await storage.updateItems({ insert: items2 }),
			await storage.updateItems({ insert: items3 })
		]);

		equal(await storage.checkIntegrity(true), 'ok');
		equal(await storage.checkIntegrity(false), 'ok');

		storedItems = await storage.getItems();
		equal(storedItems.size, items1.size + items2.size + items3.size);

		const items1Keys: string[] = [];
		items1.forEach((value, key) => {
			items1Keys.push(key);
			equal(storedItems.get(key), value);
		});

		const items2Keys: string[] = [];
		items2.forEach((value, key) => {
			items2Keys.push(key);
			equal(storedItems.get(key), value);
		});

		const items3Keys: string[] = [];
		items3.forEach((value, key) => {
			items3Keys.push(key);
			equal(storedItems.get(key), value);
		});

		await Promise.all([
			await storage.updateItems({ delete: toSet(items1Keys) }),
			await storage.updateItems({ delete: toSet(items2Keys) }),
			await storage.updateItems({ delete: toSet(items3Keys) })
		]);

		storedItems = await storage.getItems();
		equal(storedItems.size, 0);

		await Promise.all([
			await storage.updateItems({ insert: items1 }),
			await storage.getItems(),
			await storage.updateItems({ insert: items2 }),
			await storage.getItems(),
			await storage.updateItems({ insert: items3 }),
			await storage.getItems(),
		]);

		storedItems = await storage.getItems();
		equal(storedItems.size, items1.size + items2.size + items3.size);

		await storage.close();

		storage = new SQLiteStorageImpl({
			path: join(storageDir, 'storage.db')
		});

		storedItems = await storage.getItems();
		equal(storedItems.size, items1.size + items2.size + items3.size);

		await storage.close();

		await del(storageDir, tmpdir());
	});

	test('very large item value', async () => {
		const storageDir = uniqueStorageDir();

		await mkdirp(storageDir);

		let storage = new SQLiteStorageImpl({
			path: join(storageDir, 'storage.db')
		});

		const items = new Map<string, string>();
		items.set('colorthemedata', '{"id":"vs vscode-theme-defaults-themes-light_plus-json","label":"Light+ (default light)","settingsId":"Default Light+","selector":"vs.vscode-theme-defaults-themes-light_plus-json","themeTokenColors":[{"settings":{"foreground":"#000000ff","background":"#ffffffff"}},{"scope":["meta.embedded","source.groovy.embedded"],"settings":{"foreground":"#000000ff"}},{"scope":"emphasis","settings":{"fontStyle":"italic"}},{"scope":"strong","settings":{"fontStyle":"bold"}},{"scope":"meta.diff.header","settings":{"foreground":"#000080"}},{"scope":"comment","settings":{"foreground":"#008000"}},{"scope":"constant.language","settings":{"foreground":"#0000ff"}},{"scope":["constant.numeric"],"settings":{"foreground":"#09885a"}},{"scope":"constant.regexp","settings":{"foreground":"#811f3f"}},{"name":"css tags in selectors, xml tags","scope":"entity.name.tag","settings":{"foreground":"#800000"}},{"scope":"entity.name.selector","settings":{"foreground":"#800000"}},{"scope":"entity.other.attribute-name","settings":{"foreground":"#ff0000"}},{"scope":["entity.other.attribute-name.class.css","entity.other.attribute-name.class.mixin.css","entity.other.attribute-name.id.css","entity.other.attribute-name.parent-selector.css","entity.other.attribute-name.pseudo-class.css","entity.other.attribute-name.pseudo-element.css","source.css.less entity.other.attribute-name.id","entity.other.attribute-name.attribute.scss","entity.other.attribute-name.scss"],"settings":{"foreground":"#800000"}},{"scope":"invalid","settings":{"foreground":"#cd3131"}},{"scope":"markup.underline","settings":{"fontStyle":"underline"}},{"scope":"markup.bold","settings":{"fontStyle":"bold","foreground":"#000080"}},{"scope":"markup.heading","settings":{"fontStyle":"bold","foreground":"#800000"}},{"scope":"markup.italic","settings":{"fontStyle":"italic"}},{"scope":"markup.inserted","settings":{"foreground":"#09885a"}},{"scope":"markup.deleted","settings":{"foreground":"#a31515"}},{"scope":"markup.changed","settings":{"foreground":"#0451a5"}},{"scope":["punctuation.definition.quote.begin.markdown","punctuation.definition.list.begin.markdown"],"settings":{"foreground":"#0451a5"}},{"scope":"markup.inline.raw","settings":{"foreground":"#800000"}},{"name":"brackets of XML/HTML tags","scope":"punctuation.definition.tag","settings":{"foreground":"#800000"}},{"scope":"meta.preprocessor","settings":{"foreground":"#0000ff"}},{"scope":"meta.preprocessor.string","settings":{"foreground":"#a31515"}},{"scope":"meta.preprocessor.numeric","settings":{"foreground":"#09885a"}},{"scope":"meta.structure.dictionary.key.python","settings":{"foreground":"#0451a5"}},{"scope":"storage","settings":{"foreground":"#0000ff"}},{"scope":"storage.type","settings":{"foreground":"#0000ff"}},{"scope":"storage.modifier","settings":{"foreground":"#0000ff"}},{"scope":"string","settings":{"foreground":"#a31515"}},{"scope":["string.comment.buffered.block.pug","string.quoted.pug","string.interpolated.pug","string.unquoted.plain.in.yaml","string.unquoted.plain.out.yaml","string.unquoted.block.yaml","string.quoted.single.yaml","string.quoted.double.xml","string.quoted.single.xml","string.unquoted.cdata.xml","string.quoted.double.html","string.quoted.single.html","string.unquoted.html","string.quoted.single.handlebars","string.quoted.double.handlebars"],"settings":{"foreground":"#0000ff"}},{"scope":"string.regexp","settings":{"foreground":"#811f3f"}},{"name":"String interpolation","scope":["punctuation.definition.template-expression.begin","punctuation.definition.template-expression.end","punctuation.section.embedded"],"settings":{"foreground":"#0000ff"}},{"name":"Reset JavaScript string interpolation expression","scope":["meta.template.expression"],"settings":{"foreground":"#000000"}},{"scope":["support.constant.property-value","support.constant.font-name","support.constant.media-type","support.constant.media","constant.other.color.rgb-value","constant.other.rgb-value","support.constant.color"],"settings":{"foreground":"#0451a5"}},{"scope":["support.type.vendored.property-name","support.type.property-name","variable.css","variable.scss","variable.other.less","source.coffee.embedded"],"settings":{"foreground":"#ff0000"}},{"scope":["support.type.property-name.json"],"settings":{"foreground":"#0451a5"}},{"scope":"keyword","settings":{"foreground":"#0000ff"}},{"scope":"keyword.control","settings":{"foreground":"#0000ff"}},{"scope":"keyword.operator","settings":{"foreground":"#000000"}},{"scope":["keyword.operator.new","keyword.operator.expression","keyword.operator.cast","keyword.operator.sizeof","keyword.operator.instanceof","keyword.operator.logical.python"],"settings":{"foreground":"#0000ff"}},{"scope":"keyword.other.unit","settings":{"foreground":"#09885a"}},{"scope":["punctuation.section.embedded.begin.php","punctuation.section.embedded.end.php"],"settings":{"foreground":"#800000"}},{"scope":"support.function.git-rebase","settings":{"foreground":"#0451a5"}},{"scope":"constant.sha.git-rebase","settings":{"foreground":"#09885a"}},{"name":"coloring of the Java import and package identifiers","scope":["storage.modifier.import.java","variable.language.wildcard.java","storage.modifier.package.java"],"settings":{"foreground":"#000000"}},{"name":"this.self","scope":"variable.language","settings":{"foreground":"#0000ff"}},{"name":"Function declarations","scope":["entity.name.function","support.function","support.constant.handlebars"],"settings":{"foreground":"#795E26"}},{"name":"Types declaration and references","scope":["meta.return-type","support.class","support.type","entity.name.type","entity.name.class","storage.type.numeric.go","storage.type.byte.go","storage.type.boolean.go","storage.type.string.go","storage.type.uintptr.go","storage.type.error.go","storage.type.rune.go","storage.type.cs","storage.type.generic.cs","storage.type.modifier.cs","storage.type.variable.cs","storage.type.annotation.java","storage.type.generic.java","storage.type.java","storage.type.object.array.java","storage.type.primitive.array.java","storage.type.primitive.java","storage.type.token.java","storage.type.groovy","storage.type.annotation.groovy","storage.type.parameters.groovy","storage.type.generic.groovy","storage.type.object.array.groovy","storage.type.primitive.array.groovy","storage.type.primitive.groovy"],"settings":{"foreground":"#267f99"}},{"name":"Types declaration and references, TS grammar specific","scope":["meta.type.cast.expr","meta.type.new.expr","support.constant.math","support.constant.dom","support.constant.json","entity.other.inherited-class"],"settings":{"foreground":"#267f99"}},{"name":"Control flow keywords","scope":"keyword.control","settings":{"foreground":"#AF00DB"}},{"name":"Variable and parameter name","scope":["variable","meta.definition.variable.name","support.variable","entity.name.variable"],"settings":{"foreground":"#001080"}},{"name":"Object keys, TS grammar specific","scope":["meta.object-literal.key"],"settings":{"foreground":"#001080"}},{"name":"CSS property value","scope":["support.constant.property-value","support.constant.font-name","support.constant.media-type","support.constant.media","constant.other.color.rgb-value","constant.other.rgb-value","support.constant.color"],"settings":{"foreground":"#0451a5"}},{"name":"Regular expression groups","scope":["punctuation.definition.group.regexp","punctuation.definition.group.assertion.regexp","punctuation.definition.character-class.regexp","punctuation.character.set.begin.regexp","punctuation.character.set.end.regexp","keyword.operator.negation.regexp","support.other.parenthesis.regexp"],"settings":{"foreground":"#d16969"}},{"scope":["constant.character.character-class.regexp","constant.other.character-class.set.regexp","constant.other.character-class.regexp","constant.character.set.regexp"],"settings":{"foreground":"#811f3f"}},{"scope":"keyword.operator.quantifier.regexp","settings":{"foreground":"#000000"}},{"scope":["keyword.operator.or.regexp","keyword.control.anchor.regexp"],"settings":{"foreground":"#ff0000"}},{"scope":"constant.character","settings":{"foreground":"#0000ff"}},{"scope":"constant.character.escape","settings":{"foreground":"#ff0000"}},{"scope":"token.info-token","settings":{"foreground":"#316bcd"}},{"scope":"token.warn-token","settings":{"foreground":"#cd9731"}},{"scope":"token.error-token","settings":{"foreground":"#cd3131"}},{"scope":"token.debug-token","settings":{"foreground":"#800080"}}],"extensionData":{"extensionId":"vscode.theme-defaults","extensionPublisher":"vscode","extensionName":"theme-defaults","extensionIsBuiltin":true},"colorMap":{"editor.background":"#ffffff","editor.foreground":"#000000","editor.inactiveSelectionBackground":"#e5ebf1","editorIndentGuide.background":"#d3d3d3","editorIndentGuide.activeBackground":"#939393","editor.selectionHighlightBackground":"#add6ff4d","editorSuggestWidget.background":"#f3f3f3","activityBarBadge.background":"#007acc","sideBarTitle.foreground":"#6f6f6f","list.hoverBackground":"#e8e8e8","input.placeholderForeground":"#767676","settings.textInputBorder":"#cecece","settings.numberInputBorder":"#cecece"}}');
		items.set('commandpalette.mru.cache', '{"usesLRU":true,"entries":[{"key":"revealFileInOS","value":3},{"key":"extension.openInGitHub","value":4},{"key":"workbench.extensions.action.openExtensionsFolder","value":11},{"key":"workbench.action.showRuntimeExtensions","value":14},{"key":"workbench.action.toggleTabsVisibility","value":15},{"key":"extension.liveServerPreview.open","value":16},{"key":"workbench.action.openIssueReporter","value":18},{"key":"workbench.action.openProcessExplorer","value":19},{"key":"workbench.action.toggleSharedProcess","value":20},{"key":"workbench.action.configureLocale","value":21},{"key":"workbench.action.appPerf","value":22},{"key":"workbench.action.reportPerformanceIssueUsingReporter","value":23},{"key":"workbench.action.openGlobalKeybindings","value":25},{"key":"workbench.action.output.toggleOutput","value":27},{"key":"extension.sayHello","value":29}]}');

		let uuid = generateUuid();
		let value: string[] = [];
		for (let i = 0; i < 100000; i++) {
			value.push(uuid);
		}
		items.set('super.large.string', value.join()); // 3.6MB

		await storage.updateItems({ insert: items });

		let storedItems = await storage.getItems();
		equal(items.get('colorthemedata'), storedItems.get('colorthemedata'));
		equal(items.get('commandpalette.mru.cache'), storedItems.get('commandpalette.mru.cache'));
		equal(items.get('super.large.string'), storedItems.get('super.large.string'));

		uuid = generateUuid();
		value = [];
		for (let i = 0; i < 100000; i++) {
			value.push(uuid);
		}
		items.set('super.large.string', value.join()); // 3.6MB

		await storage.updateItems({ insert: items });

		storedItems = await storage.getItems();
		equal(items.get('colorthemedata'), storedItems.get('colorthemedata'));
		equal(items.get('commandpalette.mru.cache'), storedItems.get('commandpalette.mru.cache'));
		equal(items.get('super.large.string'), storedItems.get('super.large.string'));

		const toDelete = new Set<string>();
		toDelete.add('super.large.string');
		await storage.updateItems({ delete: toDelete });

		storedItems = await storage.getItems();
		equal(items.get('colorthemedata'), storedItems.get('colorthemedata'));
		equal(items.get('commandpalette.mru.cache'), storedItems.get('commandpalette.mru.cache'));
		ok(!storedItems.get('super.large.string'));

		await storage.close();

		await del(storageDir, tmpdir());
	});

	test('multiple concurrent writes execute in sequence', async () => {
		const storageDir = uniqueStorageDir();
		await mkdirp(storageDir);

		const storage = new Storage({ path: join(storageDir, 'storage.db') });

		await storage.init();

		storage.set('foo', 'bar');
		storage.set('some/foo/path', 'some/bar/path');

		await timeout(10);

		storage.set('foo1', 'bar');
		storage.set('some/foo1/path', 'some/bar/path');

		await timeout(10);

		storage.set('foo2', 'bar');
		storage.set('some/foo2/path', 'some/bar/path');

		await timeout(10);

		storage.delete('foo1');
		storage.delete('some/foo1/path');

		await timeout(10);

		storage.delete('foo4');
		storage.delete('some/foo4/path');

		await timeout(70);

		storage.set('foo3', 'bar');
		await storage.set('some/foo3/path', 'some/bar/path');

		const items = await storage.getItems();
		equal(items.get('foo'), 'bar');
		equal(items.get('some/foo/path'), 'some/bar/path');
		equal(items.has('foo1'), false);
		equal(items.has('some/foo1/path'), false);
		equal(items.get('foo2'), 'bar');
		equal(items.get('some/foo2/path'), 'some/bar/path');
		equal(items.get('foo3'), 'bar');
		equal(items.get('some/foo3/path'), 'some/bar/path');

		await storage.close();

		await del(storageDir, tmpdir());
	});
});
