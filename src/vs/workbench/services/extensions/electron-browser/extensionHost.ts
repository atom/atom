/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import * as nls from 'vs/nls';
import { ChildProcess, fork } from 'child_process';
import { ipcRenderer as ipc } from 'electron';
import { Server, Socket, createServer } from 'net';
import { getPathFromAmdModule } from 'vs/base/common/amd';
import { timeout } from 'vs/base/common/async';
import { toErrorMessage } from 'vs/base/common/errorMessage';
import { onUnexpectedError } from 'vs/base/common/errors';
import { Emitter, Event, anyEvent, debounceEvent, fromNodeEventEmitter, mapEvent } from 'vs/base/common/event';
import { IDisposable, dispose, toDisposable } from 'vs/base/common/lifecycle';
import { Schemas } from 'vs/base/common/network';
import * as objects from 'vs/base/common/objects';
import { isWindows } from 'vs/base/common/platform';
import { isEqual } from 'vs/base/common/resources';
import { URI } from 'vs/base/common/uri';
import { TPromise } from 'vs/base/common/winjs.base';
import { IRemoteConsoleLog, log, parse } from 'vs/base/node/console';
import { findFreePort, randomPort } from 'vs/base/node/ports';
import { IMessagePassingProtocol } from 'vs/base/parts/ipc/node/ipc';
import { Protocol, generateRandomPipeName } from 'vs/base/parts/ipc/node/ipc.net';
import { IBroadcast, IBroadcastService } from 'vs/platform/broadcast/electron-browser/broadcastService';
import { getScopes } from 'vs/platform/configuration/common/configurationRegistry';
import { IEnvironmentService } from 'vs/platform/environment/common/environment';
import { EXTENSION_ATTACH_BROADCAST_CHANNEL, EXTENSION_CLOSE_EXTHOST_BROADCAST_CHANNEL, EXTENSION_LOG_BROADCAST_CHANNEL, EXTENSION_RELOAD_BROADCAST_CHANNEL, EXTENSION_TERMINATE_BROADCAST_CHANNEL } from 'vs/platform/extensions/common/extensionHost';
import { ILabelService } from 'vs/platform/label/common/label';
import { ILifecycleService, WillShutdownEvent } from 'vs/platform/lifecycle/common/lifecycle';
import { ILogService } from 'vs/platform/log/common/log';
import product from 'vs/platform/node/product';
import { INotificationService, Severity } from 'vs/platform/notification/common/notification';
import { ITelemetryService } from 'vs/platform/telemetry/common/telemetry';
import { IWindowService, IWindowsService } from 'vs/platform/windows/common/windows';
import { IWorkspaceContextService, WorkbenchState } from 'vs/platform/workspace/common/workspace';
import { IConfigurationInitData, IInitData } from 'vs/workbench/api/node/extHost.protocol';
import { MessageType, createMessageOfType, isMessageOfType } from 'vs/workbench/common/extensionHostProtocol';
import { IWorkspaceConfigurationService } from 'vs/workbench/services/configuration/common/configuration';
import { ICrashReporterService } from 'vs/workbench/services/crashReporter/electron-browser/crashReporterService';
import { IExtensionDescription } from 'vs/workbench/services/extensions/common/extensions';

export interface IExtensionHostStarter {
	readonly onCrashed: Event<[number, string]>;
	start(): TPromise<IMessagePassingProtocol>;
	getInspectPort(): number;
	dispose(): void;
}

export interface IExtensionDevOptions {
	readonly isExtensionDevHost: boolean;
	readonly isExtensionDevDebug: boolean;
	readonly isExtensionDevDebugBrk: boolean;
	readonly isExtensionDevTestFromCli: boolean;
}
export function parseExtensionDevOptions(environmentService: IEnvironmentService): IExtensionDevOptions {
	// handle extension host lifecycle a bit special when we know we are developing an extension that runs inside
	let isExtensionDevHost = environmentService.isExtensionDevelopment;
	const extDevLoc = environmentService.extensionDevelopmentLocationURI;
	const debugOk = !extDevLoc || extDevLoc.scheme === Schemas.file;
	let isExtensionDevDebug = debugOk && typeof environmentService.debugExtensionHost.port === 'number';
	let isExtensionDevDebugBrk = debugOk && !!environmentService.debugExtensionHost.break;
	let isExtensionDevTestFromCli = isExtensionDevHost && !!environmentService.extensionTestsPath && !environmentService.debugExtensionHost.break;
	return {
		isExtensionDevHost,
		isExtensionDevDebug,
		isExtensionDevDebugBrk,
		isExtensionDevTestFromCli,
	};
}

export class ExtensionHostProcessWorker implements IExtensionHostStarter {

	private readonly _onCrashed: Emitter<[number, string]> = new Emitter<[number, string]>();
	public readonly onCrashed: Event<[number, string]> = this._onCrashed.event;

	private readonly _toDispose: IDisposable[];

	private readonly _isExtensionDevHost: boolean;
	private readonly _isExtensionDevDebug: boolean;
	private readonly _isExtensionDevDebugBrk: boolean;
	private readonly _isExtensionDevTestFromCli: boolean;

	// State
	private _lastExtensionHostError: string;
	private _terminating: boolean;

	// Resources, in order they get acquired/created when .start() is called:
	private _namedPipeServer: Server;
	private _inspectPort: number;
	private _extensionHostProcess: ChildProcess;
	private _extensionHostConnection: Socket;
	private _messageProtocol: TPromise<IMessagePassingProtocol>;

	constructor(
		private readonly _extensions: Promise<IExtensionDescription[]>,
		private readonly _extensionHostLogsLocation: URI,
		@IWorkspaceContextService private readonly _contextService: IWorkspaceContextService,
		@INotificationService private readonly _notificationService: INotificationService,
		@IWindowsService private readonly _windowsService: IWindowsService,
		@IWindowService private readonly _windowService: IWindowService,
		@IBroadcastService private readonly _broadcastService: IBroadcastService,
		@ILifecycleService private readonly _lifecycleService: ILifecycleService,
		@IEnvironmentService private readonly _environmentService: IEnvironmentService,
		@IWorkspaceConfigurationService private readonly _configurationService: IWorkspaceConfigurationService,
		@ITelemetryService private readonly _telemetryService: ITelemetryService,
		@ICrashReporterService private readonly _crashReporterService: ICrashReporterService,
		@ILogService private readonly _logService: ILogService,
		@ILabelService private readonly _labelService: ILabelService
	) {
		const devOpts = parseExtensionDevOptions(this._environmentService);
		this._isExtensionDevHost = devOpts.isExtensionDevHost;
		this._isExtensionDevDebug = devOpts.isExtensionDevDebug;
		this._isExtensionDevDebugBrk = devOpts.isExtensionDevDebugBrk;
		this._isExtensionDevTestFromCli = devOpts.isExtensionDevTestFromCli;

		this._lastExtensionHostError = null;
		this._terminating = false;

		this._namedPipeServer = null;
		this._extensionHostProcess = null;
		this._extensionHostConnection = null;
		this._messageProtocol = null;

		this._toDispose = [];
		this._toDispose.push(this._onCrashed);
		this._toDispose.push(this._lifecycleService.onWillShutdown((e) => this._onWillShutdown(e)));
		this._toDispose.push(this._lifecycleService.onShutdown(reason => this.terminate()));
		this._toDispose.push(this._broadcastService.onBroadcast(b => this._onBroadcast(b)));

		const globalExitListener = () => this.terminate();
		process.once('exit', globalExitListener);
		this._toDispose.push(toDisposable(() => {
			process.removeListener('exit', globalExitListener);
		}));
	}

	public dispose(): void {
		this.terminate();
	}

	private _onBroadcast(broadcast: IBroadcast): void {

		// Close Ext Host Window Request
		if (broadcast.channel === EXTENSION_CLOSE_EXTHOST_BROADCAST_CHANNEL && this._isExtensionDevHost) {
			const extensionLocations = broadcast.payload as string[];
			if (Array.isArray(extensionLocations) && extensionLocations.some(uriString => isEqual(this._environmentService.extensionDevelopmentLocationURI, URI.parse(uriString)))) {
				this._windowService.closeWindow();
			}
		}

		if (broadcast.channel === EXTENSION_RELOAD_BROADCAST_CHANNEL && this._isExtensionDevHost) {
			const extensionPaths = broadcast.payload as string[];
			if (Array.isArray(extensionPaths) && extensionPaths.some(uriString => isEqual(this._environmentService.extensionDevelopmentLocationURI, URI.parse(uriString)))) {
				this._windowService.reloadWindow();
			}
		}
	}

	public start(): TPromise<IMessagePassingProtocol> {
		if (this._terminating) {
			// .terminate() was called
			return null;
		}

		if (!this._messageProtocol) {
			this._messageProtocol = TPromise.join([this._tryListenOnPipe(), this._tryFindDebugPort()]).then(data => {
				const pipeName = data[0];
				const portData = data[1];

				const opts = {
					env: objects.mixin(objects.deepClone(process.env), {
						AMD_ENTRYPOINT: 'vs/workbench/node/extensionHostProcess',
						PIPE_LOGGING: 'true',
						VERBOSE_LOGGING: true,
						VSCODE_IPC_HOOK_EXTHOST: pipeName,
						VSCODE_HANDLES_UNCAUGHT_ERRORS: true,
						VSCODE_LOG_STACK: !this._isExtensionDevTestFromCli && (this._isExtensionDevHost || !this._environmentService.isBuilt || product.quality !== 'stable' || this._environmentService.verbose),
						VSCODE_LOG_LEVEL: this._environmentService.verbose ? 'trace' : this._environmentService.log
					}),
					// We only detach the extension host on windows. Linux and Mac orphan by default
					// and detach under Linux and Mac create another process group.
					// We detach because we have noticed that when the renderer exits, its child processes
					// (i.e. extension host) are taken down in a brutal fashion by the OS
					detached: !!isWindows,
					execArgv: <string[]>undefined,
					silent: true
				};

				if (portData.actual) {
					opts.execArgv = [
						'--nolazy',
						(this._isExtensionDevDebugBrk ? '--inspect-brk=' : '--inspect=') + portData.actual
					];
					if (!portData.expected) {
						// No one asked for 'inspect' or 'inspect-brk', only us. We add another
						// option such that the extension host can manipulate the execArgv array
						opts.env.VSCODE_PREVENT_FOREIGN_INSPECT = true;
					}
				}

				const crashReporterOptions = this._crashReporterService.getChildProcessStartOptions('extensionHost');
				if (crashReporterOptions) {
					opts.env.CRASH_REPORTER_START_OPTIONS = JSON.stringify(crashReporterOptions);
				}

				// Run Extension Host as fork of current process
				this._extensionHostProcess = fork(getPathFromAmdModule(require, 'bootstrap-fork'), ['--type=extensionHost'], opts);

				// Catch all output coming from the extension host process
				type Output = { data: string, format: string[] };
				this._extensionHostProcess.stdout.setEncoding('utf8');
				this._extensionHostProcess.stderr.setEncoding('utf8');
				const onStdout = fromNodeEventEmitter<string>(this._extensionHostProcess.stdout, 'data');
				const onStderr = fromNodeEventEmitter<string>(this._extensionHostProcess.stderr, 'data');
				const onOutput = anyEvent(
					mapEvent(onStdout, o => ({ data: `%c${o}`, format: [''] })),
					mapEvent(onStderr, o => ({ data: `%c${o}`, format: ['color: red'] }))
				);

				// Debounce all output, so we can render it in the Chrome console as a group
				const onDebouncedOutput = debounceEvent<Output>(onOutput, (r, o) => {
					return r
						? { data: r.data + o.data, format: [...r.format, ...o.format] }
						: { data: o.data, format: o.format };
				}, 100);

				// Print out extension host output
				onDebouncedOutput(output => {
					const inspectorUrlMatch = !this._environmentService.isBuilt && output.data && output.data.match(/ws:\/\/([^\s]+)/);
					if (inspectorUrlMatch) {
						console.log(`%c[Extension Host] %cdebugger inspector at chrome-devtools://devtools/bundled/inspector.html?experiments=true&v8only=true&ws=${inspectorUrlMatch[1]}`, 'color: blue', 'color: black');
					} else {
						console.group('Extension Host');
						console.log(output.data, ...output.format);
						console.groupEnd();
					}
				});

				// Support logging from extension host
				this._extensionHostProcess.on('message', msg => {
					if (msg && (<IRemoteConsoleLog>msg).type === '__$console') {
						this._logExtensionHostMessage(<IRemoteConsoleLog>msg);
					}
				});

				// Lifecycle
				this._extensionHostProcess.on('error', (err) => this._onExtHostProcessError(err));
				this._extensionHostProcess.on('exit', (code: number, signal: string) => this._onExtHostProcessExit(code, signal));

				// Notify debugger that we are ready to attach to the process if we run a development extension
				if (this._isExtensionDevHost && portData.actual && this._isExtensionDevDebug) {
					this._broadcastService.broadcast({
						channel: EXTENSION_ATTACH_BROADCAST_CHANNEL,
						payload: {
							debugId: this._environmentService.debugExtensionHost.debugId,
							port: portData.actual
						}
					});
				}
				this._inspectPort = portData.actual;

				// Help in case we fail to start it
				let startupTimeoutHandle: any;
				if (!this._environmentService.isBuilt && !this._windowService.getConfiguration().remoteAuthority || this._isExtensionDevHost) {
					startupTimeoutHandle = setTimeout(() => {
						const msg = this._isExtensionDevDebugBrk
							? nls.localize('extensionHostProcess.startupFailDebug', "Extension host did not start in 10 seconds, it might be stopped on the first line and needs a debugger to continue.")
							: nls.localize('extensionHostProcess.startupFail', "Extension host did not start in 10 seconds, that might be a problem.");

						this._notificationService.prompt(Severity.Warning, msg,
							[{
								label: nls.localize('reloadWindow', "Reload Window"),
								run: () => this._windowService.reloadWindow()
							}],
							{ sticky: true }
						);
					}, 10000);
				}

				// Initialize extension host process with hand shakes
				return this._tryExtHostHandshake().then((protocol) => {
					clearTimeout(startupTimeoutHandle);
					return protocol;
				});
			});
		}

		return this._messageProtocol;
	}

	/**
	 * Start a server (`this._namedPipeServer`) that listens on a named pipe and return the named pipe name.
	 */
	private _tryListenOnPipe(): Promise<string> {
		return new Promise<string>((resolve, reject) => {
			const pipeName = generateRandomPipeName();

			this._namedPipeServer = createServer();
			this._namedPipeServer.on('error', reject);
			this._namedPipeServer.listen(pipeName, () => {
				this._namedPipeServer.removeListener('error', reject);
				resolve(pipeName);
			});
		});
	}

	/**
	 * Find a free port if extension host debugging is enabled.
	 */
	private _tryFindDebugPort(): Promise<{ expected: number; actual: number }> {
		let expected: number;
		let startPort = randomPort();
		if (typeof this._environmentService.debugExtensionHost.port === 'number') {
			startPort = expected = this._environmentService.debugExtensionHost.port;
		}
		return new Promise(resolve => {
			return findFreePort(startPort, 10 /* try 10 ports */, 5000 /* try up to 5 seconds */).then(port => {
				if (!port) {
					console.warn('%c[Extension Host] %cCould not find a free port for debugging', 'color: blue', 'color: black');
				} else {
					if (expected && port !== expected) {
						console.warn(`%c[Extension Host] %cProvided debugging port ${expected} is not free, using ${port} instead.`, 'color: blue', 'color: black');
					}
					if (this._isExtensionDevDebugBrk) {
						console.warn(`%c[Extension Host] %cSTOPPED on first line for debugging on port ${port}`, 'color: blue', 'color: black');
					} else {
						console.info(`%c[Extension Host] %cdebugger listening on port ${port}`, 'color: blue', 'color: black');
					}
				}
				return resolve({ expected, actual: port });
			});
		});
	}

	private _tryExtHostHandshake(): Promise<IMessagePassingProtocol> {

		return new Promise<IMessagePassingProtocol>((resolve, reject) => {

			// Wait for the extension host to connect to our named pipe
			// and wrap the socket in the message passing protocol
			let handle = setTimeout(() => {
				this._namedPipeServer.close();
				this._namedPipeServer = null;
				reject('timeout');
			}, 60 * 1000);

			this._namedPipeServer.on('connection', socket => {
				clearTimeout(handle);
				this._namedPipeServer.close();
				this._namedPipeServer = null;
				this._extensionHostConnection = socket;
				resolve(new Protocol(this._extensionHostConnection));
			});

		}).then((protocol) => {

			// 1) wait for the incoming `ready` event and send the initialization data.
			// 2) wait for the incoming `initialized` event.
			return new Promise<IMessagePassingProtocol>((resolve, reject) => {

				let timeoutHandle: NodeJS.Timer;
				const installTimeoutCheck = () => {
					timeoutHandle = setTimeout(() => {
						reject('timeout');
					}, 60 * 1000);
				};
				const uninstallTimeoutCheck = () => {
					clearTimeout(timeoutHandle);
				};

				// Wait 60s for the ready message
				installTimeoutCheck();

				const disposable = protocol.onMessage(msg => {

					if (isMessageOfType(msg, MessageType.Ready)) {
						// 1) Extension Host is ready to receive messages, initialize it
						uninstallTimeoutCheck();

						this._createExtHostInitData().then(data => {

							// Wait 60s for the initialized message
							installTimeoutCheck();

							protocol.send(Buffer.from(JSON.stringify(data)));
						});
						return;
					}

					if (isMessageOfType(msg, MessageType.Initialized)) {
						// 2) Extension Host is initialized
						uninstallTimeoutCheck();

						// stop listening for messages here
						disposable.dispose();

						// release this promise
						// using a buffered message protocol here because between now
						// and the first time a `then` executes some messages might be lost
						// unless we immediately register a listener for `onMessage`.
						resolve(new BufferedMessagePassingProtocol(protocol));
						return;
					}

					console.error(`received unexpected message during handshake phase from the extension host: `, msg);
				});

			});

		});
	}

	private _createExtHostInitData(): TPromise<IInitData> {
		return TPromise.join([this._telemetryService.getTelemetryInfo(), this._extensions])
			.then(([telemetryInfo, extensionDescriptions]) => {
				const configurationData: IConfigurationInitData = { ...this._configurationService.getConfigurationData(), configurationScopes: {} };
				const workspace = this._contextService.getWorkspace();
				const r: IInitData = {
					commit: product.commit,
					parentPid: process.pid,
					environment: {
						isExtensionDevelopmentDebug: this._isExtensionDevDebug,
						appRoot: this._environmentService.appRoot ? URI.file(this._environmentService.appRoot) : void 0,
						appSettingsHome: this._environmentService.appSettingsHome ? URI.file(this._environmentService.appSettingsHome) : void 0,
						extensionDevelopmentLocationURI: this._environmentService.extensionDevelopmentLocationURI,
						extensionTestsPath: this._environmentService.extensionTestsPath
					},
					workspace: this._contextService.getWorkbenchState() === WorkbenchState.EMPTY ? null : {
						configuration: workspace.configuration,
						folders: workspace.folders,
						id: workspace.id,
						name: this._labelService.getWorkspaceLabel(workspace)
					},
					extensions: extensionDescriptions,
					// Send configurations scopes only in development mode.
					configuration: !this._environmentService.isBuilt || this._environmentService.isExtensionDevelopment ? { ...configurationData, configurationScopes: getScopes() } : configurationData,
					telemetryInfo,
					logLevel: this._logService.getLevel(),
					logsLocation: this._extensionHostLogsLocation
				};
				return r;
			});
	}

	private _logExtensionHostMessage(entry: IRemoteConsoleLog) {

		// Send to local console unless we run tests from cli
		if (!this._isExtensionDevTestFromCli) {
			log(entry, 'Extension Host');
		}

		// Log on main side if running tests from cli
		if (this._isExtensionDevTestFromCli) {
			this._windowsService.log(entry.severity, ...parse(entry).args);
		}

		// Broadcast to other windows if we are in development mode
		else if (!this._environmentService.isBuilt || this._isExtensionDevHost) {
			this._broadcastService.broadcast({
				channel: EXTENSION_LOG_BROADCAST_CHANNEL,
				payload: {
					logEntry: entry,
					debugId: this._environmentService.debugExtensionHost.debugId
				}
			});
		}
	}

	private _onExtHostProcessError(err: any): void {
		let errorMessage = toErrorMessage(err);
		if (errorMessage === this._lastExtensionHostError) {
			return; // prevent error spam
		}

		this._lastExtensionHostError = errorMessage;

		this._notificationService.error(nls.localize('extensionHostProcess.error', "Error from the extension host: {0}", errorMessage));
	}

	private _onExtHostProcessExit(code: number, signal: string): void {
		if (this._terminating) {
			// Expected termination path (we asked the process to terminate)
			return;
		}

		// Unexpected termination
		if (!this._isExtensionDevHost) {
			this._onCrashed.fire([code, signal]);
		}

		// Expected development extension termination: When the extension host goes down we also shutdown the window
		else if (!this._isExtensionDevTestFromCli) {
			this._windowService.closeWindow();
		}

		// When CLI testing make sure to exit with proper exit code
		else {
			ipc.send('vscode:exit', code);
		}
	}

	public getInspectPort(): number {
		return this._inspectPort;
	}

	public terminate(): void {
		if (this._terminating) {
			return;
		}
		this._terminating = true;

		dispose(this._toDispose);

		if (!this._messageProtocol) {
			// .start() was not called
			return;
		}

		this._messageProtocol.then((protocol) => {

			// Send the extension host a request to terminate itself
			// (graceful termination)
			protocol.send(createMessageOfType(MessageType.Terminate));

			// Give the extension host 10s, after which we will
			// try to kill the process and release any resources
			setTimeout(() => this._cleanResources(), 10 * 1000);

		}, (err) => {

			// Establishing a protocol with the extension host failed, so
			// try to kill the process and release any resources.
			this._cleanResources();
		});
	}

	private _cleanResources(): void {
		if (this._namedPipeServer) {
			this._namedPipeServer.close();
			this._namedPipeServer = null;
		}
		if (this._extensionHostConnection) {
			this._extensionHostConnection.end();
			this._extensionHostConnection = null;
		}
		if (this._extensionHostProcess) {
			this._extensionHostProcess.kill();
			this._extensionHostProcess = null;
		}
	}

	private _onWillShutdown(event: WillShutdownEvent): void {

		// If the extension development host was started without debugger attached we need
		// to communicate this back to the main side to terminate the debug session
		if (this._isExtensionDevHost && !this._isExtensionDevTestFromCli && !this._isExtensionDevDebug) {
			this._broadcastService.broadcast({
				channel: EXTENSION_TERMINATE_BROADCAST_CHANNEL,
				payload: {
					debugId: this._environmentService.debugExtensionHost.debugId
				}
			});

			event.veto(timeout(100 /* wait a bit for IPC to get delivered */).then(() => false));
		}
	}
}

/**
 * Will ensure no messages are lost from creation time until the first user of onMessage comes in.
 */
class BufferedMessagePassingProtocol implements IMessagePassingProtocol {

	private readonly _actual: IMessagePassingProtocol;
	private _bufferedMessagesListener: IDisposable;
	private _bufferedMessages: Buffer[];

	constructor(actual: IMessagePassingProtocol) {
		this._actual = actual;
		this._bufferedMessages = [];
		this._bufferedMessagesListener = this._actual.onMessage((buff) => this._bufferedMessages.push(buff));
	}

	public send(buffer: Buffer): void {
		this._actual.send(buffer);
	}

	public onMessage(listener: (e: Buffer) => any, thisArgs?: any, disposables?: IDisposable[]): IDisposable {
		if (!this._bufferedMessages) {
			// second caller gets nothing
			return this._actual.onMessage(listener, thisArgs, disposables);
		}

		// prepare result
		const result = this._actual.onMessage(listener, thisArgs, disposables);

		// stop listening to buffered messages
		this._bufferedMessagesListener.dispose();

		// capture buffered messages
		const bufferedMessages = this._bufferedMessages;
		this._bufferedMessages = null;

		// it is important to deliver these messages after this call, but before
		// other messages have a chance to be received (to guarantee in order delivery)
		// that's why we're using here nextTick and not other types of timeouts
		process.nextTick(() => {
			// deliver buffered messages
			while (bufferedMessages.length > 0) {
				const msg = bufferedMessages.shift();
				try {
					listener.call(thisArgs, msg);
				} catch (e) {
					onUnexpectedError(e);
				}
			}
		});

		return result;
	}
}
