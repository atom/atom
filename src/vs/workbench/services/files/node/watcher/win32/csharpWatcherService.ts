/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import * as cp from 'child_process';

import { FileChangeType } from 'vs/platform/files/common/files';
import * as decoder from 'vs/base/node/decoder';
import * as glob from 'vs/base/common/glob';

import { IRawFileChange } from 'vs/workbench/services/files/node/watcher/common';
import { getPathFromAmdModule } from 'vs/base/common/amd';

export class OutOfProcessWin32FolderWatcher {

	private static readonly MAX_RESTARTS = 5;

	private static changeTypeMap: FileChangeType[] = [FileChangeType.UPDATED, FileChangeType.ADDED, FileChangeType.DELETED];

	private ignored: glob.ParsedPattern[];

	private handle: cp.ChildProcess;
	private restartCounter: number;

	constructor(
		private watchedFolder: string,
		ignored: string[],
		private eventCallback: (events: IRawFileChange[]) => void,
		private errorCallback: (error: string) => void,
		private verboseLogging: boolean
	) {
		this.restartCounter = 0;

		if (Array.isArray(ignored)) {
			this.ignored = ignored.map(i => glob.parse(i));
		} else {
			this.ignored = [];
		}

		this.startWatcher();
	}

	private startWatcher(): void {
		const args = [this.watchedFolder];
		if (this.verboseLogging) {
			args.push('-verbose');
		}

		this.handle = cp.spawn(getPathFromAmdModule(require, 'vs/workbench/services/files/node/watcher/win32/CodeHelper.exe'), args);

		const stdoutLineDecoder = new decoder.LineDecoder();

		// Events over stdout
		this.handle.stdout.on('data', (data: Buffer) => {

			// Collect raw events from output
			const rawEvents: IRawFileChange[] = [];
			stdoutLineDecoder.write(data).forEach((line) => {
				const eventParts = line.split('|');
				if (eventParts.length === 2) {
					const changeType = Number(eventParts[0]);
					const absolutePath = eventParts[1];

					// File Change Event (0 Changed, 1 Created, 2 Deleted)
					if (changeType >= 0 && changeType < 3) {

						// Support ignores
						if (this.ignored && this.ignored.some(ignore => ignore(absolutePath))) {
							if (this.verboseLogging) {
								console.log('%c[File Watcher (C#)]', 'color: blue', ' >> ignored', absolutePath);
							}

							return;
						}

						// Otherwise record as event
						rawEvents.push({
							type: OutOfProcessWin32FolderWatcher.changeTypeMap[changeType],
							path: absolutePath
						});
					}

					// 3 Logging
					else {
						console.log('%c[File Watcher (C#)]', 'color: blue', eventParts[1]);
					}
				}
			});

			// Trigger processing of events through the delayer to batch them up properly
			if (rawEvents.length > 0) {
				this.eventCallback(rawEvents);
			}
		});

		// Errors
		this.handle.on('error', (error: Error) => this.onError(error));
		this.handle.stderr.on('data', (data: Buffer) => this.onError(data));

		// Exit
		this.handle.on('exit', (code: number, signal: string) => this.onExit(code, signal));
	}

	private onError(error: Error | Buffer): void {
		this.errorCallback('[File Watcher (C#)] process error: ' + error.toString());
	}

	private onExit(code: number, signal: string): void {
		if (this.handle) { // exit while not yet being disposed is unexpected!
			this.errorCallback(`[File Watcher (C#)] terminated unexpectedly (code: ${code}, signal: ${signal})`);

			if (this.restartCounter <= OutOfProcessWin32FolderWatcher.MAX_RESTARTS) {
				this.errorCallback('[File Watcher (C#)] is restarted again...');
				this.restartCounter++;
				this.startWatcher(); // restart
			} else {
				this.errorCallback('[File Watcher (C#)] Watcher failed to start after retrying for some time, giving up. Please report this as a bug report!');
			}
		}
	}

	public dispose(): void {
		if (this.handle) {
			this.handle.kill();
			this.handle = null!; // StrictNullOverride: nulling out ok in dispose
		}
	}
}
