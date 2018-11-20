/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import * as platform from 'vs/base/common/platform';
import * as terminalEnvironment from 'vs/workbench/parts/terminal/node/terminalEnvironment';
import { IDisposable } from 'vs/base/common/lifecycle';
import { ProcessState, ITerminalProcessManager, IShellLaunchConfig, ITerminalConfigHelper } from 'vs/workbench/parts/terminal/common/terminal';
import { ILogService } from 'vs/platform/log/common/log';
import { Emitter, Event } from 'vs/base/common/event';
import { IHistoryService } from 'vs/workbench/services/history/common/history';
import { ITerminalChildProcess } from 'vs/workbench/parts/terminal/node/terminal';
import { TerminalProcessExtHostProxy } from 'vs/workbench/parts/terminal/node/terminalProcessExtHostProxy';
import { IInstantiationService } from 'vs/platform/instantiation/common/instantiation';
import { TerminalProcess } from 'vs/workbench/parts/terminal/node/terminalProcess';
import { IWorkspaceContextService } from 'vs/platform/workspace/common/workspace';
import { IConfigurationResolverService } from 'vs/workbench/services/configurationResolver/common/configurationResolver';
import { Schemas } from 'vs/base/common/network';

/** The amount of time to consider terminal errors to be related to the launch */
const LAUNCHING_DURATION = 500;

/**
 * Holds all state related to the creation and management of terminal processes.
 *
 * Internal definitions:
 * - Process: The process launched with the terminalProcess.ts file, or the pty as a whole
 * - Pty Process: The pseudoterminal master process (or the winpty agent process)
 * - Shell Process: The pseudoterminal slave process (ie. the shell)
 */
export class TerminalProcessManager implements ITerminalProcessManager {
	public processState: ProcessState = ProcessState.UNINITIALIZED;
	public ptyProcessReady: Promise<void>;
	public shellProcessId: number;
	public initialCwd: string;

	private _process: ITerminalChildProcess;
	private _preLaunchInputQueue: string[] = [];
	private _disposables: IDisposable[] = [];

	private readonly _onProcessReady: Emitter<void> = new Emitter<void>();
	public get onProcessReady(): Event<void> { return this._onProcessReady.event; }
	private readonly _onProcessData: Emitter<string> = new Emitter<string>();
	public get onProcessData(): Event<string> { return this._onProcessData.event; }
	private readonly _onProcessTitle: Emitter<string> = new Emitter<string>();
	public get onProcessTitle(): Event<string> { return this._onProcessTitle.event; }
	private readonly _onProcessExit: Emitter<number> = new Emitter<number>();
	public get onProcessExit(): Event<number> { return this._onProcessExit.event; }

	constructor(
		private readonly _terminalId: number,
		private readonly _configHelper: ITerminalConfigHelper,
		@IHistoryService private readonly _historyService: IHistoryService,
		@IInstantiationService private readonly _instantiationService: IInstantiationService,
		@ILogService private readonly _logService: ILogService,
		@IWorkspaceContextService private readonly _workspaceContextService: IWorkspaceContextService,
		@IConfigurationResolverService private readonly _configurationResolverService: IConfigurationResolverService
	) {
		this.ptyProcessReady = new Promise<void>(c => {
			this.onProcessReady(() => {
				this._logService.debug(`Terminal process ready (shellProcessId: ${this.shellProcessId})`);
				c(void 0);
			});
		});
	}

	public dispose(immediate?: boolean): void {
		if (this._process) {
			// If the process was still connected this dispose came from
			// within VS Code, not the process, so mark the process as
			// killed by the user.
			this.processState = ProcessState.KILLED_BY_USER;
			this._process.shutdown(immediate);
			this._process = null;
		}
		this._disposables.forEach(d => d.dispose());
		this._disposables.length = 0;
	}

	public addDisposable(disposable: IDisposable) {
		this._disposables.push(disposable);
	}

	public createProcess(
		shellLaunchConfig: IShellLaunchConfig,
		cols: number,
		rows: number
	): void {
		const extensionHostOwned = (<any>this._configHelper.config).extHostProcess;
		if (extensionHostOwned) {
			this._process = this._instantiationService.createInstance(TerminalProcessExtHostProxy, this._terminalId, shellLaunchConfig, cols, rows);
		} else {
			if (!shellLaunchConfig.executable) {
				this._configHelper.mergeDefaultShellPathAndArgs(shellLaunchConfig);
			}

			const lastActiveWorkspaceRootUri = this._historyService.getLastActiveWorkspaceRoot(Schemas.file);
			this.initialCwd = terminalEnvironment.getCwd(shellLaunchConfig, lastActiveWorkspaceRootUri, this._configHelper);

			// Resolve env vars from config and shell
			const lastActiveWorkspaceRoot = this._workspaceContextService.getWorkspaceFolder(lastActiveWorkspaceRootUri);
			const platformKey = platform.isWindows ? 'windows' : (platform.isMacintosh ? 'osx' : 'linux');
			const envFromConfig = terminalEnvironment.resolveConfigurationVariables(this._configurationResolverService, { ...this._configHelper.config.env[platformKey] }, lastActiveWorkspaceRoot);
			const envFromShell = terminalEnvironment.resolveConfigurationVariables(this._configurationResolverService, { ...shellLaunchConfig.env }, lastActiveWorkspaceRoot);
			shellLaunchConfig.env = envFromShell;

			// Merge process env with the env from config and from shellLaunchConfig
			const env = { ...process.env };
			terminalEnvironment.mergeEnvironments(env, envFromConfig);
			terminalEnvironment.mergeEnvironments(env, shellLaunchConfig.env);

			// Sanitize the environment, removing any undesirable VS Code and Electron environment
			// variables
			terminalEnvironment.sanitizeEnvironment(env);

			// Adding other env keys necessary to create the process
			const locale = this._configHelper.config.setLocaleVariables ? platform.locale : undefined;
			terminalEnvironment.addTerminalEnvironmentKeys(env, locale);

			this._logService.debug(`Terminal process launching`, shellLaunchConfig, this.initialCwd, cols, rows, env);
			this._process = new TerminalProcess(shellLaunchConfig, this.initialCwd, cols, rows, env);
		}
		this.processState = ProcessState.LAUNCHING;

		this._process.onProcessData(data => {
			this._onProcessData.fire(data);
		});

		this._process.onProcessIdReady(pid => {
			this.shellProcessId = pid;
			this._onProcessReady.fire();

			// Send any queued data that's waiting
			if (this._preLaunchInputQueue.length > 0) {
				this._process.input(this._preLaunchInputQueue.join(''));
				this._preLaunchInputQueue.length = 0;
			}
		});

		this._process.onProcessTitleChanged(title => this._onProcessTitle.fire(title));
		this._process.onProcessExit(exitCode => this._onExit(exitCode));

		setTimeout(() => {
			if (this.processState === ProcessState.LAUNCHING) {
				this.processState = ProcessState.RUNNING;
			}
		}, LAUNCHING_DURATION);
	}

	public setDimensions(cols: number, rows: number): void {
		if (!this._process) {
			return;
		}

		// The child process could already be terminated
		try {
			this._process.resize(cols, rows);
		} catch (error) {
			// We tried to write to a closed pipe / channel.
			if (error.code !== 'EPIPE' && error.code !== 'ERR_IPC_CHANNEL_CLOSED') {
				throw (error);
			}
		}
	}

	public write(data: string): void {
		if (this.shellProcessId) {
			if (this._process) {
				// Send data if the pty is ready
				this._process.input(data);
			}
		} else {
			// If the pty is not ready, queue the data received to send later
			this._preLaunchInputQueue.push(data);
		}
	}

	private _onExit(exitCode: number): void {
		this._process = null;

		// If the process is marked as launching then mark the process as killed
		// during launch. This typically means that there is a problem with the
		// shell and args.
		if (this.processState === ProcessState.LAUNCHING) {
			this.processState = ProcessState.KILLED_DURING_LAUNCH;
		}

		// If TerminalInstance did not know about the process exit then it was
		// triggered by the process, not on VS Code's side.
		if (this.processState === ProcessState.RUNNING) {
			this.processState = ProcessState.KILLED_BY_PROCESS;
		}

		this._onProcessExit.fire(exitCode);
	}
}