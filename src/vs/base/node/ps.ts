/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import { exec } from 'child_process';

import { getPathFromAmdModule } from 'vs/base/common/amd';

export interface ProcessItem {
	name: string;
	cmd: string;
	pid: number;
	ppid: number;
	load: number;
	mem: number;

	children?: ProcessItem[];
}

export function listProcesses(rootPid: number): Promise<ProcessItem> {

	return new Promise((resolve, reject) => {

		let rootItem: ProcessItem;
		const map = new Map<number, ProcessItem>();

		function addToTree(pid: number, ppid: number, cmd: string, load: number, mem: number) {

			const parent = map.get(ppid);
			if (pid === rootPid || parent) {

				const item: ProcessItem = {
					name: findName(cmd),
					cmd,
					pid,
					ppid,
					load,
					mem
				};
				map.set(pid, item);

				if (pid === rootPid) {
					rootItem = item;
				}

				if (parent) {
					if (!parent.children) {
						parent.children = [];
					}
					parent.children.push(item);
					if (parent.children.length > 1) {
						parent.children = parent.children.sort((a, b) => a.pid - b.pid);
					}
				}
			}
		}

		function findName(cmd: string): string {

			const SHARED_PROCESS_HINT = /--disable-blink-features=Auxclick/;
			const WINDOWS_WATCHER_HINT = /\\watcher\\win32\\CodeHelper\.exe/;
			const WINDOWS_CRASH_REPORTER = /--crashes-directory/;
			const WINDOWS_PTY = /\\pipe\\winpty-control/;
			const WINDOWS_CONSOLE_HOST = /conhost\.exe/;
			const TYPE = /--type=([a-zA-Z-]+)/;

			// find windows file watcher
			if (WINDOWS_WATCHER_HINT.exec(cmd)) {
				return 'watcherService ';
			}

			// find windows crash reporter
			if (WINDOWS_CRASH_REPORTER.exec(cmd)) {
				return 'electron-crash-reporter';
			}

			// find windows pty process
			if (WINDOWS_PTY.exec(cmd)) {
				return 'winpty-process';
			}

			//find windows console host process
			if (WINDOWS_CONSOLE_HOST.exec(cmd)) {
				return 'console-window-host (Windows internal process)';
			}

			// find "--type=xxxx"
			let matches = TYPE.exec(cmd);
			if (matches && matches.length === 2) {
				if (matches[1] === 'renderer') {
					if (SHARED_PROCESS_HINT.exec(cmd)) {
						return 'shared-process';
					}

					return `window`;
				}
				return matches[1];
			}

			// find all xxxx.js
			const JS = /[a-zA-Z-]+\.js/g;
			let result = '';
			do {
				matches = JS.exec(cmd);
				if (matches) {
					result += matches + ' ';
				}
			} while (matches);

			if (result) {
				if (cmd.indexOf('node ') !== 0) {
					return `electron_node ${result}`;
				}
			}
			return cmd;
		}

		if (process.platform === 'win32') {

			const cleanUNCPrefix = (value: string): string => {
				if (value.indexOf('\\\\?\\') === 0) {
					return value.substr(4);
				} else if (value.indexOf('\\??\\') === 0) {
					return value.substr(4);
				} else if (value.indexOf('"\\\\?\\') === 0) {
					return '"' + value.substr(5);
				} else if (value.indexOf('"\\??\\') === 0) {
					return '"' + value.substr(5);
				} else {
					return value;
				}
			};

			(import('windows-process-tree')).then(windowsProcessTree => {
				windowsProcessTree.getProcessList(rootPid, (processList) => {
					windowsProcessTree.getProcessCpuUsage(processList, (completeProcessList) => {
						const processItems: Map<number, ProcessItem> = new Map();
						completeProcessList.forEach(process => {
							const commandLine = cleanUNCPrefix(process.commandLine || '');
							processItems.set(process.pid, {
								name: findName(commandLine),
								cmd: commandLine,
								pid: process.pid,
								ppid: process.ppid,
								load: process.cpu || 0,
								mem: process.memory || 0
							});
						});

						rootItem = processItems.get(rootPid);
						if (rootItem) {
							processItems.forEach(item => {
								let parent = processItems.get(item.ppid);
								if (parent) {
									if (!parent.children) {
										parent.children = [];
									}
									parent.children.push(item);
								}
							});

							processItems.forEach(item => {
								if (item.children) {
									item.children = item.children.sort((a, b) => a.pid - b.pid);
								}
							});
							resolve(rootItem);
						} else {
							reject(new Error(`Root process ${rootPid} not found`));
						}
					});
				}, windowsProcessTree.ProcessDataFlag.CommandLine | windowsProcessTree.ProcessDataFlag.Memory);
			});
		} else {	// OS X & Linux

			const CMD = '/bin/ps -ax -o pid=,ppid=,pcpu=,pmem=,command=';
			const PID_CMD = /^\s*([0-9]+)\s+([0-9]+)\s+([0-9]+\.[0-9]+)\s+([0-9]+\.[0-9]+)\s+(.+)$/;

			exec(CMD, { maxBuffer: 1000 * 1024 }, (err, stdout, stderr) => {

				if (err || stderr) {
					reject(err || stderr.toString());
				} else {

					const lines = stdout.toString().split('\n');
					for (const line of lines) {
						let matches = PID_CMD.exec(line.trim());
						if (matches && matches.length === 6) {
							addToTree(parseInt(matches[1]), parseInt(matches[2]), matches[5], parseFloat(matches[3]), parseFloat(matches[4]));
						}
					}

					if (process.platform === 'linux') {
						// Flatten rootItem to get a list of all VSCode processes
						let processes = [rootItem];
						const pids: number[] = [];
						while (processes.length) {
							const process = processes.shift();
							if (process) {
								pids.push(process.pid);
								if (process.children) {
									processes = processes.concat(process.children);
								}
							}
						}

						// The cpu usage value reported on Linux is the average over the process lifetime,
						// recalculate the usage over a one second interval
						// JSON.stringify is needed to escape spaces, https://github.com/nodejs/node/issues/6803
						let cmd = JSON.stringify(getPathFromAmdModule(require, 'vs/base/node/cpuUsage.sh'));
						cmd += ' ' + pids.join(' ');

						exec(cmd, {}, (err, stdout, stderr) => {
							if (err || stderr) {
								reject(err || stderr.toString());
							} else {
								const cpuUsage = stdout.toString().split('\n');
								for (let i = 0; i < pids.length; i++) {
									const processInfo = map.get(pids[i]);
									processInfo.load = parseFloat(cpuUsage[i]);
								}

								resolve(rootItem);
							}
						});
					} else {
						resolve(rootItem);
					}

				}
			});
		}
	});
}
