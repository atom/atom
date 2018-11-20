/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import { spawn, ChildProcess } from 'child_process';
import { assign } from 'vs/base/common/objects';
import { parseCLIProcessArgv, buildHelpMessage } from 'vs/platform/environment/node/argv';
import { ParsedArgs } from 'vs/platform/environment/common/environment';
import product from 'vs/platform/node/product';
import pkg from 'vs/platform/node/package';
import * as paths from 'path';
import * as os from 'os';
import * as fs from 'fs';
import { whenDeleted } from 'vs/base/node/pfs';
import { findFreePort, randomPort } from 'vs/base/node/ports';
import { resolveTerminalEncoding } from 'vs/base/node/encoding';
import * as iconv from 'iconv-lite';
import { writeFileAndFlushSync } from 'vs/base/node/extfs';
import { isWindows } from 'vs/base/common/platform';
import { ProfilingSession, Target } from 'v8-inspect-profiler';
import { createWaitMarkerFile } from 'vs/code/node/wait';

function shouldSpawnCliProcess(argv: ParsedArgs): boolean {
	return !!argv['install-source']
		|| !!argv['list-extensions']
		|| !!argv['install-extension']
		|| !!argv['uninstall-extension'];
}

interface IMainCli {
	main: (argv: ParsedArgs) => Thenable<void>;
}

export async function main(argv: string[]): Promise<any> {
	let args: ParsedArgs;

	try {
		args = parseCLIProcessArgv(argv);
	} catch (err) {
		console.error(err.message);
		return;
	}

	// Help
	if (args.help) {
		console.log(buildHelpMessage(product.nameLong, product.applicationName, pkg.version));
	}

	// Version Info
	else if (args.version) {
		console.log(`${pkg.version}\n${product.commit}\n${process.arch}`);
	}

	// Extensions Management
	else if (shouldSpawnCliProcess(args)) {
		const cli = await new Promise<IMainCli>((c, e) => require(['vs/code/node/cliProcessMain'], c, e));
		await cli.main(args);
		return;
	}

	// Write File
	else if (args['file-write']) {
		const source = args._[0];
		const target = args._[1];

		// Validate
		if (
			!source || !target || source === target ||					// make sure source and target are provided and are not the same
			!paths.isAbsolute(source) || !paths.isAbsolute(target) ||	// make sure both source and target are absolute paths
			!fs.existsSync(source) || !fs.statSync(source).isFile() ||	// make sure source exists as file
			!fs.existsSync(target) || !fs.statSync(target).isFile()		// make sure target exists as file
		) {
			throw new Error('Using --file-write with invalid arguments.');
		}

		try {

			// Check for readonly status and chmod if so if we are told so
			let targetMode: number = 0;
			let restoreMode = false;
			if (!!args['file-chmod']) {
				targetMode = fs.statSync(target).mode;
				if (!(targetMode & 128) /* readonly */) {
					fs.chmodSync(target, targetMode | 128);
					restoreMode = true;
				}
			}

			// Write source to target
			const data = fs.readFileSync(source);
			if (isWindows) {
				// On Windows we use a different strategy of saving the file
				// by first truncating the file and then writing with r+ mode.
				// This helps to save hidden files on Windows
				// (see https://github.com/Microsoft/vscode/issues/931) and
				// prevent removing alternate data streams
				// (see https://github.com/Microsoft/vscode/issues/6363)
				fs.truncateSync(target, 0);
				writeFileAndFlushSync(target, data, { flag: 'r+' });
			} else {
				writeFileAndFlushSync(target, data);
			}

			// Restore previous mode as needed
			if (restoreMode) {
				fs.chmodSync(target, targetMode);
			}
		} catch (error) {
			error.message = `Error using --file-write: ${error.message}`;
			throw error;
		}
	}

	// Just Code
	else {
		const env = assign({}, process.env, {
			'VSCODE_CLI': '1', // this will signal Code that it was spawned from this module
			'ELECTRON_NO_ATTACH_CONSOLE': '1'
		});

		delete env['ELECTRON_RUN_AS_NODE'];

		const processCallbacks: ((child: ChildProcess) => Thenable<any>)[] = [];

		const verbose = args.verbose || args.status || typeof args['upload-logs'] !== 'undefined';
		if (verbose) {
			env['ELECTRON_ENABLE_LOGGING'] = '1';

			processCallbacks.push(async child => {
				child.stdout.on('data', (data: Buffer) => console.log(data.toString('utf8').trim()));
				child.stderr.on('data', (data: Buffer) => console.log(data.toString('utf8').trim()));

				await new Promise(c => child.once('exit', () => c()));
			});
		}

		let stdinWithoutTty: boolean = false;
		try {
			stdinWithoutTty = !process.stdin.isTTY; // Via https://twitter.com/MylesBorins/status/782009479382626304
		} catch (error) {
			// Windows workaround for https://github.com/nodejs/node/issues/11656
		}

		const readFromStdin = args._.some(a => a === '-');
		if (readFromStdin) {
			// remove the "-" argument when we read from stdin
			args._ = args._.filter(a => a !== '-');
			argv = argv.filter(a => a !== '-');
		}

		let stdinFilePath: string;
		if (stdinWithoutTty) {

			// Read from stdin: we require a single "-" argument to be passed in order to start reading from
			// stdin. We do this because there is no reliable way to find out if data is piped to stdin. Just
			// checking for stdin being connected to a TTY is not enough (https://github.com/Microsoft/vscode/issues/40351)
			if (args._.length === 0 && readFromStdin) {

				// prepare temp file to read stdin to
				stdinFilePath = paths.join(os.tmpdir(), `code-stdin-${Math.random().toString(36).replace(/[^a-z]+/g, '').substr(0, 3)}.txt`);

				// open tmp file for writing
				let stdinFileError: Error | undefined;
				let stdinFileStream: fs.WriteStream;
				try {
					stdinFileStream = fs.createWriteStream(stdinFilePath);
				} catch (error) {
					stdinFileError = error;
				}

				if (!stdinFileError) {

					// Pipe into tmp file using terminals encoding
					resolveTerminalEncoding(verbose).then(encoding => {
						const converterStream = iconv.decodeStream(encoding);
						process.stdin.pipe(converterStream).pipe(stdinFileStream);
					});

					// Make sure to open tmp file
					argv.push(stdinFilePath);

					// Enable --wait to get all data and ignore adding this to history
					argv.push('--wait');
					argv.push('--skip-add-to-recently-opened');
					args.wait = true;
				}

				if (verbose) {
					if (stdinFileError) {
						console.error(`Failed to create file to read via stdin: ${stdinFileError.toString()}`);
					} else {
						console.log(`Reading from stdin via: ${stdinFilePath}`);
					}
				}
			}

			// If the user pipes data via stdin but forgot to add the "-" argument, help by printing a message
			// if we detect that data flows into via stdin after a certain timeout.
			else if (args._.length === 0) {
				processCallbacks.push(child => new Promise(c => {
					const dataListener = () => {
						if (isWindows) {
							console.log(`Run with '${product.applicationName} -' to read output from another program (e.g. 'echo Hello World | ${product.applicationName} -').`);
						} else {
							console.log(`Run with '${product.applicationName} -' to read from stdin (e.g. 'ps aux | grep code | ${product.applicationName} -').`);
						}

						c(void 0);
					};

					// wait for 1s maximum...
					setTimeout(() => {
						process.stdin.removeListener('data', dataListener);

						c(void 0);
					}, 1000);

					// ...but finish early if we detect data
					process.stdin.once('data', dataListener);
				}));
			}
		}

		// If we are started with --wait create a random temporary file
		// and pass it over to the starting instance. We can use this file
		// to wait for it to be deleted to monitor that the edited file
		// is closed and then exit the waiting process.
		let waitMarkerFilePath: string | undefined;
		if (args.wait) {
			waitMarkerFilePath = await createWaitMarkerFile(verbose);
			if (waitMarkerFilePath) {
				argv.push('--waitMarkerFilePath', waitMarkerFilePath);
			}
		}

		// If we have been started with `--prof-startup` we need to find free ports to profile
		// the main process, the renderer, and the extension host. We also disable v8 cached data
		// to get better profile traces. Last, we listen on stdout for a signal that tells us to
		// stop profiling.
		if (args['prof-startup']) {
			const portMain = await findFreePort(randomPort(), 10, 3000);
			const portRenderer = await findFreePort(portMain + 1, 10, 3000);
			const portExthost = await findFreePort(portRenderer + 1, 10, 3000);

			// fail the operation when one of the ports couldn't be accquired.
			if (portMain * portRenderer * portExthost === 0) {
				throw new Error('Failed to find free ports for profiler. Make sure to shutdown all instances of the editor first.');
			}

			const filenamePrefix = paths.join(os.homedir(), 'prof-' + Math.random().toString(16).slice(-4));

			argv.push(`--inspect-brk=${portMain}`);
			argv.push(`--remote-debugging-port=${portRenderer}`);
			argv.push(`--inspect-brk-extensions=${portExthost}`);
			argv.push(`--prof-startup-prefix`, filenamePrefix);
			argv.push(`--no-cached-data`);

			fs.writeFileSync(filenamePrefix, argv.slice(-6).join('|'));

			processCallbacks.push(async _child => {

				class Profiler {
					static async start(name: string, filenamePrefix: string, opts: { port: number, tries?: number, target?: (targets: Target[]) => Target }) {
						const profiler = await import('v8-inspect-profiler');

						let session: ProfilingSession;
						try {
							session = await profiler.startProfiling(opts);
						} catch (err) {
							console.error(`FAILED to start profiling for '${name}' on port '${opts.port}'`);
						}

						return {
							async stop() {
								if (!session) {
									return;
								}
								let suffix = '';
								let profile = await session.stop();
								if (!process.env['VSCODE_DEV']) {
									// when running from a not-development-build we remove
									// absolute filenames because we don't want to reveal anything
									// about users. We also append the `.txt` suffix to make it
									// easier to attach these files to GH issues
									profile = profiler.rewriteAbsolutePaths(profile, 'piiRemoved');
									suffix = '.txt';
								}

								await profiler.writeProfile(profile, `${filenamePrefix}.${name}.cpuprofile${suffix}`);
							}
						};
					}
				}

				try {
					// load and start profiler
					const mainProfileRequest = Profiler.start('main', filenamePrefix, { port: portMain });
					const extHostProfileRequest = Profiler.start('extHost', filenamePrefix, { port: portExthost, tries: 300 });
					const rendererProfileRequest = Profiler.start('renderer', filenamePrefix, {
						port: portRenderer,
						tries: 200,
						target: function (targets) {
							return targets.filter(target => {
								if (!target.webSocketDebuggerUrl) {
									return false;
								}
								if (target.type === 'page') {
									return target.url.indexOf('workbench/workbench.html') > 0;
								} else {
									return true;
								}
							})[0];
						}
					});

					const main = await mainProfileRequest;
					const extHost = await extHostProfileRequest;
					const renderer = await rendererProfileRequest;

					// wait for the renderer to delete the
					// marker file
					await whenDeleted(filenamePrefix);

					// stop profiling
					await main.stop();
					await renderer.stop();
					await extHost.stop();

					// re-create the marker file to signal that profiling is done
					fs.writeFileSync(filenamePrefix, '');

				} catch (e) {
					console.error('Failed to profile startup. Make sure to quit Code first.');
				}
			});
		}

		if (args['js-flags']) {
			const match = /max_old_space_size=(\d+)/g.exec(args['js-flags']);
			if (match && !args['max-memory']) {
				argv.push(`--max-memory=${match[1]}`);
			}
		}

		const options = {
			detached: true,
			env
		};

		if (typeof args['upload-logs'] !== 'undefined') {
			options['stdio'] = ['pipe', 'pipe', 'pipe'];
		} else if (!verbose) {
			options['stdio'] = 'ignore';
		}

		const child = spawn(process.execPath, argv.slice(2), options);

		if (args.wait && waitMarkerFilePath) {
			return new Promise<void>(c => {

				// Complete when process exits
				child.once('exit', () => c(void 0));

				// Complete when wait marker file is deleted
				whenDeleted(waitMarkerFilePath!).then(c, c);
			}).then(() => {

				// Make sure to delete the tmp stdin file if we have any
				if (stdinFilePath) {
					fs.unlinkSync(stdinFilePath);
				}
			});
		}

		return Promise.all(processCallbacks.map(callback => callback(child)));
	}
}

function eventuallyExit(code: number): void {
	setTimeout(() => process.exit(code), 0);
}

main(process.argv)
	.then(() => eventuallyExit(0))
	.then(null, err => {
		console.error(err.message || err.stack || err);
		eventuallyExit(1);
	});
