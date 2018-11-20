/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import { IEnvironmentService, ParsedArgs, IDebugParams, IExtensionHostDebugParams } from 'vs/platform/environment/common/environment';
import * as crypto from 'crypto';
import * as paths from 'vs/base/node/paths';
import * as os from 'os';
import * as path from 'path';
import { memoize } from 'vs/base/common/decorators';
import pkg from 'vs/platform/node/package';
import product from 'vs/platform/node/product';
import { toLocalISOString } from 'vs/base/common/date';
import { isWindows, isLinux } from 'vs/base/common/platform';
import { getPathFromAmdModule } from 'vs/base/common/amd';
import { URI } from 'vs/base/common/uri';

// Read this before there's any chance it is overwritten
// Related to https://github.com/Microsoft/vscode/issues/30624
const xdgRuntimeDir = process.env['XDG_RUNTIME_DIR'];

function getNixIPCHandle(userDataPath: string, type: string): string {
	if (xdgRuntimeDir) {
		const scope = crypto.createHash('md5').update(userDataPath).digest('hex').substr(0, 8);
		return path.join(xdgRuntimeDir, `vscode-${scope}-${pkg.version}-${type}.sock`);
	}

	return path.join(userDataPath, `${pkg.version}-${type}.sock`);
}

function getWin32IPCHandle(userDataPath: string, type: string): string {
	const scope = crypto.createHash('md5').update(userDataPath).digest('hex');

	return `\\\\.\\pipe\\${scope}-${pkg.version}-${type}-sock`;
}

function getIPCHandle(userDataPath: string, type: string): string {
	if (isWindows) {
		return getWin32IPCHandle(userDataPath, type);
	}

	return getNixIPCHandle(userDataPath, type);
}

function getCLIPath(execPath: string, appRoot: string, isBuilt: boolean): string {

	// Windows
	if (isWindows) {
		if (isBuilt) {
			return path.join(path.dirname(execPath), 'bin', `${product.applicationName}.cmd`);
		}

		return path.join(appRoot, 'scripts', 'code-cli.bat');
	}

	// Linux
	if (isLinux) {
		if (isBuilt) {
			return path.join(path.dirname(execPath), 'bin', `${product.applicationName}`);
		}

		return path.join(appRoot, 'scripts', 'code-cli.sh');
	}

	// macOS
	if (isBuilt) {
		return path.join(appRoot, 'bin', 'code');
	}

	return path.join(appRoot, 'scripts', 'code-cli.sh');
}

export class EnvironmentService implements IEnvironmentService {

	_serviceBrand: any;

	get args(): ParsedArgs { return this._args; }

	@memoize
	get appRoot(): string { return path.dirname(getPathFromAmdModule(require, '')); }

	get execPath(): string { return this._execPath; }

	@memoize
	get cliPath(): string { return getCLIPath(this.execPath, this.appRoot, this.isBuilt); }

	readonly logsPath: string;

	@memoize
	get userHome(): string { return os.homedir(); }

	@memoize
	get userDataPath(): string {
		const vscodePortable = process.env['VSCODE_PORTABLE'];
		if (vscodePortable) {
			return path.join(vscodePortable, 'user-data');
		}

		return parseUserDataDir(this._args, process);
	}

	get appNameLong(): string { return product.nameLong; }

	get appQuality(): string | undefined { return product.quality; }

	@memoize
	get appSettingsHome(): string { return path.join(this.userDataPath, 'User'); }

	@memoize
	get appSettingsPath(): string { return path.join(this.appSettingsHome, 'settings.json'); }

	@memoize
	get workspaceStorageHome(): string { return path.join(this.appSettingsHome, 'workspaceStorage'); }

	@memoize
	get settingsSearchBuildId(): number | undefined { return product.settingsSearchBuildId; }

	@memoize
	get settingsSearchUrl(): string | undefined { return product.settingsSearchUrl; }

	@memoize
	get appKeybindingsPath(): string { return path.join(this.appSettingsHome, 'keybindings.json'); }

	@memoize
	get isExtensionDevelopment(): boolean { return !!this._args.extensionDevelopmentPath; }

	@memoize
	get backupHome(): string { return path.join(this.userDataPath, 'Backups'); }

	@memoize
	get backupWorkspacesPath(): string { return path.join(this.backupHome, 'workspaces.json'); }

	@memoize
	get workspacesHome(): string { return path.join(this.userDataPath, 'Workspaces'); }

	@memoize
	get installSourcePath(): string { return path.join(this.userDataPath, 'installSource'); }

	@memoize
	get builtinExtensionsPath(): string {
		const fromArgs = parsePathArg(this._args['builtin-extensions-dir'], process);
		if (fromArgs) {
			return fromArgs;
		} else {
			return path.normalize(path.join(getPathFromAmdModule(require, ''), '..', 'extensions'));
		}
	}

	@memoize
	get extensionsPath(): string {
		const fromArgs = parsePathArg(this._args['extensions-dir'], process);

		if (fromArgs) {
			return fromArgs;
		}

		const vscodeExtensions = process.env['VSCODE_EXTENSIONS'];
		if (vscodeExtensions) {
			return vscodeExtensions;
		}

		const vscodePortable = process.env['VSCODE_PORTABLE'];
		if (vscodePortable) {
			return path.join(vscodePortable, 'extensions');
		}

		return path.join(this.userHome, product.dataFolderName, 'extensions');
	}

	@memoize
	get extensionDevelopmentLocationURI(): URI | undefined {
		const s = this._args.extensionDevelopmentPath;
		if (s) {
			if (/^[^:/?#]+?:\/\//.test(s)) {
				return URI.parse(s);
			}
			return URI.file(path.normalize(s));
		}
		return void 0;
	}

	@memoize
	get extensionTestsPath(): string | undefined { return this._args.extensionTestsPath ? path.normalize(this._args.extensionTestsPath) : this._args.extensionTestsPath; }

	get disableExtensions(): boolean | string[] {
		if (this._args['disable-extensions']) {
			return true;
		}
		const disableExtensions = this._args['disable-extension'];
		if (disableExtensions) {
			if (typeof disableExtensions === 'string') {
				return [disableExtensions];
			}
			if (Array.isArray(disableExtensions) && disableExtensions.length > 0) {
				return disableExtensions;
			}
		}
		return false;
	}

	get skipGettingStarted(): boolean { return !!this._args['skip-getting-started']; }

	get skipReleaseNotes(): boolean { return !!this._args['skip-release-notes']; }

	get skipAddToRecentlyOpened(): boolean { return !!this._args['skip-add-to-recently-opened']; }

	@memoize
	get debugExtensionHost(): IExtensionHostDebugParams { return parseExtensionHostPort(this._args, this.isBuilt); }

	@memoize
	get debugSearch(): IDebugParams { return parseSearchPort(this._args, this.isBuilt); }

	get isBuilt(): boolean { return !process.env['VSCODE_DEV']; }
	get verbose(): boolean { return !!this._args.verbose; }
	get log(): string | undefined { return this._args.log; }

	get wait(): boolean { return !!this._args.wait; }

	get logExtensionHostCommunication(): boolean { return !!this._args.logExtensionHostCommunication; }

	get performance(): boolean { return !!this._args.performance; }
	get status(): boolean { return !!this._args.status; }

	@memoize
	get mainIPCHandle(): string { return getIPCHandle(this.userDataPath, 'main'); }

	@memoize
	get sharedIPCHandle(): string { return getIPCHandle(this.userDataPath, 'shared'); }

	@memoize
	get nodeCachedDataDir(): string | undefined { return process.env['VSCODE_NODE_CACHED_DATA_DIR'] || undefined; }

	get disableUpdates(): boolean { return !!this._args['disable-updates']; }
	get disableCrashReporter(): boolean { return !!this._args['disable-crash-reporter']; }

	get driverHandle(): string | undefined { return this._args['driver']; }
	get driverVerbose(): boolean { return !!this._args['driver-verbose']; }

	constructor(private _args: ParsedArgs, private _execPath: string) {
		if (!process.env['VSCODE_LOGS']) {
			const key = toLocalISOString(new Date()).replace(/-|:|\.\d+Z$/g, '');
			process.env['VSCODE_LOGS'] = path.join(this.userDataPath, 'logs', key);
		}

		this.logsPath = process.env['VSCODE_LOGS']!;
	}
}

export function parseExtensionHostPort(args: ParsedArgs, isBuild: boolean): IExtensionHostDebugParams {
	return parseDebugPort(args.debugPluginHost, args.debugBrkPluginHost, 5870, isBuild, args.debugId);
}

export function parseSearchPort(args: ParsedArgs, isBuild: boolean): IDebugParams {
	return parseDebugPort(args.debugSearch, args.debugBrkSearch, 5876, isBuild);
}

export function parseDebugPort(debugArg: string | undefined, debugBrkArg: string | undefined, defaultBuildPort: number, isBuild: boolean, debugId?: string): IExtensionHostDebugParams {
	const portStr = debugBrkArg || debugArg;
	const port = Number(portStr) || (!isBuild ? defaultBuildPort : null);
	const brk = port ? Boolean(!!debugBrkArg) : false;
	return { port, break: brk, debugId };
}

function parsePathArg(arg: string | undefined, process: NodeJS.Process): string | undefined {
	if (!arg) {
		return undefined;
	}

	// Determine if the arg is relative or absolute, if relative use the original CWD
	// (VSCODE_CWD), not the potentially overridden one (process.cwd()).
	const resolved = path.resolve(arg);

	if (path.normalize(arg) === resolved) {
		return resolved;
	} else {
		return path.resolve(process.env['VSCODE_CWD'] || process.cwd(), arg);
	}
}

export function parseUserDataDir(args: ParsedArgs, process: NodeJS.Process): string {
	return parsePathArg(args['user-data-dir'], process) || path.resolve(paths.getDefaultUserDataPath(process.platform));
}
