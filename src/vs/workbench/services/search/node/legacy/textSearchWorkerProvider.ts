/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import * as os from 'os';

import * as ipc from 'vs/base/parts/ipc/node/ipc';
import { Client } from 'vs/base/parts/ipc/node/ipc.cp';

import { ISearchWorker, SearchWorkerChannelClient } from './worker/searchWorkerIpc';
import { getPathFromAmdModule } from 'vs/base/common/amd';

export interface ITextSearchWorkerProvider {
	getWorkers(): ISearchWorker[];
}

export class TextSearchWorkerProvider implements ITextSearchWorkerProvider {
	private workers: ISearchWorker[] = [];

	getWorkers(): ISearchWorker[] {
		const numWorkers = os.cpus().length;
		while (this.workers.length < numWorkers) {
			this.createWorker();
		}

		return this.workers;
	}

	private createWorker(): void {
		let client = new Client(
			getPathFromAmdModule(require, 'bootstrap-fork'),
			{
				serverName: 'Search Worker ' + this.workers.length,
				args: ['--type=searchWorker'],
				timeout: 30 * 1000,
				env: {
					AMD_ENTRYPOINT: 'vs/workbench/services/search/node/legacy/worker/searchWorkerApp',
					PIPE_LOGGING: 'true',
					VERBOSE_LOGGING: process.env.VERBOSE_LOGGING
				},
				useQueue: true
			});

		const channel = ipc.getNextTickChannel(client.getChannel('searchWorker'));
		const channelClient = new SearchWorkerChannelClient(channel);

		this.workers.push(channelClient);
	}
}
