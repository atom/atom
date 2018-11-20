/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import * as assert from 'assert';
import { isUndefinedOrNull } from 'vs/base/common/types';
import { isLinux, isWindows } from 'vs/base/common/platform';
import { URI } from 'vs/base/common/uri';
import { join } from 'vs/base/common/paths';
import { validateFileName } from 'vs/workbench/parts/files/electron-browser/fileActions';
import { ExplorerItem } from 'vs/workbench/parts/files/common/explorerModel';

function createStat(path: string, name: string, isFolder: boolean, hasChildren: boolean, size: number, mtime: number): ExplorerItem {
	return new ExplorerItem(toResource(path), undefined, false, false, isFolder, name, mtime);
}

function toResource(path) {
	if (isWindows) {
		return URI.file(join('C:\\', path));
	} else {
		return URI.file(join('/home/john', path));
	}

}

suite('Files - View Model', () => {

	test('Properties', () => {
		const d = new Date().getTime();
		let s = createStat('/path/to/stat', 'sName', true, true, 8096, d);

		assert.strictEqual(s.isDirectoryResolved, false);
		assert.strictEqual(s.resource.fsPath, toResource('/path/to/stat').fsPath);
		assert.strictEqual(s.name, 'sName');
		assert.strictEqual(s.isDirectory, true);
		assert.strictEqual(s.mtime, new Date(d).getTime());
		assert.strictEqual(s.getChildrenArray().length, 0);

		s = createStat('/path/to/stat', 'sName', false, false, 8096, d);
		assert(isUndefinedOrNull(s.getChildrenArray()));
	});

	test('Add and Remove Child, check for hasChild', function () {
		const d = new Date().getTime();
		const s = createStat('/path/to/stat', 'sName', true, false, 8096, d);

		const child1 = createStat('/path/to/stat/foo', 'foo', true, false, 8096, d);
		const child4 = createStat('/otherpath/to/other/otherbar.html', 'otherbar.html', false, false, 8096, d);

		s.addChild(child1);

		assert(s.getChildrenArray().length === 1);

		s.removeChild(child1);
		s.addChild(child1);
		assert(s.getChildrenArray().length === 1);

		s.removeChild(child1);
		assert(s.getChildrenArray().length === 0);

		// Assert that adding a child updates its path properly
		s.addChild(child4);
		assert.strictEqual(child4.resource.fsPath, toResource('/path/to/stat/' + child4.name).fsPath);
	});

	test('Move', () => {
		const d = new Date().getTime();

		const s1 = createStat('/', '/', true, false, 8096, d);
		const s2 = createStat('/path', 'path', true, false, 8096, d);
		const s3 = createStat('/path/to', 'to', true, false, 8096, d);
		const s4 = createStat('/path/to/stat', 'stat', false, false, 8096, d);

		s1.addChild(s2);
		s2.addChild(s3);
		s3.addChild(s4);

		s4.move(s1);

		assert.strictEqual(s3.getChildrenArray().length, 0);

		assert.strictEqual(s1.getChildrenArray().length, 2);

		// Assert the new path of the moved element
		assert.strictEqual(s4.resource.fsPath, toResource('/' + s4.name).fsPath);

		// Move a subtree with children
		const leaf = createStat('/leaf', 'leaf', true, false, 8096, d);
		const leafC1 = createStat('/leaf/folder', 'folder', true, false, 8096, d);
		const leafCC2 = createStat('/leaf/folder/index.html', 'index.html', true, false, 8096, d);

		leaf.addChild(leafC1);
		leafC1.addChild(leafCC2);
		s1.addChild(leaf);

		leafC1.move(s3);
		assert.strictEqual(leafC1.resource.fsPath, URI.file(s3.resource.fsPath + '/' + leafC1.name).fsPath);
		assert.strictEqual(leafCC2.resource.fsPath, URI.file(leafC1.resource.fsPath + '/' + leafCC2.name).fsPath);
	});

	test('Rename', () => {
		const d = new Date().getTime();

		const s1 = createStat('/', '/', true, false, 8096, d);
		const s2 = createStat('/path', 'path', true, false, 8096, d);
		const s3 = createStat('/path/to', 'to', true, false, 8096, d);
		const s4 = createStat('/path/to/stat', 'stat', true, false, 8096, d);

		s1.addChild(s2);
		s2.addChild(s3);
		s3.addChild(s4);

		assert.strictEqual(s1.getChild(s2.name), s2);
		const s2renamed = createStat('/otherpath', 'otherpath', true, true, 8096, d);
		s2.rename(s2renamed);
		assert.strictEqual(s1.getChild(s2.name), s2);

		// Verify the paths have changed including children
		assert.strictEqual(s2.name, s2renamed.name);
		assert.strictEqual(s2.resource.fsPath, s2renamed.resource.fsPath);
		assert.strictEqual(s3.resource.fsPath, toResource('/otherpath/to').fsPath);
		assert.strictEqual(s4.resource.fsPath, toResource('/otherpath/to/stat').fsPath);

		const s4renamed = createStat('/otherpath/to/statother.js', 'statother.js', true, false, 8096, d);
		s4.rename(s4renamed);
		assert.strictEqual(s3.getChild(s4.name), s4);
		assert.strictEqual(s4.name, s4renamed.name);
		assert.strictEqual(s4.resource.fsPath, s4renamed.resource.fsPath);
	});

	test('Find', () => {
		const d = new Date().getTime();

		const s1 = createStat('/', '/', true, false, 8096, d);
		const s2 = createStat('/path', 'path', true, false, 8096, d);
		const s3 = createStat('/path/to', 'to', true, false, 8096, d);
		const s4 = createStat('/path/to/stat', 'stat', true, false, 8096, d);
		const s4Upper = createStat('/path/to/STAT', 'stat', true, false, 8096, d);

		const child1 = createStat('/path/to/stat/foo', 'foo', true, false, 8096, d);
		const child2 = createStat('/path/to/stat/foo/bar.html', 'bar.html', false, false, 8096, d);

		s1.addChild(s2);
		s2.addChild(s3);
		s3.addChild(s4);
		s4.addChild(child1);
		child1.addChild(child2);

		assert.strictEqual(s1.find(child2.resource), child2);
		assert.strictEqual(s1.find(child1.resource), child1);
		assert.strictEqual(s1.find(s4.resource), s4);
		assert.strictEqual(s1.find(s3.resource), s3);
		assert.strictEqual(s1.find(s2.resource), s2);

		if (isLinux) {
			assert.ok(!s1.find(s4Upper.resource));
		} else {
			assert.strictEqual(s1.find(s4Upper.resource), s4);
		}

		assert.strictEqual(s1.find(toResource('foobar')), null);

		assert.strictEqual(s1.find(toResource('/')), s1);
		assert.strictEqual(s1.find(toResource('')), s1);
	});

	test('Find with mixed case', function () {
		const d = new Date().getTime();

		const s1 = createStat('/', '/', true, false, 8096, d);
		const s2 = createStat('/path', 'path', true, false, 8096, d);
		const s3 = createStat('/path/to', 'to', true, false, 8096, d);
		const s4 = createStat('/path/to/stat', 'stat', true, false, 8096, d);

		const child1 = createStat('/path/to/stat/foo', 'foo', true, false, 8096, d);
		const child2 = createStat('/path/to/stat/foo/bar.html', 'bar.html', false, false, 8096, d);

		s1.addChild(s2);
		s2.addChild(s3);
		s3.addChild(s4);
		s4.addChild(child1);
		child1.addChild(child2);

		if (isLinux) { // linux is case sensitive
			assert.ok(!s1.find(toResource('/path/to/stat/Foo')));
			assert.ok(!s1.find(toResource('/Path/to/stat/foo/bar.html')));
		} else {
			assert.ok(s1.find(toResource('/path/to/stat/Foo')));
			assert.ok(s1.find(toResource('/Path/to/stat/foo/bar.html')));
		}
	});

	test('Validate File Name (For Create)', function () {
		const d = new Date().getTime();
		const s = createStat('/path/to/stat', 'sName', true, true, 8096, d);
		const sChild = createStat('/path/to/stat/alles.klar', 'alles.klar', true, true, 8096, d);
		s.addChild(sChild);

		assert(validateFileName(s, null) !== null);
		assert(validateFileName(s, '') !== null);
		assert(validateFileName(s, '  ') !== null);
		assert(validateFileName(s, 'Read Me') === null, 'name containing space');

		if (isWindows) {
			assert(validateFileName(s, 'foo:bar') !== null);
			assert(validateFileName(s, 'foo*bar') !== null);
			assert(validateFileName(s, 'foo?bar') !== null);
			assert(validateFileName(s, 'foo<bar') !== null);
			assert(validateFileName(s, 'foo>bar') !== null);
			assert(validateFileName(s, 'foo|bar') !== null);
		}
		assert(validateFileName(s, 'alles.klar') !== null);

		assert(validateFileName(s, '.foo') === null);
		assert(validateFileName(s, 'foo.bar') === null);
		assert(validateFileName(s, 'foo') === null);
	});

	test('Validate File Name (For Rename)', function () {
		const d = new Date().getTime();
		const s = createStat('/path/to/stat', 'sName', true, true, 8096, d);
		const sChild = createStat('/path/to/stat/alles.klar', 'alles.klar', true, true, 8096, d);
		s.addChild(sChild);

		assert(validateFileName(s, 'alles.klar') !== null);

		if (isLinux) {
			assert(validateFileName(s, 'Alles.klar') === null);
			assert(validateFileName(s, 'Alles.Klar') === null);
		} else {
			assert(validateFileName(s, 'Alles.klar') !== null);
			assert(validateFileName(s, 'Alles.Klar') !== null);
		}

		assert(validateFileName(s, '.foo') === null);
		assert(validateFileName(s, 'foo.bar') === null);
		assert(validateFileName(s, 'foo') === null);
	});

	test('Validate Multi-Path File Names', function () {
		const d = new Date().getTime();
		const wsFolder = createStat('/', 'workspaceFolder', true, false, 8096, d);

		assert(validateFileName(wsFolder, 'foo/bar') === null);
		assert(validateFileName(wsFolder, 'foo\\bar') === null);
		assert(validateFileName(wsFolder, 'all/slashes/are/same') === null);
		assert(validateFileName(wsFolder, 'theres/one/different\\slash') === null);
		assert(validateFileName(wsFolder, '/slashAtBeginning') !== null);

		// attempting to add a child to a deeply nested file
		const s1 = createStat('/path', 'path', true, false, 8096, d);
		const s2 = createStat('/path/to', 'to', true, false, 8096, d);
		const s3 = createStat('/path/to/stat', 'stat', true, false, 8096, d);
		wsFolder.addChild(s1);
		s1.addChild(s2);
		s2.addChild(s3);
		const fileDeeplyNested = createStat('/path/to/stat/fileNested', 'fileNested', false, false, 8096, d);
		s3.addChild(fileDeeplyNested);
		assert(validateFileName(wsFolder, '/path/to/stat/fileNested/aChild') !== null);

		// detect if path already exists
		assert(validateFileName(wsFolder, '/path/to/stat/fileNested') !== null);
		assert(validateFileName(wsFolder, '/path/to/stat/') !== null);
	});

	test('Merge Local with Disk', function () {
		const d = new Date().toUTCString();

		const merge1 = new ExplorerItem(URI.file(join('C:\\', '/path/to')), undefined, false, false, true, 'to', Date.now(), d);
		const merge2 = new ExplorerItem(URI.file(join('C:\\', '/path/to')), undefined, false, false, true, 'to', Date.now(), new Date(0).toUTCString());

		// Merge Properties
		ExplorerItem.mergeLocalWithDisk(merge2, merge1);
		assert.strictEqual(merge1.mtime, merge2.mtime);

		// Merge Child when isDirectoryResolved=false is a no-op
		merge2.addChild(new ExplorerItem(URI.file(join('C:\\', '/path/to/foo.html')), undefined, false, false, true, 'foo.html', Date.now(), d));
		ExplorerItem.mergeLocalWithDisk(merge2, merge1);
		assert.strictEqual(merge1.getChildrenArray().length, 0);

		// Merge Child with isDirectoryResolved=true
		const child = new ExplorerItem(URI.file(join('C:\\', '/path/to/foo.html')), undefined, false, false, true, 'foo.html', Date.now(), d);
		merge2.removeChild(child);
		merge2.addChild(child);
		merge2.isDirectoryResolved = true;
		ExplorerItem.mergeLocalWithDisk(merge2, merge1);
		assert.strictEqual(merge1.getChildrenArray().length, 1);
		assert.strictEqual(merge1.getChild('foo.html').name, 'foo.html');
		assert.deepEqual(merge1.getChild('foo.html').parent, merge1, 'Check parent');

		// Verify that merge does not replace existing children, but updates properties in that case
		const existingChild = merge1.getChild('foo.html');
		ExplorerItem.mergeLocalWithDisk(merge2, merge1);
		assert.ok(existingChild === merge1.getChild(existingChild.name));
	});
});
