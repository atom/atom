/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import * as fs from 'fs';
import * as path from 'path';
import * as assert from 'assert';

import { StatResolver } from 'vs/workbench/services/files/electron-browser/fileService';
import { URI as uri } from 'vs/base/common/uri';
import { isLinux } from 'vs/base/common/platform';
import * as utils from 'vs/workbench/services/files/test/electron-browser/utils';
import { getPathFromAmdModule } from 'vs/base/common/amd';

function create(relativePath: string): StatResolver {
	let basePath = getPathFromAmdModule(require, './fixtures/resolver');
	let absolutePath = relativePath ? path.join(basePath, relativePath) : basePath;
	let fsStat = fs.statSync(absolutePath);

	return new StatResolver(uri.file(absolutePath), fsStat.isSymbolicLink(), fsStat.isDirectory(), fsStat.mtime.getTime(), fsStat.size, void 0);
}

function toResource(relativePath: string): uri {
	let basePath = getPathFromAmdModule(require, './fixtures/resolver');
	let absolutePath = relativePath ? path.join(basePath, relativePath) : basePath;

	return uri.file(absolutePath);
}

suite('Stat Resolver', () => {

	test('resolve file', function () {
		let resolver = create('/index.html');
		return resolver.resolve(null).then(result => {
			assert.ok(!result.isDirectory);
			assert.equal(result.name, 'index.html');
			assert.ok(!!result.etag);

			resolver = create('examples');
			return resolver.resolve(null).then(result => {
				assert.ok(result.isDirectory);
			});
		});
	});

	test('resolve directory', function () {
		let testsElements = ['examples', 'other', 'index.html', 'site.css'];

		let resolver = create('/');

		return resolver.resolve(null).then(result => {
			assert.ok(result);
			assert.ok(result.children);
			assert.ok(result.children.length > 0);
			assert.ok(result.isDirectory);
			assert.equal(result.children.length, testsElements.length);

			assert.ok(result.children.every((entry) => {
				return testsElements.some((name) => {
					return path.basename(entry.resource.fsPath) === name;
				});
			}));

			result.children.forEach((value) => {
				assert.ok(path.basename(value.resource.fsPath));
				if (['examples', 'other'].indexOf(path.basename(value.resource.fsPath)) >= 0) {
					assert.ok(value.isDirectory);
				} else if (path.basename(value.resource.fsPath) === 'index.html') {
					assert.ok(!value.isDirectory);
					assert.ok(!value.children);
				} else if (path.basename(value.resource.fsPath) === 'site.css') {
					assert.ok(!value.isDirectory);
					assert.ok(!value.children);
				} else {
					assert.ok(!'Unexpected value ' + path.basename(value.resource.fsPath));
				}
			});
		});
	});

	test('resolve directory - resolveTo single directory', function () {
		let resolver = create('/');

		return resolver.resolve({ resolveTo: [toResource('other/deep')] }).then(result => {
			assert.ok(result);
			assert.ok(result.children);
			assert.ok(result.children.length > 0);
			assert.ok(result.isDirectory);

			let children = result.children;
			assert.equal(children.length, 4);

			let other = utils.getByName(result, 'other');
			assert.ok(other);
			assert.ok(other.children.length > 0);

			let deep = utils.getByName(other, 'deep');
			assert.ok(deep);
			assert.ok(deep.children.length > 0);
			assert.equal(deep.children.length, 4);
		});
	});

	test('resolve directory - resolveTo single directory - mixed casing', function () {
		let resolver = create('/');

		return resolver.resolve({ resolveTo: [toResource('other/Deep')] }).then(result => {
			assert.ok(result);
			assert.ok(result.children);
			assert.ok(result.children.length > 0);
			assert.ok(result.isDirectory);

			let children = result.children;
			assert.equal(children.length, 4);

			let other = utils.getByName(result, 'other');
			assert.ok(other);
			assert.ok(other.children.length > 0);

			let deep = utils.getByName(other, 'deep');
			if (isLinux) { // Linux has case sensitive file system
				assert.ok(deep);
				assert.ok(!deep.children); // not resolved because we got instructed to resolve other/Deep with capital D
			} else {
				assert.ok(deep);
				assert.ok(deep.children.length > 0);
				assert.equal(deep.children.length, 4);
			}
		});
	});

	test('resolve directory - resolveTo multiple directories', function () {
		let resolver = create('/');

		return resolver.resolve({ resolveTo: [toResource('other/deep'), toResource('examples')] }).then(result => {
			assert.ok(result);
			assert.ok(result.children);
			assert.ok(result.children.length > 0);
			assert.ok(result.isDirectory);

			let children = result.children;
			assert.equal(children.length, 4);

			let other = utils.getByName(result, 'other');
			assert.ok(other);
			assert.ok(other.children.length > 0);

			let deep = utils.getByName(other, 'deep');
			assert.ok(deep);
			assert.ok(deep.children.length > 0);
			assert.equal(deep.children.length, 4);

			let examples = utils.getByName(result, 'examples');
			assert.ok(examples);
			assert.ok(examples.children.length > 0);
			assert.equal(examples.children.length, 4);
		});
	});

	test('resolve directory - resolveSingleChildFolders', function () {
		let resolver = create('/other');

		return resolver.resolve({ resolveSingleChildDescendants: true }).then(result => {
			assert.ok(result);
			assert.ok(result.children);
			assert.ok(result.children.length > 0);
			assert.ok(result.isDirectory);

			let children = result.children;
			assert.equal(children.length, 1);

			let deep = utils.getByName(result, 'deep');
			assert.ok(deep);
			assert.ok(deep.children.length > 0);
			assert.equal(deep.children.length, 4);
		});
	});
});
