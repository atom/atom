/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import * as path from 'path';
import { onUnexpectedError } from 'vs/base/common/errors';
import { IProgress, ITextQuery } from 'vs/platform/search/common/search';
import { FileWalker } from 'vs/workbench/services/search/node/fileSearch';
import { ISearchEngine, ISearchEngineSuccess, ISerializedFileMatch } from '../search';
import { ITextSearchWorkerProvider } from './textSearchWorkerProvider';
import { ISearchWorker, ISearchWorkerSearchArgs } from './worker/searchWorkerIpc';
import { IRawSearch } from 'vs/workbench/services/search/node/legacy/search';

export class Engine implements ISearchEngine<ISerializedFileMatch[]> {

	private static readonly PROGRESS_FLUSH_CHUNK_SIZE = 50; // optimization: number of files to process before emitting progress event

	private config: IRawSearch;
	private config2: ITextQuery;
	private walker: FileWalker;
	private walkerError: Error;

	private isCanceled = false;
	private isDone = false;
	private totalBytes = 0;
	private processedBytes = 0;
	private progressed = 0;
	private walkerIsDone = false;
	private limitReached = false;
	private numResults = 0;

	private workerProvider: ITextSearchWorkerProvider;
	private workers: ISearchWorker[];

	private nextWorker = 0;

	constructor(config: ITextQuery, walker: FileWalker, workerProvider: ITextSearchWorkerProvider) {
		this.config = makeRawSearch(config);
		this.config2 = config;
		this.walker = walker;
		this.workerProvider = workerProvider;
	}

	cancel(): void {
		this.isCanceled = true;
		this.walker.cancel();

		this.workers.forEach(w => {
			w.cancel()
				.then(null, onUnexpectedError);
		});
	}

	initializeWorkers(): void {
		this.workers.forEach(w => {
			w.initialize()
				.then(null, onUnexpectedError);
		});
	}

	search(onResult: (match: ISerializedFileMatch[]) => void, onProgress: (progress: IProgress) => void, done: (error: Error, complete: ISearchEngineSuccess) => void): void {
		this.workers = this.workerProvider.getWorkers();
		this.initializeWorkers();

		const fileEncoding = this.config.folderQueries.length === 1 ?
			this.config.folderQueries[0].fileEncoding || 'utf8' :
			'utf8';

		const progress = () => {
			if (++this.progressed % Engine.PROGRESS_FLUSH_CHUNK_SIZE === 0) {
				onProgress({ total: this.totalBytes, worked: this.processedBytes }); // buffer progress in chunks to reduce pressure
			}
		};

		const unwind = (processed: number) => {
			this.processedBytes += processed;

			// Emit progress() unless we got canceled or hit the limit
			if (processed && !this.isDone && !this.isCanceled && !this.limitReached) {
				progress();
			}

			// Emit done()
			if (!this.isDone && this.processedBytes === this.totalBytes && this.walkerIsDone) {
				this.isDone = true;
				done(this.walkerError, {
					limitHit: this.limitReached,
					stats: this.walker.getStats()
				});
			}
		};

		const run = (batch: string[], batchBytes: number): void => {
			const worker = this.workers[this.nextWorker];
			this.nextWorker = (this.nextWorker + 1) % this.workers.length;

			const maxResults = this.config.maxResults && (this.config.maxResults - this.numResults);
			const searchArgs: ISearchWorkerSearchArgs = { absolutePaths: batch, maxResults, pattern: this.config.contentPattern, fileEncoding, previewOptions: this.config.previewOptions };
			worker.search(searchArgs).then(result => {
				if (!result || this.limitReached || this.isCanceled) {
					return unwind(batchBytes);
				}

				const matches = result.matches;
				onResult(matches);
				this.numResults += result.numMatches;

				if (this.config.maxResults && this.numResults >= this.config.maxResults) {
					// It's possible to go over maxResults like this, but it's much simpler than trying to extract the exact number
					// of file matches, line matches, and matches within a line to == maxResults.
					this.limitReached = true;
				}

				unwind(batchBytes);
			},
				error => {
					// An error on the worker's end, not in reading the file, but in processing the batch. Log and continue.
					onUnexpectedError(error);
					unwind(batchBytes);
				});
		};

		// Walk over the file system
		let nextBatch: string[] = [];
		let nextBatchBytes = 0;
		const batchFlushBytes = 2 ** 20; // 1MB
		this.walker.walk(this.config2.folderQueries, this.config2.extraFileResources, result => {
			let bytes = result.size || 1;
			this.totalBytes += bytes;

			// If we have reached the limit or we are canceled, ignore it
			if (this.limitReached || this.isCanceled) {
				return unwind(bytes);
			}

			// Indicate progress to the outside
			progress();

			const absolutePath = result.base ? [result.base, result.relativePath].join(path.sep) : result.relativePath;
			nextBatch.push(absolutePath);
			nextBatchBytes += bytes;

			if (nextBatchBytes >= batchFlushBytes) {
				run(nextBatch, nextBatchBytes);
				nextBatch = [];
				nextBatchBytes = 0;
			}
		},
			onProgress,
			(error, isLimitHit) => {
				this.walkerIsDone = true;
				this.walkerError = error;

				// Send any remaining paths to a worker, or unwind if we're stopping
				if (nextBatch.length) {
					if (this.limitReached || this.isCanceled) {
						unwind(nextBatchBytes);
					} else {
						run(nextBatch, nextBatchBytes);
					}
				} else {
					unwind(0);
				}
			});
	}
}

/**
 * Exported for tests
 */
export function makeRawSearch(query: ITextQuery): IRawSearch {
	let rawSearch: IRawSearch = {
		folderQueries: [],
		extraFiles: [],
		excludePattern: query.excludePattern,
		includePattern: query.includePattern,
		maxResults: query.maxResults,
		useRipgrep: query.useRipgrep,
		disregardIgnoreFiles: query.folderQueries.some(fq => fq.disregardIgnoreFiles),
		disregardGlobalIgnoreFiles: query.folderQueries.some(fq => fq.disregardGlobalIgnoreFiles),
		ignoreSymlinks: query.folderQueries.some(fq => fq.ignoreSymlinks),
		previewOptions: query.previewOptions
	};

	for (const q of query.folderQueries) {
		rawSearch.folderQueries.push({
			excludePattern: q.excludePattern,
			includePattern: q.includePattern,
			fileEncoding: q.fileEncoding,
			disregardIgnoreFiles: q.disregardIgnoreFiles,
			disregardGlobalIgnoreFiles: q.disregardGlobalIgnoreFiles,
			folder: q.folder.fsPath
		});
	}

	if (query.extraFileResources) {
		for (const r of query.extraFileResources) {
			rawSearch.extraFiles.push(r.fsPath);
		}
	}

	rawSearch.contentPattern = query.contentPattern;

	return rawSearch;
}
