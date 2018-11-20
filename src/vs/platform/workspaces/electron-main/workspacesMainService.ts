/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import { IWorkspacesMainService, IWorkspaceIdentifier, WORKSPACE_EXTENSION, IWorkspaceSavedEvent, UNTITLED_WORKSPACE_NAME, IResolvedWorkspace, IStoredWorkspaceFolder, isRawFileWorkspaceFolder, isStoredWorkspaceFolder, IWorkspaceFolderCreationData } from 'vs/platform/workspaces/common/workspaces';
import { TPromise } from 'vs/base/common/winjs.base';
import { isParent } from 'vs/platform/files/common/files';
import { IEnvironmentService } from 'vs/platform/environment/common/environment';
import { extname, join, dirname, isAbsolute, resolve } from 'path';
import { mkdirp, writeFile, readFile } from 'vs/base/node/pfs';
import { readFileSync, existsSync, mkdirSync, writeFileSync } from 'fs';
import { isLinux, isMacintosh } from 'vs/base/common/platform';
import { delSync, readdirSync, writeFileAndFlushSync } from 'vs/base/node/extfs';
import { Event, Emitter } from 'vs/base/common/event';
import { ILogService } from 'vs/platform/log/common/log';
import { isEqual } from 'vs/base/common/paths';
import { coalesce } from 'vs/base/common/arrays';
import { createHash } from 'crypto';
import * as json from 'vs/base/common/json';
import * as jsonEdit from 'vs/base/common/jsonEdit';
import { massageFolderPathForWorkspace } from 'vs/platform/workspaces/node/workspaces';
import { toWorkspaceFolders } from 'vs/platform/workspace/common/workspace';
import { URI } from 'vs/base/common/uri';
import { Schemas } from 'vs/base/common/network';
import { Disposable } from 'vs/base/common/lifecycle';

export interface IStoredWorkspace {
	folders: IStoredWorkspaceFolder[];
}

export class WorkspacesMainService extends Disposable implements IWorkspacesMainService {

	_serviceBrand: any;

	private workspacesHome: string;

	private readonly _onWorkspaceSaved = this._register(new Emitter<IWorkspaceSavedEvent>());
	get onWorkspaceSaved(): Event<IWorkspaceSavedEvent> { return this._onWorkspaceSaved.event; }

	private readonly _onUntitledWorkspaceDeleted = this._register(new Emitter<IWorkspaceIdentifier>());
	get onUntitledWorkspaceDeleted(): Event<IWorkspaceIdentifier> { return this._onUntitledWorkspaceDeleted.event; }

	constructor(
		@IEnvironmentService private environmentService: IEnvironmentService,
		@ILogService private logService: ILogService
	) {
		super();

		this.workspacesHome = environmentService.workspacesHome;
	}

	resolveWorkspace(path: string): TPromise<IResolvedWorkspace | null> {
		if (!this.isWorkspacePath(path)) {
			return TPromise.as(null); // does not look like a valid workspace config file
		}

		return readFile(path, 'utf8').then(contents => this.doResolveWorkspace(path, contents));
	}

	resolveWorkspaceSync(path: string): IResolvedWorkspace | null {
		if (!this.isWorkspacePath(path)) {
			return null; // does not look like a valid workspace config file
		}

		let contents: string;
		try {
			contents = readFileSync(path, 'utf8');
		} catch (error) {
			return null; // invalid workspace
		}

		return this.doResolveWorkspace(path, contents);
	}

	private isWorkspacePath(path: string): boolean {
		return this.isInsideWorkspacesHome(path) || extname(path) === `.${WORKSPACE_EXTENSION}`;
	}

	private doResolveWorkspace(path: string, contents: string): IResolvedWorkspace | null {
		try {
			const workspace = this.doParseStoredWorkspace(path, contents);

			return {
				id: this.getWorkspaceId(path),
				configPath: path,
				folders: toWorkspaceFolders(workspace.folders, URI.file(dirname(path)))
			};
		} catch (error) {
			this.logService.warn(error.toString());
		}

		return null;
	}

	private doParseStoredWorkspace(path: string, contents: string): IStoredWorkspace {

		// Parse workspace file
		let storedWorkspace: IStoredWorkspace = json.parse(contents); // use fault tolerant parser

		// Filter out folders which do not have a path or uri set
		if (Array.isArray(storedWorkspace.folders)) {
			storedWorkspace.folders = storedWorkspace.folders.filter(folder => isStoredWorkspaceFolder(folder));
		}

		// Validate
		if (!Array.isArray(storedWorkspace.folders)) {
			throw new Error(`${path} looks like an invalid workspace file.`);
		}

		return storedWorkspace;
	}

	private isInsideWorkspacesHome(path: string): boolean {
		return isParent(path, this.environmentService.workspacesHome, !isLinux /* ignore case */);
	}

	createWorkspace(folders?: IWorkspaceFolderCreationData[]): TPromise<IWorkspaceIdentifier> {
		const { workspace, configParent, storedWorkspace } = this.createUntitledWorkspace(folders);

		return mkdirp(configParent).then(() => {
			return writeFile(workspace.configPath, JSON.stringify(storedWorkspace, null, '\t')).then(() => workspace);
		});
	}

	createWorkspaceSync(folders?: IWorkspaceFolderCreationData[]): IWorkspaceIdentifier {
		const { workspace, configParent, storedWorkspace } = this.createUntitledWorkspace(folders);

		if (!existsSync(this.workspacesHome)) {
			mkdirSync(this.workspacesHome);
		}

		mkdirSync(configParent);

		writeFileAndFlushSync(workspace.configPath, JSON.stringify(storedWorkspace, null, '\t'));

		return workspace;
	}

	private createUntitledWorkspace(folders: IWorkspaceFolderCreationData[] = []): { workspace: IWorkspaceIdentifier, configParent: string, storedWorkspace: IStoredWorkspace } {
		const randomId = (Date.now() + Math.round(Math.random() * 1000)).toString();
		const untitledWorkspaceConfigFolder = join(this.workspacesHome, randomId);
		const untitledWorkspaceConfigPath = join(untitledWorkspaceConfigFolder, UNTITLED_WORKSPACE_NAME);

		const storedWorkspace: IStoredWorkspace = {
			folders: folders.map(folder => {
				const folderResource = folder.uri;
				let storedWorkspace: IStoredWorkspaceFolder;

				// File URI
				if (folderResource.scheme === Schemas.file) {
					storedWorkspace = { path: massageFolderPathForWorkspace(folderResource.fsPath, untitledWorkspaceConfigFolder, []) };
				}

				// Any URI
				else {
					storedWorkspace = { uri: folderResource.toString(true) };
				}

				if (folder.name) {
					storedWorkspace.name = folder.name;
				}

				return storedWorkspace;
			})
		};

		return {
			workspace: {
				id: this.getWorkspaceId(untitledWorkspaceConfigPath),
				configPath: untitledWorkspaceConfigPath
			},
			configParent: untitledWorkspaceConfigFolder,
			storedWorkspace
		};
	}

	getWorkspaceId(workspaceConfigPath: string): string {
		if (!isLinux) {
			workspaceConfigPath = workspaceConfigPath.toLowerCase(); // sanitize for platform file system
		}

		return createHash('md5').update(workspaceConfigPath).digest('hex');
	}

	isUntitledWorkspace(workspace: IWorkspaceIdentifier): boolean {
		return this.isInsideWorkspacesHome(workspace.configPath);
	}

	saveWorkspace(workspace: IWorkspaceIdentifier, targetConfigPath: string): TPromise<IWorkspaceIdentifier> {

		// Return early if target is same as source
		if (isEqual(workspace.configPath, targetConfigPath, !isLinux)) {
			return TPromise.as(workspace);
		}

		// Read the contents of the workspace file and resolve it
		return readFile(workspace.configPath).then(raw => {
			const rawWorkspaceContents = raw.toString();
			let storedWorkspace: IStoredWorkspace;
			try {
				storedWorkspace = this.doParseStoredWorkspace(workspace.configPath, rawWorkspaceContents);
			} catch (error) {
				return TPromise.wrapError(error);
			}

			const sourceConfigFolder = dirname(workspace.configPath);
			const targetConfigFolder = dirname(targetConfigPath);

			// Rewrite absolute paths to relative paths if the target workspace folder
			// is a parent of the location of the workspace file itself. Otherwise keep
			// using absolute paths.
			storedWorkspace.folders.forEach(folder => {
				if (isRawFileWorkspaceFolder(folder)) {
					if (!isAbsolute(folder.path)) {
						folder.path = resolve(sourceConfigFolder, folder.path); // relative paths get resolved against the workspace location
					}
					folder.path = massageFolderPathForWorkspace(folder.path, targetConfigFolder, storedWorkspace.folders);
				}

			});

			// Preserve as much of the existing workspace as possible by using jsonEdit
			// and only changing the folders portion.
			let newRawWorkspaceContents = rawWorkspaceContents;
			const edits = jsonEdit.setProperty(rawWorkspaceContents, ['folders'], storedWorkspace.folders, { insertSpaces: false, tabSize: 4, eol: (isLinux || isMacintosh) ? '\n' : '\r\n' });
			edits.forEach(edit => {
				newRawWorkspaceContents = jsonEdit.applyEdit(rawWorkspaceContents, edit);
			});

			return writeFile(targetConfigPath, newRawWorkspaceContents).then(() => {
				const savedWorkspaceIdentifier = { id: this.getWorkspaceId(targetConfigPath), configPath: targetConfigPath };

				// Event
				this._onWorkspaceSaved.fire({ workspace: savedWorkspaceIdentifier, oldConfigPath: workspace.configPath });

				// Delete untitled workspace
				this.deleteUntitledWorkspaceSync(workspace);

				return savedWorkspaceIdentifier;
			});
		});
	}

	deleteUntitledWorkspaceSync(workspace: IWorkspaceIdentifier): void {
		if (!this.isUntitledWorkspace(workspace)) {
			return; // only supported for untitled workspaces
		}

		// Delete from disk
		this.doDeleteUntitledWorkspaceSync(workspace.configPath);

		// Event
		this._onUntitledWorkspaceDeleted.fire(workspace);
	}

	private doDeleteUntitledWorkspaceSync(configPath: string): void {
		try {

			// Delete Workspace
			delSync(dirname(configPath));

			// Mark Workspace Storage to be deleted
			const workspaceStoragePath = join(this.environmentService.workspaceStorageHome, this.getWorkspaceId(configPath));
			if (existsSync(workspaceStoragePath)) {
				writeFileSync(join(workspaceStoragePath, 'obsolete'), '');
			}
		} catch (error) {
			this.logService.warn(`Unable to delete untitled workspace ${configPath} (${error}).`);
		}
	}

	getUntitledWorkspacesSync(): IWorkspaceIdentifier[] {
		let untitledWorkspacePaths: string[] = [];
		try {
			untitledWorkspacePaths = readdirSync(this.workspacesHome).map(folder => join(this.workspacesHome, folder, UNTITLED_WORKSPACE_NAME));
		} catch (error) {
			if (error && error.code !== 'ENOENT') {
				this.logService.warn(`Unable to read folders in ${this.workspacesHome} (${error}).`);
			}
		}

		const untitledWorkspaces: IWorkspaceIdentifier[] = coalesce(untitledWorkspacePaths.map(untitledWorkspacePath => {
			const workspace = this.resolveWorkspaceSync(untitledWorkspacePath);
			if (!workspace) {
				this.doDeleteUntitledWorkspaceSync(untitledWorkspacePath);

				return null; // invalid workspace
			}

			return { id: workspace.id, configPath: untitledWorkspacePath };
		}));

		return untitledWorkspaces;
	}
}