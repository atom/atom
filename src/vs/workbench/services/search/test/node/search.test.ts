/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import * as assert from 'assert';
import * as path from 'path';
import { getPathFromAmdModule } from 'vs/base/common/amd';
import { join, normalize } from 'vs/base/common/paths';
import * as platform from 'vs/base/common/platform';
import { joinPath } from 'vs/base/common/resources';
import { URI } from 'vs/base/common/uri';
import { IFolderQuery, QueryType } from 'vs/platform/search/common/search';
import { Engine as FileSearchEngine, FileWalker } from 'vs/workbench/services/search/node/fileSearch';
import { IRawFileMatch } from 'vs/workbench/services/search/node/search';

const TEST_FIXTURES = path.normalize(getPathFromAmdModule(require, './fixtures'));
const EXAMPLES_FIXTURES = URI.file(path.join(TEST_FIXTURES, 'examples'));
const MORE_FIXTURES = URI.file(path.join(TEST_FIXTURES, 'more'));
const TEST_ROOT_FOLDER: IFolderQuery = { folder: URI.file(TEST_FIXTURES) };
const ROOT_FOLDER_QUERY: IFolderQuery[] = [
	TEST_ROOT_FOLDER
];

const ROOT_FOLDER_QUERY_36438: IFolderQuery[] = [
	{ folder: URI.file(path.normalize(getPathFromAmdModule(require, './fixtures2/36438'))) }
];

const MULTIROOT_QUERIES: IFolderQuery[] = [
	{ folder: EXAMPLES_FIXTURES },
	{ folder: MORE_FIXTURES }
];

const testTimeout = 5000;

suite('FileSearchEngine', () => {

	test('Files: *.js', function (done: () => void) {
		this.timeout(testTimeout);
		let engine = new FileSearchEngine({
			type: QueryType.File,
			folderQueries: ROOT_FOLDER_QUERY,
			filePattern: '*.js'
		});

		let count = 0;
		engine.search((result) => {
			if (result) {
				count++;
			}
		}, () => { }, (error) => {
			assert.ok(!error);
			assert.equal(count, 4);
			done();
		});
	});

	test('Files: maxResults', function (done: () => void) {
		this.timeout(testTimeout);
		let engine = new FileSearchEngine({
			type: QueryType.File,
			folderQueries: ROOT_FOLDER_QUERY,
			maxResults: 1
		});

		let count = 0;
		engine.search((result) => {
			if (result) {
				count++;
			}
		}, () => { }, (error) => {
			assert.ok(!error);
			assert.equal(count, 1);
			done();
		});
	});

	test('Files: maxResults without Ripgrep', function (done: () => void) {
		this.timeout(testTimeout);
		let engine = new FileSearchEngine({
			type: QueryType.File,
			folderQueries: ROOT_FOLDER_QUERY,
			maxResults: 1,
			useRipgrep: false
		});

		let count = 0;
		engine.search((result) => {
			if (result) {
				count++;
			}
		}, () => { }, (error) => {
			assert.ok(!error);
			assert.equal(count, 1);
			done();
		});
	});

	test('Files: exists', function (done: () => void) {
		this.timeout(testTimeout);
		let engine = new FileSearchEngine({
			type: QueryType.File,
			folderQueries: ROOT_FOLDER_QUERY,
			includePattern: { '**/file.txt': true },
			exists: true
		});

		let count = 0;
		engine.search((result) => {
			if (result) {
				count++;
			}
		}, () => { }, (error, complete) => {
			assert.ok(!error);
			assert.equal(count, 0);
			assert.ok(complete.limitHit);
			done();
		});
	});

	test('Files: not exists', function (done: () => void) {
		this.timeout(testTimeout);
		let engine = new FileSearchEngine({
			type: QueryType.File,
			folderQueries: ROOT_FOLDER_QUERY,
			includePattern: { '**/nofile.txt': true },
			exists: true
		});

		let count = 0;
		engine.search((result) => {
			if (result) {
				count++;
			}
		}, () => { }, (error, complete) => {
			assert.ok(!error);
			assert.equal(count, 0);
			assert.ok(!complete.limitHit);
			done();
		});
	});

	test('Files: exists without Ripgrep', function (done: () => void) {
		this.timeout(testTimeout);
		let engine = new FileSearchEngine({
			type: QueryType.File,
			folderQueries: ROOT_FOLDER_QUERY,
			includePattern: { '**/file.txt': true },
			exists: true,
			useRipgrep: false
		});

		let count = 0;
		engine.search((result) => {
			if (result) {
				count++;
			}
		}, () => { }, (error, complete) => {
			assert.ok(!error);
			assert.equal(count, 0);
			assert.ok(complete.limitHit);
			done();
		});
	});

	test('Files: not exists without Ripgrep', function (done: () => void) {
		this.timeout(testTimeout);
		let engine = new FileSearchEngine({
			type: QueryType.File,
			folderQueries: ROOT_FOLDER_QUERY,
			includePattern: { '**/nofile.txt': true },
			exists: true,
			useRipgrep: false
		});

		let count = 0;
		engine.search((result) => {
			if (result) {
				count++;
			}
		}, () => { }, (error, complete) => {
			assert.ok(!error);
			assert.equal(count, 0);
			assert.ok(!complete.limitHit);
			done();
		});
	});

	test('Files: examples/com*', function (done: () => void) {
		this.timeout(testTimeout);
		let engine = new FileSearchEngine({
			type: QueryType.File,
			folderQueries: ROOT_FOLDER_QUERY,
			filePattern: normalize(join('examples', 'com*'), true)
		});

		let count = 0;
		engine.search((result) => {
			if (result) {
				count++;
			}
		}, () => { }, (error) => {
			assert.ok(!error);
			assert.equal(count, 1);
			done();
		});
	});

	test('Files: examples (fuzzy)', function (done: () => void) {
		this.timeout(testTimeout);
		let engine = new FileSearchEngine({
			type: QueryType.File,
			folderQueries: ROOT_FOLDER_QUERY,
			filePattern: 'xl'
		});

		let count = 0;
		engine.search((result) => {
			if (result) {
				count++;
			}
		}, () => { }, (error) => {
			assert.ok(!error);
			assert.equal(count, 7);
			done();
		});
	});

	test('Files: multiroot', function (done: () => void) {
		this.timeout(testTimeout);
		let engine = new FileSearchEngine({
			type: QueryType.File,
			folderQueries: MULTIROOT_QUERIES,
			filePattern: 'file'
		});

		let count = 0;
		engine.search((result) => {
			if (result) {
				count++;
			}
		}, () => { }, (error) => {
			assert.ok(!error);
			assert.equal(count, 3);
			done();
		});
	});

	test('Files: multiroot with includePattern and maxResults', function (done: () => void) {
		this.timeout(testTimeout);
		let engine = new FileSearchEngine({
			type: QueryType.File,
			folderQueries: MULTIROOT_QUERIES,
			maxResults: 1,
			includePattern: {
				'*.txt': true,
				'*.js': true
			},
			useRipgrep: true
		});

		let count = 0;
		engine.search((result) => {
			if (result) {
				count++;
			}
		}, () => { }, (error, complete) => {
			assert.ok(!error);
			assert.equal(count, 1);
			done();
		});
	});

	test('Files: multiroot with includePattern and exists', function (done: () => void) {
		this.timeout(testTimeout);
		let engine = new FileSearchEngine({
			type: QueryType.File,
			folderQueries: MULTIROOT_QUERIES,
			exists: true,
			includePattern: {
				'*.txt': true,
				'*.js': true
			},
			useRipgrep: true
		});

		let count = 0;
		engine.search((result) => {
			if (result) {
				count++;
			}
		}, () => { }, (error, complete) => {
			assert.ok(!error);
			assert.equal(count, 0);
			assert.ok(complete.limitHit);
			done();
		});
	});

	test('Files: NPE (CamelCase)', function (done: () => void) {
		this.timeout(testTimeout);
		let engine = new FileSearchEngine({
			type: QueryType.File,
			folderQueries: ROOT_FOLDER_QUERY,
			filePattern: 'NullPE'
		});

		let count = 0;
		engine.search((result) => {
			if (result) {
				count++;
			}
		}, () => { }, (error) => {
			assert.ok(!error);
			assert.equal(count, 1);
			done();
		});
	});

	test('Files: *.*', function (done: () => void) {
		this.timeout(testTimeout);
		let engine = new FileSearchEngine({
			type: QueryType.File,
			folderQueries: ROOT_FOLDER_QUERY,
			filePattern: '*.*'
		});

		let count = 0;
		engine.search((result) => {
			if (result) {
				count++;
			}
		}, () => { }, (error) => {
			assert.ok(!error);
			assert.equal(count, 14);
			done();
		});
	});

	test('Files: *.as', function (done: () => void) {
		this.timeout(testTimeout);
		let engine = new FileSearchEngine({
			type: QueryType.File,
			folderQueries: ROOT_FOLDER_QUERY,
			filePattern: '*.as'
		});

		let count = 0;
		engine.search((result) => {
			if (result) {
				count++;
			}
		}, () => { }, (error) => {
			assert.ok(!error);
			assert.equal(count, 0);
			done();
		});
	});

	test('Files: *.* without derived', function (done: () => void) {
		this.timeout(testTimeout);
		let engine = new FileSearchEngine({
			type: QueryType.File,
			folderQueries: ROOT_FOLDER_QUERY,
			filePattern: 'site.*',
			excludePattern: { '**/*.css': { 'when': '$(basename).less' } }
		});

		let count = 0;
		let res: IRawFileMatch;
		engine.search((result) => {
			if (result) {
				count++;
			}
			res = result;
		}, () => { }, (error) => {
			assert.ok(!error);
			assert.equal(count, 1);
			assert.strictEqual(path.basename(res.relativePath), 'site.less');
			done();
		});
	});

	test('Files: *.* exclude folder without wildcard', function (done: () => void) {
		this.timeout(testTimeout);
		let engine = new FileSearchEngine({
			type: QueryType.File,
			folderQueries: ROOT_FOLDER_QUERY,
			filePattern: '*.*',
			excludePattern: { 'examples': true }
		});

		let count = 0;
		engine.search((result) => {
			if (result) {
				count++;
			}
		}, () => { }, (error) => {
			assert.ok(!error);
			assert.equal(count, 8);
			done();
		});
	});

	test('Files: exclude folder without wildcard #36438', function (done: () => void) {
		this.timeout(testTimeout);
		let engine = new FileSearchEngine({
			type: QueryType.File,
			folderQueries: ROOT_FOLDER_QUERY_36438,
			excludePattern: { 'modules': true }
		});

		let count = 0;
		engine.search((result) => {
			if (result) {
				count++;
			}
		}, () => { }, (error) => {
			assert.ok(!error);
			assert.equal(count, 1);
			done();
		});
	});

	test('Files: include folder without wildcard #36438', function (done: () => void) {
		this.timeout(testTimeout);
		let engine = new FileSearchEngine({
			type: QueryType.File,
			folderQueries: ROOT_FOLDER_QUERY_36438,
			includePattern: { 'modules/**': true }
		});

		let count = 0;
		engine.search((result) => {
			if (result) {
				count++;
			}
		}, () => { }, (error) => {
			assert.ok(!error);
			assert.equal(count, 1);
			done();
		});
	});

	test('Files: *.* exclude folder with leading wildcard', function (done: () => void) {
		this.timeout(testTimeout);
		let engine = new FileSearchEngine({
			type: QueryType.File,
			folderQueries: ROOT_FOLDER_QUERY,
			filePattern: '*.*',
			excludePattern: { '**/examples': true }
		});

		let count = 0;
		engine.search((result) => {
			if (result) {
				count++;
			}
		}, () => { }, (error) => {
			assert.ok(!error);
			assert.equal(count, 8);
			done();
		});
	});

	test('Files: *.* exclude folder with trailing wildcard', function (done: () => void) {
		this.timeout(testTimeout);
		let engine = new FileSearchEngine({
			type: QueryType.File,
			folderQueries: ROOT_FOLDER_QUERY,
			filePattern: '*.*',
			excludePattern: { 'examples/**': true }
		});

		let count = 0;
		engine.search((result) => {
			if (result) {
				count++;
			}
		}, () => { }, (error) => {
			assert.ok(!error);
			assert.equal(count, 8);
			done();
		});
	});

	test('Files: *.* exclude with unicode', function (done: () => void) {
		this.timeout(testTimeout);
		let engine = new FileSearchEngine({
			type: QueryType.File,
			folderQueries: ROOT_FOLDER_QUERY,
			filePattern: '*.*',
			excludePattern: { '**/üm laut汉语': true }
		});

		let count = 0;
		engine.search((result) => {
			if (result) {
				count++;
			}
		}, () => { }, (error) => {
			assert.ok(!error);
			assert.equal(count, 13);
			done();
		});
	});

	test('Files: *.* include with unicode', function (done: () => void) {
		this.timeout(testTimeout);
		let engine = new FileSearchEngine({
			type: QueryType.File,
			folderQueries: ROOT_FOLDER_QUERY,
			filePattern: '*.*',
			includePattern: { '**/üm laut汉语/*': true }
		});

		let count = 0;
		engine.search((result) => {
			if (result) {
				count++;
			}
		}, () => { }, (error) => {
			assert.ok(!error);
			assert.equal(count, 1);
			done();
		});
	});

	test('Files: multiroot with exclude', function (done: () => void) {
		this.timeout(testTimeout);
		const folderQueries: IFolderQuery[] = [
			{
				folder: EXAMPLES_FIXTURES,
				excludePattern: {
					'**/anotherfile.txt': true
				}
			},
			{
				folder: MORE_FIXTURES,
				excludePattern: {
					'**/file.txt': true
				}
			}
		];

		const engine = new FileSearchEngine({
			type: QueryType.File,
			folderQueries,
			filePattern: '*'
		});

		let count = 0;
		engine.search((result) => {
			if (result) {
				count++;
			}
		}, () => { }, (error) => {
			assert.ok(!error);
			assert.equal(count, 5);
			done();
		});
	});

	test('Files: Unicode and Spaces', function (done: () => void) {
		this.timeout(testTimeout);
		let engine = new FileSearchEngine({
			type: QueryType.File,
			folderQueries: ROOT_FOLDER_QUERY,
			filePattern: '汉语'
		});

		let count = 0;
		let res: IRawFileMatch;
		engine.search((result) => {
			if (result) {
				count++;
			}
			res = result;
		}, () => { }, (error) => {
			assert.ok(!error);
			assert.equal(count, 1);
			assert.equal(path.basename(res.relativePath), '汉语.txt');
			done();
		});
	});

	test('Files: no results', function (done: () => void) {
		this.timeout(testTimeout);
		let engine = new FileSearchEngine({
			type: QueryType.File,
			folderQueries: ROOT_FOLDER_QUERY,
			filePattern: 'nofilematch'
		});

		let count = 0;
		engine.search((result) => {
			if (result) {
				count++;
			}
		}, () => { }, (error) => {
			assert.ok(!error);
			assert.equal(count, 0);
			done();
		});
	});

	test('Files: relative path matched once', function (done: () => void) {
		this.timeout(testTimeout);
		let engine = new FileSearchEngine({
			type: QueryType.File,
			folderQueries: ROOT_FOLDER_QUERY,
			filePattern: path.normalize(path.join('examples', 'company.js'))
		});

		let count = 0;
		let res: IRawFileMatch;
		engine.search((result) => {
			if (result) {
				count++;
			}
			res = result;
		}, () => { }, (error) => {
			assert.ok(!error);
			assert.equal(count, 1);
			assert.equal(path.basename(res.relativePath), 'company.js');
			done();
		});
	});

	test('Files: Include pattern, single files', function (done: () => void) {
		this.timeout(testTimeout);
		let engine = new FileSearchEngine({
			type: QueryType.File,
			folderQueries: ROOT_FOLDER_QUERY,
			includePattern: {
				'site.css': true,
				'examples/company.js': true,
				'examples/subfolder/subfile.txt': true
			}
		});

		let res: IRawFileMatch[] = [];
		engine.search((result) => {
			res.push(result);
		}, () => { }, (error) => {
			assert.ok(!error);
			const basenames = res.map(r => path.basename(r.relativePath));
			assert.ok(basenames.indexOf('site.css') !== -1, `site.css missing in ${JSON.stringify(basenames)}`);
			assert.ok(basenames.indexOf('company.js') !== -1, `company.js missing in ${JSON.stringify(basenames)}`);
			assert.ok(basenames.indexOf('subfile.txt') !== -1, `subfile.txt missing in ${JSON.stringify(basenames)}`);
			done();
		});
	});

	test('Files: extraFiles only', function (done: () => void) {
		this.timeout(testTimeout);
		let engine = new FileSearchEngine({
			type: QueryType.File,
			folderQueries: [],
			extraFileResources: [
				URI.file(path.normalize(path.join(getPathFromAmdModule(require, './fixtures'), 'site.css'))),
				URI.file(path.normalize(path.join(getPathFromAmdModule(require, './fixtures'), 'examples', 'company.js'))),
				URI.file(path.normalize(path.join(getPathFromAmdModule(require, './fixtures'), 'index.html')))
			],
			filePattern: '*.js'
		});

		let count = 0;
		let res: IRawFileMatch;
		engine.search((result) => {
			if (result) {
				count++;
			}
			res = result;
		}, () => { }, (error) => {
			assert.ok(!error);
			assert.equal(count, 1);
			assert.equal(path.basename(res.relativePath), 'company.js');
			done();
		});
	});

	test('Files: extraFiles only (with include)', function (done: () => void) {
		this.timeout(testTimeout);
		let engine = new FileSearchEngine({
			type: QueryType.File,
			folderQueries: [],
			extraFileResources: [
				URI.file(path.normalize(path.join(getPathFromAmdModule(require, './fixtures'), 'site.css'))),
				URI.file(path.normalize(path.join(getPathFromAmdModule(require, './fixtures'), 'examples', 'company.js'))),
				URI.file(path.normalize(path.join(getPathFromAmdModule(require, './fixtures'), 'index.html')))
			],
			filePattern: '*.*',
			includePattern: { '**/*.css': true }
		});

		let count = 0;
		let res: IRawFileMatch;
		engine.search((result) => {
			if (result) {
				count++;
			}
			res = result;
		}, () => { }, (error) => {
			assert.ok(!error);
			assert.equal(count, 1);
			assert.equal(path.basename(res.relativePath), 'site.css');
			done();
		});
	});

	test('Files: extraFiles only (with exclude)', function (done: () => void) {
		this.timeout(testTimeout);
		let engine = new FileSearchEngine({
			type: QueryType.File,
			folderQueries: [],
			extraFileResources: [
				URI.file(path.normalize(path.join(getPathFromAmdModule(require, './fixtures'), 'site.css'))),
				URI.file(path.normalize(path.join(getPathFromAmdModule(require, './fixtures'), 'examples', 'company.js'))),
				URI.file(path.normalize(path.join(getPathFromAmdModule(require, './fixtures'), 'index.html')))
			],
			filePattern: '*.*',
			excludePattern: { '**/*.css': true }
		});

		let count = 0;
		engine.search((result) => {
			if (result) {
				count++;
			}
		}, () => { }, (error) => {
			assert.ok(!error);
			assert.equal(count, 2);
			done();
		});
	});

	test('Files: no dupes in nested folders', function (done: () => void) {
		this.timeout(testTimeout);
		let engine = new FileSearchEngine({
			type: QueryType.File,
			folderQueries: [
				{ folder: EXAMPLES_FIXTURES },
				{ folder: joinPath(EXAMPLES_FIXTURES, 'subfolder') }
			],
			filePattern: 'subfile.txt'
		});

		let count = 0;
		engine.search((result) => {
			if (result) {
				count++;
			}
		}, () => { }, (error) => {
			assert.ok(!error);
			assert.equal(count, 1);
			done();
		});
	});
});

suite('FileWalker', () => {

	test('Find: exclude subfolder', function (done: () => void) {
		this.timeout(testTimeout);
		if (platform.isWindows) {
			done();
			return;
		}

		const file0 = './more/file.txt';
		const file1 = './examples/subfolder/subfile.txt';

		const walker = new FileWalker({
			type: QueryType.File,
			folderQueries: ROOT_FOLDER_QUERY,
			excludePattern: { '**/something': true }
		});
		const cmd1 = walker.spawnFindCmd(TEST_ROOT_FOLDER);
		walker.readStdout(cmd1, 'utf8', /*isRipgrep=*/false, (err1, stdout1) => {
			assert.equal(err1, null);
			assert.notStrictEqual(stdout1.split('\n').indexOf(file0), -1, stdout1);
			assert.notStrictEqual(stdout1.split('\n').indexOf(file1), -1, stdout1);

			const walker = new FileWalker({
				type: QueryType.File,
				folderQueries: ROOT_FOLDER_QUERY,
				excludePattern: { '**/subfolder': true }
			});
			const cmd2 = walker.spawnFindCmd(TEST_ROOT_FOLDER);
			walker.readStdout(cmd2, 'utf8', /*isRipgrep=*/false, (err2, stdout2) => {
				assert.equal(err2, null);
				assert.notStrictEqual(stdout1.split('\n').indexOf(file0), -1, stdout1);
				assert.strictEqual(stdout2.split('\n').indexOf(file1), -1, stdout2);
				done();
			});
		});
	});

	test('Find: folder excludes', function (done: () => void) {
		this.timeout(testTimeout);
		if (platform.isWindows) {
			done();
			return;
		}

		const folderQueries: IFolderQuery[] = [
			{
				folder: URI.file(TEST_FIXTURES),
				excludePattern: { '**/subfolder': true }
			}
		];

		const file0 = './more/file.txt';
		const file1 = './examples/subfolder/subfile.txt';

		const walker = new FileWalker({ type: QueryType.File, folderQueries });
		const cmd1 = walker.spawnFindCmd(folderQueries[0]);
		walker.readStdout(cmd1, 'utf8', /*isRipgrep=*/false, (err1, stdout1) => {
			assert.equal(err1, null);
			assert(outputContains(stdout1, file0), stdout1);
			assert(!outputContains(stdout1, file1), stdout1);
			done();
		});
	});

	test('Find: exclude multiple folders', function (done: () => void) {
		this.timeout(testTimeout);
		if (platform.isWindows) {
			done();
			return;
		}

		const file0 = './index.html';
		const file1 = './examples/small.js';
		const file2 = './more/file.txt';

		const walker = new FileWalker({ type: QueryType.File, folderQueries: ROOT_FOLDER_QUERY, excludePattern: { '**/something': true } });
		const cmd1 = walker.spawnFindCmd(TEST_ROOT_FOLDER);
		walker.readStdout(cmd1, 'utf8', /*isRipgrep=*/false, (err1, stdout1) => {
			assert.equal(err1, null);
			assert.notStrictEqual(stdout1.split('\n').indexOf(file0), -1, stdout1);
			assert.notStrictEqual(stdout1.split('\n').indexOf(file1), -1, stdout1);
			assert.notStrictEqual(stdout1.split('\n').indexOf(file2), -1, stdout1);

			const walker = new FileWalker({ type: QueryType.File, folderQueries: ROOT_FOLDER_QUERY, excludePattern: { '{**/examples,**/more}': true } });
			const cmd2 = walker.spawnFindCmd(TEST_ROOT_FOLDER);
			walker.readStdout(cmd2, 'utf8', /*isRipgrep=*/false, (err2, stdout2) => {
				assert.equal(err2, null);
				assert.notStrictEqual(stdout1.split('\n').indexOf(file0), -1, stdout1);
				assert.strictEqual(stdout2.split('\n').indexOf(file1), -1, stdout2);
				assert.strictEqual(stdout2.split('\n').indexOf(file2), -1, stdout2);
				done();
			});
		});
	});

	test('Find: exclude folder path suffix', function (done: () => void) {
		this.timeout(testTimeout);
		if (platform.isWindows) {
			done();
			return;
		}

		const file0 = './examples/company.js';
		const file1 = './examples/subfolder/subfile.txt';

		const walker = new FileWalker({ type: QueryType.File, folderQueries: ROOT_FOLDER_QUERY, excludePattern: { '**/examples/something': true } });
		const cmd1 = walker.spawnFindCmd(TEST_ROOT_FOLDER);
		walker.readStdout(cmd1, 'utf8', /*isRipgrep=*/false, (err1, stdout1) => {
			assert.equal(err1, null);
			assert.notStrictEqual(stdout1.split('\n').indexOf(file0), -1, stdout1);
			assert.notStrictEqual(stdout1.split('\n').indexOf(file1), -1, stdout1);

			const walker = new FileWalker({ type: QueryType.File, folderQueries: ROOT_FOLDER_QUERY, excludePattern: { '**/examples/subfolder': true } });
			const cmd2 = walker.spawnFindCmd(TEST_ROOT_FOLDER);
			walker.readStdout(cmd2, 'utf8', /*isRipgrep=*/false, (err2, stdout2) => {
				assert.equal(err2, null);
				assert.notStrictEqual(stdout1.split('\n').indexOf(file0), -1, stdout1);
				assert.strictEqual(stdout2.split('\n').indexOf(file1), -1, stdout2);
				done();
			});
		});
	});

	test('Find: exclude subfolder path suffix', function (done: () => void) {
		this.timeout(testTimeout);
		if (platform.isWindows) {
			done();
			return;
		}

		const file0 = './examples/subfolder/subfile.txt';
		const file1 = './examples/subfolder/anotherfolder/anotherfile.txt';

		const walker = new FileWalker({ type: QueryType.File, folderQueries: ROOT_FOLDER_QUERY, excludePattern: { '**/subfolder/something': true } });
		const cmd1 = walker.spawnFindCmd(TEST_ROOT_FOLDER);
		walker.readStdout(cmd1, 'utf8', /*isRipgrep=*/false, (err1, stdout1) => {
			assert.equal(err1, null);
			assert.notStrictEqual(stdout1.split('\n').indexOf(file0), -1, stdout1);
			assert.notStrictEqual(stdout1.split('\n').indexOf(file1), -1, stdout1);

			const walker = new FileWalker({ type: QueryType.File, folderQueries: ROOT_FOLDER_QUERY, excludePattern: { '**/subfolder/anotherfolder': true } });
			const cmd2 = walker.spawnFindCmd(TEST_ROOT_FOLDER);
			walker.readStdout(cmd2, 'utf8', /*isRipgrep=*/false, (err2, stdout2) => {
				assert.equal(err2, null);
				assert.notStrictEqual(stdout1.split('\n').indexOf(file0), -1, stdout1);
				assert.strictEqual(stdout2.split('\n').indexOf(file1), -1, stdout2);
				done();
			});
		});
	});

	test('Find: exclude folder path', function (done: () => void) {
		this.timeout(testTimeout);
		if (platform.isWindows) {
			done();
			return;
		}

		const file0 = './examples/company.js';
		const file1 = './examples/subfolder/subfile.txt';

		const walker = new FileWalker({ type: QueryType.File, folderQueries: ROOT_FOLDER_QUERY, excludePattern: { 'examples/something': true } });
		const cmd1 = walker.spawnFindCmd(TEST_ROOT_FOLDER);
		walker.readStdout(cmd1, 'utf8', /*isRipgrep=*/false, (err1, stdout1) => {
			assert.equal(err1, null);
			assert.notStrictEqual(stdout1.split('\n').indexOf(file0), -1, stdout1);
			assert.notStrictEqual(stdout1.split('\n').indexOf(file1), -1, stdout1);

			const walker = new FileWalker({ type: QueryType.File, folderQueries: ROOT_FOLDER_QUERY, excludePattern: { 'examples/subfolder': true } });
			const cmd2 = walker.spawnFindCmd(TEST_ROOT_FOLDER);
			walker.readStdout(cmd2, 'utf8', /*isRipgrep=*/false, (err2, stdout2) => {
				assert.equal(err2, null);
				assert.notStrictEqual(stdout1.split('\n').indexOf(file0), -1, stdout1);
				assert.strictEqual(stdout2.split('\n').indexOf(file1), -1, stdout2);
				done();
			});
		});
	});

	test('Find: exclude combination of paths', function (done: () => void) {
		this.timeout(testTimeout);
		if (platform.isWindows) {
			done();
			return;
		}

		const filesIn = [
			'./examples/subfolder/subfile.txt',
			'./examples/company.js',
			'./index.html'
		];
		const filesOut = [
			'./examples/subfolder/anotherfolder/anotherfile.txt',
			'./more/file.txt'
		];

		const walker = new FileWalker({
			type: QueryType.File,
			folderQueries: ROOT_FOLDER_QUERY,
			excludePattern: {
				'**/subfolder/anotherfolder': true,
				'**/something/else': true,
				'**/more': true,
				'**/andmore': true
			}
		});
		const cmd1 = walker.spawnFindCmd(TEST_ROOT_FOLDER);
		walker.readStdout(cmd1, 'utf8', /*isRipgrep=*/false, (err1, stdout1) => {
			assert.equal(err1, null);
			for (const fileIn of filesIn) {
				assert.notStrictEqual(stdout1.split('\n').indexOf(fileIn), -1, stdout1);
			}
			for (const fileOut of filesOut) {
				assert.strictEqual(stdout1.split('\n').indexOf(fileOut), -1, stdout1);
			}
			done();
		});
	});

	function outputContains(stdout: string, ...files: string[]): boolean {
		const lines = stdout.split('\n');
		return files.every(file => lines.indexOf(file) >= 0);
	}
});
