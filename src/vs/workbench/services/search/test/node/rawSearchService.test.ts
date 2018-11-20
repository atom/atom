/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import * as assert from 'assert';
import * as path from 'path';
import { getPathFromAmdModule } from 'vs/base/common/amd';
import { CancelablePromise, createCancelablePromise } from 'vs/base/common/async';
import { Emitter, Event } from 'vs/base/common/event';
import { URI } from 'vs/base/common/uri';
import { IFileQuery, IFileSearchStats, IFolderQuery, IProgress, ISearchEngineStats, QueryType } from 'vs/platform/search/common/search';
import { SearchService as RawSearchService } from 'vs/workbench/services/search/node/rawSearchService';
import { IRawFileMatch, ISearchEngine, ISearchEngineSuccess, ISerializedFileMatch, ISerializedSearchComplete, ISerializedSearchProgressItem, ISerializedSearchSuccess } from 'vs/workbench/services/search/node/search';
import { DiskSearch } from 'vs/workbench/services/search/node/searchService';

const TEST_FOLDER_QUERIES = [
	{ folder: URI.file(path.normalize('/some/where')) }
];

const TEST_FIXTURES = path.normalize(getPathFromAmdModule(require, './fixtures'));
const MULTIROOT_QUERIES: IFolderQuery[] = [
	{ folder: URI.file(path.join(TEST_FIXTURES, 'examples')) },
	{ folder: URI.file(path.join(TEST_FIXTURES, 'more')) }
];

const stats: ISearchEngineStats = {
	traversal: 'node',
	fileWalkTime: 0,
	cmdTime: 1,
	directoriesWalked: 2,
	filesWalked: 3
};

class TestSearchEngine implements ISearchEngine<IRawFileMatch> {

	public static last: TestSearchEngine;

	private isCanceled = false;

	constructor(private result: () => IRawFileMatch, public config?: IFileQuery) {
		TestSearchEngine.last = this;
	}

	public search(onResult: (match: IRawFileMatch) => void, onProgress: (progress: IProgress) => void, done: (error: Error, complete: ISearchEngineSuccess) => void): void {
		const self = this;
		(function next() {
			process.nextTick(() => {
				if (self.isCanceled) {
					done(null, {
						limitHit: false,
						stats: stats
					});
					return;
				}
				const result = self.result();
				if (!result) {
					done(null, {
						limitHit: false,
						stats: stats
					});
				} else {
					onResult(result);
					next();
				}
			});
		})();
	}

	public cancel(): void {
		this.isCanceled = true;
	}
}

const testTimeout = 5000;

suite('RawSearchService', () => {

	const rawSearch: IFileQuery = {
		type: QueryType.File,
		folderQueries: TEST_FOLDER_QUERIES,
		filePattern: 'a'
	};

	const rawMatch: IRawFileMatch = {
		base: path.normalize('/some'),
		relativePath: 'where',
		basename: 'where',
		size: 123
	};

	const match: ISerializedFileMatch = {
		path: path.normalize('/some/where')
	};

	test('Individual results', async function () {
		this.timeout(testTimeout);
		let i = 5;
		const Engine = TestSearchEngine.bind(null, () => i-- && rawMatch);
		const service = new RawSearchService();

		let results = 0;
		const cb: (p: ISerializedSearchProgressItem) => void = value => {
			if (!Array.isArray(value)) {
				assert.deepStrictEqual(value, match);
				results++;
			} else {
				assert.fail(JSON.stringify(value));
			}
		};

		await service.doFileSearchWithEngine(Engine, rawSearch, cb, null, 0);
		return assert.strictEqual(results, 5);
	});

	test('Batch results', async function () {
		this.timeout(testTimeout);
		let i = 25;
		const Engine = TestSearchEngine.bind(null, () => i-- && rawMatch);
		const service = new RawSearchService();

		const results = [];
		const cb: (p: ISerializedSearchProgressItem) => void = value => {
			if (Array.isArray(value)) {
				value.forEach(m => {
					assert.deepStrictEqual(m, match);
				});
				results.push(value.length);
			} else {
				assert.fail(JSON.stringify(value));
			}
		};

		await service.doFileSearchWithEngine(Engine, rawSearch, cb, undefined, 10);
		assert.deepStrictEqual(results, [10, 10, 5]);
	});

	test('Collect batched results', async function () {
		this.timeout(testTimeout);
		const uriPath = '/some/where';
		let i = 25;
		const Engine = TestSearchEngine.bind(null, () => i-- && rawMatch);
		const service = new RawSearchService();

		function fileSearch(config: IFileQuery, batchSize: number): Event<ISerializedSearchProgressItem | ISerializedSearchComplete> {
			let promise: CancelablePromise<ISerializedSearchSuccess>;

			const emitter = new Emitter<ISerializedSearchProgressItem | ISerializedSearchComplete>({
				onFirstListenerAdd: () => {
					promise = createCancelablePromise(token => service.doFileSearchWithEngine(Engine, config, p => emitter.fire(p), token, batchSize)
						.then(c => emitter.fire(c), err => emitter.fire({ type: 'error', error: err })));
				},
				onLastListenerRemove: () => {
					promise.cancel();
				}
			});

			return emitter.event;
		}

		const progressResults = [];
		const onProgress = match => {
			assert.strictEqual(match.resource.path, uriPath);
			progressResults.push(match);
		};

		const result_2 = await DiskSearch.collectResultsFromEvent(fileSearch(rawSearch, 10), onProgress);
		assert.strictEqual(result_2.results.length, 25, 'Result');
		assert.strictEqual(progressResults.length, 25, 'Progress');
	});

	test('Multi-root with include pattern and maxResults', async function () {
		this.timeout(testTimeout);
		const service = new RawSearchService();

		const query: IFileQuery = {
			type: QueryType.File,
			folderQueries: MULTIROOT_QUERIES,
			maxResults: 1,
			includePattern: {
				'*.txt': true,
				'*.js': true
			},
		};

		const result = await DiskSearch.collectResultsFromEvent(service.fileSearch(query));
		assert.strictEqual(result.results.length, 1, 'Result');
	});

	test('Multi-root with include pattern and exists', async function () {
		this.timeout(testTimeout);
		const service = new RawSearchService();

		const query: IFileQuery = {
			type: QueryType.File,
			folderQueries: MULTIROOT_QUERIES,
			exists: true,
			includePattern: {
				'*.txt': true,
				'*.js': true
			},
		};

		const result = await DiskSearch.collectResultsFromEvent(service.fileSearch(query));
		assert.strictEqual(result.results.length, 0, 'Result');
		assert.ok(result.limitHit);
	});

	test('Sorted results', async function () {
		this.timeout(testTimeout);
		const paths = ['bab', 'bbc', 'abb'];
		const matches: IRawFileMatch[] = paths.map(relativePath => ({
			base: path.normalize('/some/where'),
			relativePath,
			basename: relativePath,
			size: 3
		}));
		const Engine = TestSearchEngine.bind(null, () => matches.shift());
		const service = new RawSearchService();

		const results = [];
		const cb = value => {
			if (Array.isArray(value)) {
				results.push(...value.map(v => v.path));
			} else {
				assert.fail(JSON.stringify(value));
			}
		};

		await service.doFileSearchWithEngine(Engine, {
			type: QueryType.File,
			folderQueries: TEST_FOLDER_QUERIES,
			filePattern: 'bb',
			sortByScore: true,
			maxResults: 2
		}, cb, undefined, 1);
		assert.notStrictEqual(typeof TestSearchEngine.last.config.maxResults, 'number');
		assert.deepStrictEqual(results, [path.normalize('/some/where/bbc'), path.normalize('/some/where/bab')]);
	});

	test('Sorted result batches', async function () {
		this.timeout(testTimeout);
		let i = 25;
		const Engine = TestSearchEngine.bind(null, () => i-- && rawMatch);
		const service = new RawSearchService();

		const results = [];
		const cb = value => {
			if (Array.isArray(value)) {
				value.forEach(m => {
					assert.deepStrictEqual(m, match);
				});
				results.push(value.length);
			} else {
				assert.fail(JSON.stringify(value));
			}
		};
		await service.doFileSearchWithEngine(Engine, {
			type: QueryType.File,
			folderQueries: TEST_FOLDER_QUERIES,
			filePattern: 'a',
			sortByScore: true,
			maxResults: 23
		}, cb, undefined, 10);
		assert.deepStrictEqual(results, [10, 10, 3]);
	});

	test('Cached results', function () {
		this.timeout(testTimeout);
		const paths = ['bcb', 'bbc', 'aab'];
		const matches: IRawFileMatch[] = paths.map(relativePath => ({
			base: path.normalize('/some/where'),
			relativePath,
			basename: relativePath,
			size: 3
		}));
		const Engine = TestSearchEngine.bind(null, () => matches.shift());
		const service = new RawSearchService();

		const results = [];
		const cb = value => {
			if (Array.isArray(value)) {
				results.push(...value.map(v => v.path));
			} else {
				assert.fail(JSON.stringify(value));
			}
		};
		return service.doFileSearchWithEngine(Engine, {
			type: QueryType.File,
			folderQueries: TEST_FOLDER_QUERIES,
			filePattern: 'b',
			sortByScore: true,
			cacheKey: 'x'
		}, cb, undefined, -1).then(complete => {
			assert.strictEqual((<IFileSearchStats>complete.stats).fromCache, false);
			assert.deepStrictEqual(results, [path.normalize('/some/where/bcb'), path.normalize('/some/where/bbc'), path.normalize('/some/where/aab')]);
		}).then(async () => {
			const results = [];
			const cb = value => {
				if (Array.isArray(value)) {
					results.push(...value.map(v => v.path));
				} else {
					assert.fail(JSON.stringify(value));
				}
			};
			try {
				const complete = await service.doFileSearchWithEngine(Engine, {
					type: QueryType.File,
					folderQueries: TEST_FOLDER_QUERIES,
					filePattern: 'bc',
					sortByScore: true,
					cacheKey: 'x'
				}, cb, undefined, -1);
				assert.ok((<IFileSearchStats>complete.stats).fromCache);
				assert.deepStrictEqual(results, [path.normalize('/some/where/bcb'), path.normalize('/some/where/bbc')]);
			}
			catch (e) { }
		}).then(() => {
			return service.clearCache('x');
		}).then(async () => {
			matches.push({
				base: path.normalize('/some/where'),
				relativePath: 'bc',
				basename: 'bc',
				size: 3
			});
			const results = [];
			const cb = value => {
				if (Array.isArray(value)) {
					results.push(...value.map(v => v.path));
				} else {
					assert.fail(JSON.stringify(value));
				}
			};
			const complete = await service.doFileSearchWithEngine(Engine, {
				type: QueryType.File,
				folderQueries: TEST_FOLDER_QUERIES,
				filePattern: 'bc',
				sortByScore: true,
				cacheKey: 'x'
			}, cb, undefined, -1);
			assert.strictEqual((<IFileSearchStats>complete.stats).fromCache, false);
			assert.deepStrictEqual(results, [path.normalize('/some/where/bc')]);
		});
	});
});
