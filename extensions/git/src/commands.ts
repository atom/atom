/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import { Uri, commands, Disposable, window, workspace, QuickPickItem, OutputChannel, Range, WorkspaceEdit, Position, LineChange, SourceControlResourceState, TextDocumentShowOptions, ViewColumn, ProgressLocation, TextEditor, MessageOptions, WorkspaceFolder } from 'vscode';
import { Git, CommitOptions, Stash, ForcePushMode } from './git';
import { Repository, Resource, ResourceGroupType } from './repository';
import { Model } from './model';
import { toGitUri, fromGitUri } from './uri';
import { grep, isDescendant, pathEquals } from './util';
import { applyLineChanges, intersectDiffWithRange, toLineRanges, invertLineChange, getModifiedRange } from './staging';
import * as path from 'path';
import { lstat, Stats } from 'fs';
import * as os from 'os';
import TelemetryReporter from 'vscode-extension-telemetry';
import * as nls from 'vscode-nls';
import { Ref, RefType, Branch, GitErrorCodes, Status } from './api/git';

const localize = nls.loadMessageBundle();

class CheckoutItem implements QuickPickItem {

	protected get shortCommit(): string { return (this.ref.commit || '').substr(0, 8); }
	get label(): string { return this.ref.name || this.shortCommit; }
	get description(): string { return this.shortCommit; }

	constructor(protected ref: Ref) { }

	async run(repository: Repository): Promise<void> {
		const ref = this.ref.name;

		if (!ref) {
			return;
		}

		await repository.checkout(ref);
	}
}

class CheckoutTagItem extends CheckoutItem {

	get description(): string {
		return localize('tag at', "Tag at {0}", this.shortCommit);
	}
}

class CheckoutRemoteHeadItem extends CheckoutItem {

	get description(): string {
		return localize('remote branch at', "Remote branch at {0}", this.shortCommit);
	}

	async run(repository: Repository): Promise<void> {
		if (!this.ref.name) {
			return;
		}

		await repository.checkoutTracking(this.ref.name);
	}
}

class BranchDeleteItem implements QuickPickItem {

	private get shortCommit(): string { return (this.ref.commit || '').substr(0, 8); }
	get branchName(): string | undefined { return this.ref.name; }
	get label(): string { return this.branchName || ''; }
	get description(): string { return this.shortCommit; }

	constructor(private ref: Ref) { }

	async run(repository: Repository, force?: boolean): Promise<void> {
		if (!this.branchName) {
			return;
		}
		await repository.deleteBranch(this.branchName, force);
	}
}

class MergeItem implements QuickPickItem {

	get label(): string { return this.ref.name || ''; }
	get description(): string { return this.ref.name || ''; }

	constructor(protected ref: Ref) { }

	async run(repository: Repository): Promise<void> {
		await repository.merge(this.ref.name! || this.ref.commit!);
	}
}

class CreateBranchItem implements QuickPickItem {

	constructor(private cc: CommandCenter) { }

	get label(): string { return localize('create branch', '$(plus) Create new branch'); }
	get description(): string { return ''; }

	get alwaysShow(): boolean { return true; }

	async run(repository: Repository): Promise<void> {
		await this.cc.branch(repository);
	}
}

interface CommandOptions {
	repository?: boolean;
	diff?: boolean;
}

interface Command {
	commandId: string;
	key: string;
	method: Function;
	options: CommandOptions;
}

const Commands: Command[] = [];

function command(commandId: string, options: CommandOptions = {}): Function {
	return (_target: any, key: string, descriptor: any) => {
		if (!(typeof descriptor.value === 'function')) {
			throw new Error('not supported');
		}

		Commands.push({ commandId, key, method: descriptor.value, options });
	};
}

const ImageMimetypes = [
	'image/png',
	'image/gif',
	'image/jpeg',
	'image/webp',
	'image/tiff',
	'image/bmp'
];

async function categorizeResourceByResolution(resources: Resource[]): Promise<{ merge: Resource[], resolved: Resource[], unresolved: Resource[], deletionConflicts: Resource[] }> {
	const selection = resources.filter(s => s instanceof Resource) as Resource[];
	const merge = selection.filter(s => s.resourceGroupType === ResourceGroupType.Merge);
	const isBothAddedOrModified = (s: Resource) => s.type === Status.BOTH_MODIFIED || s.type === Status.BOTH_ADDED;
	const isAnyDeleted = (s: Resource) => s.type === Status.DELETED_BY_THEM || s.type === Status.DELETED_BY_US;
	const possibleUnresolved = merge.filter(isBothAddedOrModified);
	const promises = possibleUnresolved.map(s => grep(s.resourceUri.fsPath, /^<{7}|^={7}|^>{7}/));
	const unresolvedBothModified = await Promise.all<boolean>(promises);
	const resolved = possibleUnresolved.filter((_s, i) => !unresolvedBothModified[i]);
	const deletionConflicts = merge.filter(s => isAnyDeleted(s));
	const unresolved = [
		...merge.filter(s => !isBothAddedOrModified(s) && !isAnyDeleted(s)),
		...possibleUnresolved.filter((_s, i) => unresolvedBothModified[i])
	];

	return { merge, resolved, unresolved, deletionConflicts };
}

enum PushType {
	Push,
	PushTo,
	PushTags,
}

interface PushOptions {
	pushType: PushType;
	forcePush?: boolean;
	silent?: boolean;
}

export class CommandCenter {

	private disposables: Disposable[];

	constructor(
		private git: Git,
		private model: Model,
		private outputChannel: OutputChannel,
		private telemetryReporter: TelemetryReporter
	) {
		this.disposables = Commands.map(({ commandId, key, method, options }) => {
			const command = this.createCommand(commandId, key, method, options);

			if (options.diff) {
				return commands.registerDiffInformationCommand(commandId, command);
			} else {
				return commands.registerCommand(commandId, command);
			}
		});
	}

	@command('git.refresh', { repository: true })
	async refresh(repository: Repository): Promise<void> {
		await repository.status();
	}

	@command('git.openResource')
	async openResource(resource: Resource): Promise<void> {
		const repository = this.model.getRepository(resource.resourceUri);

		if (!repository) {
			return;
		}

		const config = workspace.getConfiguration('git', Uri.file(repository.root));
		const openDiffOnClick = config.get<boolean>('openDiffOnClick');

		if (openDiffOnClick) {
			await this._openResource(resource, undefined, true, false);
		} else {
			await this.openFile(resource);
		}
	}

	private async _openResource(resource: Resource, preview?: boolean, preserveFocus?: boolean, preserveSelection?: boolean): Promise<void> {
		let stat: Stats | undefined;

		try {
			stat = await new Promise<Stats>((c, e) => lstat(resource.resourceUri.fsPath, (err, stat) => err ? e(err) : c(stat)));
		} catch (err) {
			// noop
		}

		let left: Uri | undefined;
		let right: Uri | undefined;

		if (stat && stat.isDirectory()) {
			const repository = this.model.getRepositoryForSubmodule(resource.resourceUri);

			if (repository) {
				right = toGitUri(resource.resourceUri, resource.resourceGroupType === ResourceGroupType.Index ? 'index' : 'wt', { submoduleOf: repository.root });
			}
		} else {
			if (resource.type !== Status.DELETED_BY_THEM) {
				left = await this.getLeftResource(resource);
			}

			right = await this.getRightResource(resource);
		}

		const title = this.getTitle(resource);

		if (!right) {
			// TODO
			console.error('oh no');
			return;
		}

		const opts: TextDocumentShowOptions = {
			preserveFocus,
			preview,
			viewColumn: ViewColumn.Active
		};

		const activeTextEditor = window.activeTextEditor;

		// Check if active text editor has same path as other editor. we cannot compare via
		// URI.toString() here because the schemas can be different. Instead we just go by path.
		if (preserveSelection && activeTextEditor && activeTextEditor.document.uri.path === right.path) {
			opts.selection = activeTextEditor.selection;
		}

		if (!left) {
			await commands.executeCommand<void>('vscode.open', right, opts, title);
		} else {
			await commands.executeCommand<void>('vscode.diff', left, right, title, opts);
		}
	}

	private async getURI(uri: Uri, ref: string): Promise<Uri | undefined> {
		const repository = this.model.getRepository(uri);

		if (!repository) {
			return toGitUri(uri, ref);
		}

		try {
			let gitRef = ref;

			if (gitRef === '~') {
				const uriString = uri.toString();
				const [indexStatus] = repository.indexGroup.resourceStates.filter(r => r.resourceUri.toString() === uriString);
				gitRef = indexStatus ? '' : 'HEAD';
			}

			const { size, object } = await repository.getObjectDetails(gitRef, uri.fsPath);
			const { mimetype } = await repository.detectObjectType(object);

			if (mimetype === 'text/plain') {
				return toGitUri(uri, ref);
			}

			if (size > 1000000) { // 1 MB
				return Uri.parse(`data:;label:${path.basename(uri.fsPath)};description:${gitRef},`);
			}

			if (ImageMimetypes.indexOf(mimetype) > -1) {
				const contents = await repository.buffer(gitRef, uri.fsPath);
				return Uri.parse(`data:${mimetype};label:${path.basename(uri.fsPath)};description:${gitRef};size:${size};base64,${contents.toString('base64')}`);
			}

			return Uri.parse(`data:;label:${path.basename(uri.fsPath)};description:${gitRef},`);

		} catch (err) {
			return toGitUri(uri, ref);
		}
	}

	private async getLeftResource(resource: Resource): Promise<Uri | undefined> {
		switch (resource.type) {
			case Status.INDEX_MODIFIED:
			case Status.INDEX_RENAMED:
				return this.getURI(resource.original, 'HEAD');

			case Status.MODIFIED:
				return this.getURI(resource.resourceUri, '~');

			case Status.DELETED_BY_THEM:
				return this.getURI(resource.resourceUri, '');
		}
		return undefined;
	}

	private async getRightResource(resource: Resource): Promise<Uri | undefined> {
		switch (resource.type) {
			case Status.INDEX_MODIFIED:
			case Status.INDEX_ADDED:
			case Status.INDEX_COPIED:
			case Status.INDEX_RENAMED:
				return this.getURI(resource.resourceUri, '');

			case Status.INDEX_DELETED:
			case Status.DELETED:
				return this.getURI(resource.resourceUri, 'HEAD');

			case Status.DELETED_BY_US:
				return this.getURI(resource.resourceUri, '~3');

			case Status.DELETED_BY_THEM:
				return this.getURI(resource.resourceUri, '~2');

			case Status.MODIFIED:
			case Status.UNTRACKED:
			case Status.IGNORED:
				const repository = this.model.getRepository(resource.resourceUri);

				if (!repository) {
					return;
				}

				const uriString = resource.resourceUri.toString();
				const [indexStatus] = repository.indexGroup.resourceStates.filter(r => r.resourceUri.toString() === uriString);

				if (indexStatus && indexStatus.renameResourceUri) {
					return indexStatus.renameResourceUri;
				}

				return resource.resourceUri;

			case Status.BOTH_ADDED:
			case Status.BOTH_MODIFIED:
				return resource.resourceUri;
		}
		return undefined;
	}

	private getTitle(resource: Resource): string {
		const basename = path.basename(resource.resourceUri.fsPath);

		switch (resource.type) {
			case Status.INDEX_MODIFIED:
			case Status.INDEX_RENAMED:
				return `${basename} (Index)`;

			case Status.MODIFIED:
			case Status.BOTH_ADDED:
			case Status.BOTH_MODIFIED:
				return `${basename} (Working Tree)`;

			case Status.DELETED_BY_US:
				return `${basename} (Theirs)`;

			case Status.DELETED_BY_THEM:
				return `${basename} (Ours)`;
		}

		return '';
	}

	@command('git.clone')
	async clone(url?: string): Promise<void> {
		if (!url) {
			url = await window.showInputBox({
				prompt: localize('repourl', "Repository URL"),
				ignoreFocusOut: true
			});
		}

		if (!url) {
			/* __GDPR__
				"clone" : {
					"outcome" : { "classification": "SystemMetaData", "purpose": "FeatureInsight" }
				}
			*/
			this.telemetryReporter.sendTelemetryEvent('clone', { outcome: 'no_URL' });
			return;
		}

		const config = workspace.getConfiguration('git');
		let defaultCloneDirectory = config.get<string>('defaultCloneDirectory') || os.homedir();
		defaultCloneDirectory = defaultCloneDirectory.replace(/^~/, os.homedir());

		const uris = await window.showOpenDialog({
			canSelectFiles: false,
			canSelectFolders: true,
			canSelectMany: false,
			defaultUri: Uri.file(defaultCloneDirectory),
			openLabel: localize('selectFolder', "Select Repository Location")
		});

		if (!uris || uris.length === 0) {
			/* __GDPR__
				"clone" : {
					"outcome" : { "classification": "SystemMetaData", "purpose": "FeatureInsight" }
				}
			*/
			this.telemetryReporter.sendTelemetryEvent('clone', { outcome: 'no_directory' });
			return;
		}

		const uri = uris[0];
		const parentPath = uri.fsPath;

		try {
			const opts = {
				location: ProgressLocation.Notification,
				title: localize('cloning', "Cloning git repository '{0}'...", url),
				cancellable: true
			};

			const repositoryPath = await window.withProgress(
				opts,
				(_, token) => this.git.clone(url!, parentPath, token)
			);

			const choices = [];
			let message = localize('proposeopen', "Would you like to open the cloned repository?");
			const open = localize('openrepo', "Open Repository");
			choices.push(open);

			const addToWorkspace = localize('add', "Add to Workspace");
			if (workspace.workspaceFolders) {
				message = localize('proposeopen2', "Would you like to open the cloned repository, or add it to the current workspace?");
				choices.push(addToWorkspace);
			}

			const result = await window.showInformationMessage(message, ...choices);

			const openFolder = result === open;
			/* __GDPR__
				"clone" : {
					"outcome" : { "classification": "SystemMetaData", "purpose": "FeatureInsight" },
					"openFolder": { "classification": "SystemMetaData", "purpose": "PerformanceAndHealth", "isMeasurement": true }
				}
			*/
			this.telemetryReporter.sendTelemetryEvent('clone', { outcome: 'success' }, { openFolder: openFolder ? 1 : 0 });

			const uri = Uri.file(repositoryPath);

			if (openFolder) {
				commands.executeCommand('vscode.openFolder', uri);
			} else if (result === addToWorkspace) {
				workspace.updateWorkspaceFolders(workspace.workspaceFolders!.length, 0, { uri });
			}
		} catch (err) {
			if (/already exists and is not an empty directory/.test(err && err.stderr || '')) {
				/* __GDPR__
					"clone" : {
						"outcome" : { "classification": "SystemMetaData", "purpose": "FeatureInsight" }
					}
				*/
				this.telemetryReporter.sendTelemetryEvent('clone', { outcome: 'directory_not_empty' });
			} else if (/Cancelled/i.test(err && (err.message || err.stderr || ''))) {
				return;
			} else {
				/* __GDPR__
					"clone" : {
						"outcome" : { "classification": "SystemMetaData", "purpose": "FeatureInsight" }
					}
				*/
				this.telemetryReporter.sendTelemetryEvent('clone', { outcome: 'error' });
			}

			throw err;
		}
	}

	@command('git.init')
	async init(): Promise<void> {
		let repositoryPath: string | undefined = undefined;

		if (workspace.workspaceFolders) {
			const placeHolder = localize('init', "Pick workspace folder to initialize git repo in");
			const pick = { label: localize('choose', "Choose Folder...") };
			const items: { label: string, folder?: WorkspaceFolder }[] = [
				...workspace.workspaceFolders.map(folder => ({ label: folder.name, description: folder.uri.fsPath, folder })),
				pick
			];
			const item = await window.showQuickPick(items, { placeHolder, ignoreFocusOut: true });

			if (!item) {
				return;
			} else if (item.folder) {
				repositoryPath = item.folder.uri.fsPath;
			}
		}

		if (!repositoryPath) {
			const homeUri = Uri.file(os.homedir());
			const defaultUri = workspace.workspaceFolders && workspace.workspaceFolders.length > 0
				? Uri.file(workspace.workspaceFolders[0].uri.fsPath)
				: homeUri;

			const result = await window.showOpenDialog({
				canSelectFiles: false,
				canSelectFolders: true,
				canSelectMany: false,
				defaultUri,
				openLabel: localize('init repo', "Initialize Repository")
			});

			if (!result || result.length === 0) {
				return;
			}

			const uri = result[0];

			if (homeUri.toString().startsWith(uri.toString())) {
				const yes = localize('create repo', "Initialize Repository");
				const answer = await window.showWarningMessage(localize('are you sure', "This will create a Git repository in '{0}'. Are you sure you want to continue?", uri.fsPath), yes);

				if (answer !== yes) {
					return;
				}
			}

			repositoryPath = uri.fsPath;
		}

		await this.git.init(repositoryPath);

		const choices = [];
		let message = localize('proposeopen init', "Would you like to open the initialized repository?");
		const open = localize('openrepo', "Open Repository");
		choices.push(open);

		const addToWorkspace = localize('add', "Add to Workspace");
		if (workspace.workspaceFolders) {
			message = localize('proposeopen2 init', "Would you like to open the initialized repository, or add it to the current workspace?");
			choices.push(addToWorkspace);
		}

		const result = await window.showInformationMessage(message, ...choices);
		const uri = Uri.file(repositoryPath);

		if (result === open) {
			commands.executeCommand('vscode.openFolder', uri);
		} else if (result === addToWorkspace) {
			workspace.updateWorkspaceFolders(workspace.workspaceFolders!.length, 0, { uri });
		} else {
			await this.model.openRepository(repositoryPath);
		}
	}

	@command('git.openRepository', { repository: false })
	async openRepository(path?: string): Promise<void> {
		if (!path) {
			const result = await window.showOpenDialog({
				canSelectFiles: false,
				canSelectFolders: true,
				canSelectMany: false,
				defaultUri: Uri.file(os.homedir()),
				openLabel: localize('open repo', "Open Repository")
			});

			if (!result || result.length === 0) {
				return;
			}

			path = result[0].fsPath;
		}

		await this.model.openRepository(path);
	}

	@command('git.close', { repository: true })
	async close(repository: Repository): Promise<void> {
		this.model.close(repository);
	}

	@command('git.openFile')
	async openFile(arg?: Resource | Uri, ...resourceStates: SourceControlResourceState[]): Promise<void> {
		const preserveFocus = arg instanceof Resource;

		let uris: Uri[] | undefined;

		if (arg instanceof Uri) {
			if (arg.scheme === 'git') {
				uris = [Uri.file(fromGitUri(arg).path)];
			} else if (arg.scheme === 'file') {
				uris = [arg];
			}
		} else {
			let resource = arg;

			if (!(resource instanceof Resource)) {
				// can happen when called from a keybinding
				resource = this.getSCMResource();
			}

			if (resource) {
				const resources = ([resource, ...resourceStates] as Resource[])
					.filter(r => r.type !== Status.DELETED && r.type !== Status.INDEX_DELETED);

				uris = resources.map(r => r.resourceUri);
			}
		}

		if (!uris) {
			return;
		}

		const activeTextEditor = window.activeTextEditor;
		for (const uri of uris) {
			const opts: TextDocumentShowOptions = {
				preserveFocus,
				preview: false,
				viewColumn: ViewColumn.Active
			};

			const document = await workspace.openTextDocument(uri);

			// Check if active text editor has same path as other editor. we cannot compare via
			// URI.toString() here because the schemas can be different. Instead we just go by path.
			if (activeTextEditor && activeTextEditor.document.uri.path === uri.path) {
				// preserve not only selection but also visible range
				opts.selection = activeTextEditor.selection;
				const previousVisibleRanges = activeTextEditor.visibleRanges;
				const editor = await window.showTextDocument(document, opts);
				editor.revealRange(previousVisibleRanges[0]);
			} else {
				await window.showTextDocument(document, opts);
			}
		}
	}

	@command('git.openFile2')
	async openFile2(arg?: Resource | Uri, ...resourceStates: SourceControlResourceState[]): Promise<void> {
		this.openFile(arg, ...resourceStates);
	}

	@command('git.openHEADFile')
	async openHEADFile(arg?: Resource | Uri): Promise<void> {
		let resource: Resource | undefined = undefined;
		const preview = !(arg instanceof Resource);

		if (arg instanceof Resource) {
			resource = arg;
		} else if (arg instanceof Uri) {
			resource = this.getSCMResource(arg);
		} else {
			resource = this.getSCMResource();
		}

		if (!resource) {
			return;
		}

		const HEAD = await this.getLeftResource(resource);

		if (!HEAD) {
			window.showWarningMessage(localize('HEAD not available', "HEAD version of '{0}' is not available.", path.basename(resource.resourceUri.fsPath)));
			return;
		}

		const opts: TextDocumentShowOptions = {
			preview
		};

		return await commands.executeCommand<void>('vscode.open', HEAD, opts);
	}

	@command('git.openChange')
	async openChange(arg?: Resource | Uri, ...resourceStates: SourceControlResourceState[]): Promise<void> {
		const preserveFocus = arg instanceof Resource;
		const preview = !(arg instanceof Resource);

		const preserveSelection = arg instanceof Uri || !arg;
		let resources: Resource[] | undefined = undefined;

		if (arg instanceof Uri) {
			const resource = this.getSCMResource(arg);
			if (resource !== undefined) {
				resources = [resource];
			}
		} else {
			let resource: Resource | undefined = undefined;

			if (arg instanceof Resource) {
				resource = arg;
			} else {
				resource = this.getSCMResource();
			}

			if (resource) {
				resources = [...resourceStates as Resource[], resource];
			}
		}

		if (!resources) {
			return;
		}

		for (const resource of resources) {
			await this._openResource(resource, preview, preserveFocus, preserveSelection);
		}
	}

	@command('git.stage')
	async stage(...resourceStates: SourceControlResourceState[]): Promise<void> {
		this.outputChannel.appendLine(`git.stage ${resourceStates.length}`);

		resourceStates = resourceStates.filter(s => !!s);

		if (resourceStates.length === 0 || (resourceStates[0] && !(resourceStates[0].resourceUri instanceof Uri))) {
			const resource = this.getSCMResource();

			this.outputChannel.appendLine(`git.stage.getSCMResource ${resource ? resource.resourceUri.toString() : null}`);

			if (!resource) {
				return;
			}

			resourceStates = [resource];
		}

		const selection = resourceStates.filter(s => s instanceof Resource) as Resource[];
		const { resolved, unresolved, deletionConflicts } = await categorizeResourceByResolution(selection);

		if (unresolved.length > 0) {
			const message = unresolved.length > 1
				? localize('confirm stage files with merge conflicts', "Are you sure you want to stage {0} files with merge conflicts?", unresolved.length)
				: localize('confirm stage file with merge conflicts', "Are you sure you want to stage {0} with merge conflicts?", path.basename(unresolved[0].resourceUri.fsPath));

			const yes = localize('yes', "Yes");
			const pick = await window.showWarningMessage(message, { modal: true }, yes);

			if (pick !== yes) {
				return;
			}
		}

		try {
			await this.runByRepository(deletionConflicts.map(r => r.resourceUri), async (repository, resources) => {
				for (const resource of resources) {
					await this._stageDeletionConflict(repository, resource);
				}
			});
		} catch (err) {
			if (/Cancelled/.test(err.message)) {
				return;
			}

			throw err;
		}

		const workingTree = selection.filter(s => s.resourceGroupType === ResourceGroupType.WorkingTree);
		const scmResources = [...workingTree, ...resolved, ...unresolved];

		this.outputChannel.appendLine(`git.stage.scmResources ${scmResources.length}`);
		if (!scmResources.length) {
			return;
		}

		const resources = scmResources.map(r => r.resourceUri);
		await this.runByRepository(resources, async (repository, resources) => repository.add(resources));
	}

	@command('git.stageAll', { repository: true })
	async stageAll(repository: Repository): Promise<void> {
		const resources = repository.mergeGroup.resourceStates.filter(s => s instanceof Resource) as Resource[];
		const { merge, unresolved, deletionConflicts } = await categorizeResourceByResolution(resources);

		try {
			for (const deletionConflict of deletionConflicts) {
				await this._stageDeletionConflict(repository, deletionConflict.resourceUri);
			}
		} catch (err) {
			if (/Cancelled/.test(err.message)) {
				return;
			}

			throw err;
		}

		if (unresolved.length > 0) {
			const message = unresolved.length > 1
				? localize('confirm stage files with merge conflicts', "Are you sure you want to stage {0} files with merge conflicts?", merge.length)
				: localize('confirm stage file with merge conflicts', "Are you sure you want to stage {0} with merge conflicts?", path.basename(merge[0].resourceUri.fsPath));

			const yes = localize('yes', "Yes");
			const pick = await window.showWarningMessage(message, { modal: true }, yes);

			if (pick !== yes) {
				return;
			}
		}

		await repository.add([]);
	}

	private async _stageDeletionConflict(repository: Repository, uri: Uri): Promise<void> {
		const uriString = uri.toString();
		const resource = repository.mergeGroup.resourceStates.filter(r => r.resourceUri.toString() === uriString)[0];

		if (!resource) {
			return;
		}

		if (resource.type === Status.DELETED_BY_THEM) {
			const keepIt = localize('keep ours', "Keep Our Version");
			const deleteIt = localize('delete', "Delete File");
			const result = await window.showInformationMessage(localize('deleted by them', "File '{0}' was deleted by them and modified by us.\n\nWhat would you like to do?", path.basename(uri.fsPath)), { modal: true }, keepIt, deleteIt);

			if (result === keepIt) {
				await repository.add([uri]);
			} else if (result === deleteIt) {
				await repository.rm([uri]);
			} else {
				throw new Error('Cancelled');
			}
		} else if (resource.type === Status.DELETED_BY_US) {
			const keepIt = localize('keep theirs', "Keep Their Version");
			const deleteIt = localize('delete', "Delete File");
			const result = await window.showInformationMessage(localize('deleted by us', "File '{0}' was deleted by us and modified by them.\n\nWhat would you like to do?", path.basename(uri.fsPath)), { modal: true }, keepIt, deleteIt);

			if (result === keepIt) {
				await repository.add([uri]);
			} else if (result === deleteIt) {
				await repository.rm([uri]);
			} else {
				throw new Error('Cancelled');
			}
		}
	}

	@command('git.stageChange')
	async stageChange(uri: Uri, changes: LineChange[], index: number): Promise<void> {
		const textEditor = window.visibleTextEditors.filter(e => e.document.uri.toString() === uri.toString())[0];

		if (!textEditor) {
			return;
		}

		await this._stageChanges(textEditor, [changes[index]]);
	}

	@command('git.stageSelectedRanges', { diff: true })
	async stageSelectedChanges(changes: LineChange[]): Promise<void> {
		const textEditor = window.activeTextEditor;

		if (!textEditor) {
			return;
		}

		const modifiedDocument = textEditor.document;
		const selectedLines = toLineRanges(textEditor.selections, modifiedDocument);
		const selectedChanges = changes
			.map(diff => selectedLines.reduce<LineChange | null>((result, range) => result || intersectDiffWithRange(modifiedDocument, diff, range), null))
			.filter(d => !!d) as LineChange[];

		if (!selectedChanges.length) {
			return;
		}

		await this._stageChanges(textEditor, selectedChanges);
	}

	private async _stageChanges(textEditor: TextEditor, changes: LineChange[]): Promise<void> {
		const modifiedDocument = textEditor.document;
		const modifiedUri = modifiedDocument.uri;

		if (modifiedUri.scheme !== 'file') {
			return;
		}

		const originalUri = toGitUri(modifiedUri, '~');
		const originalDocument = await workspace.openTextDocument(originalUri);
		const result = applyLineChanges(originalDocument, modifiedDocument, changes);

		await this.runByRepository(modifiedUri, async (repository, resource) => await repository.stage(resource, result));
	}

	@command('git.revertChange')
	async revertChange(uri: Uri, changes: LineChange[], index: number): Promise<void> {
		const textEditor = window.visibleTextEditors.filter(e => e.document.uri.toString() === uri.toString())[0];

		if (!textEditor) {
			return;
		}

		await this._revertChanges(textEditor, [...changes.slice(0, index), ...changes.slice(index + 1)]);
	}

	@command('git.revertSelectedRanges', { diff: true })
	async revertSelectedRanges(changes: LineChange[]): Promise<void> {
		const textEditor = window.activeTextEditor;

		if (!textEditor) {
			return;
		}

		const modifiedDocument = textEditor.document;
		const selections = textEditor.selections;
		const selectedChanges = changes.filter(change => {
			const modifiedRange = getModifiedRange(modifiedDocument, change);
			return selections.every(selection => !selection.intersection(modifiedRange));
		});

		if (selectedChanges.length === changes.length) {
			return;
		}

		await this._revertChanges(textEditor, selectedChanges);
	}

	private async _revertChanges(textEditor: TextEditor, changes: LineChange[]): Promise<void> {
		const modifiedDocument = textEditor.document;
		const modifiedUri = modifiedDocument.uri;

		if (modifiedUri.scheme !== 'file') {
			return;
		}

		const originalUri = toGitUri(modifiedUri, '~');
		const originalDocument = await workspace.openTextDocument(originalUri);
		const selectionsBeforeRevert = textEditor.selections;
		const visibleRangesBeforeRevert = textEditor.visibleRanges;
		const result = applyLineChanges(originalDocument, modifiedDocument, changes);

		const edit = new WorkspaceEdit();
		edit.replace(modifiedUri, new Range(new Position(0, 0), modifiedDocument.lineAt(modifiedDocument.lineCount - 1).range.end), result);
		workspace.applyEdit(edit);

		await modifiedDocument.save();

		textEditor.selections = selectionsBeforeRevert;
		textEditor.revealRange(visibleRangesBeforeRevert[0]);
	}

	@command('git.unstage')
	async unstage(...resourceStates: SourceControlResourceState[]): Promise<void> {
		resourceStates = resourceStates.filter(s => !!s);

		if (resourceStates.length === 0 || (resourceStates[0] && !(resourceStates[0].resourceUri instanceof Uri))) {
			const resource = this.getSCMResource();

			if (!resource) {
				return;
			}

			resourceStates = [resource];
		}

		const scmResources = resourceStates
			.filter(s => s instanceof Resource && s.resourceGroupType === ResourceGroupType.Index) as Resource[];

		if (!scmResources.length) {
			return;
		}

		const resources = scmResources.map(r => r.resourceUri);
		await this.runByRepository(resources, async (repository, resources) => repository.revert(resources));
	}

	@command('git.unstageAll', { repository: true })
	async unstageAll(repository: Repository): Promise<void> {
		await repository.revert([]);
	}

	@command('git.unstageSelectedRanges', { diff: true })
	async unstageSelectedRanges(diffs: LineChange[]): Promise<void> {
		const textEditor = window.activeTextEditor;

		if (!textEditor) {
			return;
		}

		const modifiedDocument = textEditor.document;
		const modifiedUri = modifiedDocument.uri;

		if (modifiedUri.scheme !== 'git') {
			return;
		}

		const { ref } = fromGitUri(modifiedUri);

		if (ref !== '') {
			return;
		}

		const originalUri = toGitUri(modifiedUri, 'HEAD');
		const originalDocument = await workspace.openTextDocument(originalUri);
		const selectedLines = toLineRanges(textEditor.selections, modifiedDocument);
		const selectedDiffs = diffs
			.map(diff => selectedLines.reduce<LineChange | null>((result, range) => result || intersectDiffWithRange(modifiedDocument, diff, range), null))
			.filter(d => !!d) as LineChange[];

		if (!selectedDiffs.length) {
			return;
		}

		const invertedDiffs = selectedDiffs.map(invertLineChange);
		const result = applyLineChanges(modifiedDocument, originalDocument, invertedDiffs);

		await this.runByRepository(modifiedUri, async (repository, resource) => await repository.stage(resource, result));
	}

	@command('git.clean')
	async clean(...resourceStates: SourceControlResourceState[]): Promise<void> {
		resourceStates = resourceStates.filter(s => !!s);

		if (resourceStates.length === 0 || (resourceStates[0] && !(resourceStates[0].resourceUri instanceof Uri))) {
			const resource = this.getSCMResource();

			if (!resource) {
				return;
			}

			resourceStates = [resource];
		}

		const scmResources = resourceStates
			.filter(s => s instanceof Resource && s.resourceGroupType === ResourceGroupType.WorkingTree) as Resource[];

		if (!scmResources.length) {
			return;
		}

		const untrackedCount = scmResources.reduce((s, r) => s + (r.type === Status.UNTRACKED ? 1 : 0), 0);
		let message: string;
		let yes = localize('discard', "Discard Changes");

		if (scmResources.length === 1) {
			if (untrackedCount > 0) {
				message = localize('confirm delete', "Are you sure you want to DELETE {0}?", path.basename(scmResources[0].resourceUri.fsPath));
				yes = localize('delete file', "Delete file");
			} else {
				if (scmResources[0].type === Status.DELETED) {
					yes = localize('restore file', "Restore file");
					message = localize('confirm restore', "Are you sure you want to restore {0}?", path.basename(scmResources[0].resourceUri.fsPath));
				} else {
					message = localize('confirm discard', "Are you sure you want to discard changes in {0}?", path.basename(scmResources[0].resourceUri.fsPath));
				}
			}
		} else {
			if (scmResources.every(resource => resource.type === Status.DELETED)) {
				yes = localize('restore files', "Restore files");
				message = localize('confirm restore multiple', "Are you sure you want to restore {0} files?", scmResources.length);
			} else {
				message = localize('confirm discard multiple', "Are you sure you want to discard changes in {0} files?", scmResources.length);
			}

			if (untrackedCount > 0) {
				message = `${message}\n\n${localize('warn untracked', "This will DELETE {0} untracked files!", untrackedCount)}`;
			}
		}

		const pick = await window.showWarningMessage(message, { modal: true }, yes);

		if (pick !== yes) {
			return;
		}

		const resources = scmResources.map(r => r.resourceUri);
		await this.runByRepository(resources, async (repository, resources) => repository.clean(resources));
	}

	@command('git.cleanAll', { repository: true })
	async cleanAll(repository: Repository): Promise<void> {
		let resources = repository.workingTreeGroup.resourceStates;

		if (resources.length === 0) {
			return;
		}

		const trackedResources = resources.filter(r => r.type !== Status.UNTRACKED && r.type !== Status.IGNORED);
		const untrackedResources = resources.filter(r => r.type === Status.UNTRACKED || r.type === Status.IGNORED);

		if (untrackedResources.length === 0) {
			const message = resources.length === 1
				? localize('confirm discard all single', "Are you sure you want to discard changes in {0}?", path.basename(resources[0].resourceUri.fsPath))
				: localize('confirm discard all', "Are you sure you want to discard ALL changes in {0} files?\nThis is IRREVERSIBLE!\nYour current working set will be FOREVER LOST.", resources.length);
			const yes = resources.length === 1
				? localize('discardAll multiple', "Discard 1 File")
				: localize('discardAll', "Discard All {0} Files", resources.length);
			const pick = await window.showWarningMessage(message, { modal: true }, yes);

			if (pick !== yes) {
				return;
			}

			await repository.clean(resources.map(r => r.resourceUri));
			return;
		} else if (resources.length === 1) {
			const message = localize('confirm delete', "Are you sure you want to DELETE {0}?", path.basename(resources[0].resourceUri.fsPath));
			const yes = localize('delete file', "Delete file");
			const pick = await window.showWarningMessage(message, { modal: true }, yes);

			if (pick !== yes) {
				return;
			}

			await repository.clean(resources.map(r => r.resourceUri));
		} else if (trackedResources.length === 0) {
			const message = localize('confirm delete multiple', "Are you sure you want to DELETE {0} files?", resources.length);
			const yes = localize('delete files', "Delete Files");
			const pick = await window.showWarningMessage(message, { modal: true }, yes);

			if (pick !== yes) {
				return;
			}

			await repository.clean(resources.map(r => r.resourceUri));

		} else { // resources.length > 1 && untrackedResources.length > 0 && trackedResources.length > 0
			const untrackedMessage = untrackedResources.length === 1
				? localize('there are untracked files single', "The following untracked file will be DELETED FROM DISK if discarded: {0}.", path.basename(untrackedResources[0].resourceUri.fsPath))
				: localize('there are untracked files', "There are {0} untracked files which will be DELETED FROM DISK if discarded.", untrackedResources.length);

			const message = localize('confirm discard all 2', "{0}\n\nThis is IRREVERSIBLE, your current working set will be FOREVER LOST.", untrackedMessage, resources.length);

			const yesTracked = trackedResources.length === 1
				? localize('yes discard tracked', "Discard 1 Tracked File", trackedResources.length)
				: localize('yes discard tracked multiple', "Discard {0} Tracked Files", trackedResources.length);

			const yesAll = localize('discardAll', "Discard All {0} Files", resources.length);
			const pick = await window.showWarningMessage(message, { modal: true }, yesTracked, yesAll);

			if (pick === yesTracked) {
				resources = trackedResources;
			} else if (pick !== yesAll) {
				return;
			}

			await repository.clean(resources.map(r => r.resourceUri));
		}
	}

	private async smartCommit(
		repository: Repository,
		getCommitMessage: () => Promise<string | undefined>,
		opts?: CommitOptions
	): Promise<boolean> {
		const config = workspace.getConfiguration('git', Uri.file(repository.root));
		const promptToSaveFilesBeforeCommit = config.get<boolean>('promptToSaveFilesBeforeCommit') === true;

		if (promptToSaveFilesBeforeCommit) {
			const unsavedTextDocuments = workspace.textDocuments
				.filter(d => !d.isUntitled && d.isDirty && isDescendant(repository.root, d.uri.fsPath));

			if (unsavedTextDocuments.length > 0) {
				const message = unsavedTextDocuments.length === 1
					? localize('unsaved files single', "The following file is unsaved: {0}.\n\nWould you like to save it before committing?", path.basename(unsavedTextDocuments[0].uri.fsPath))
					: localize('unsaved files', "There are {0} unsaved files.\n\nWould you like to save them before committing?", unsavedTextDocuments.length);
				const saveAndCommit = localize('save and commit', "Save All & Commit");
				const commit = localize('commit', "Commit Anyway");
				const pick = await window.showWarningMessage(message, { modal: true }, saveAndCommit, commit);

				if (pick === saveAndCommit) {
					await Promise.all(unsavedTextDocuments.map(d => d.save()));
					await repository.status();
				} else if (pick !== commit) {
					return false; // do not commit on cancel
				}
			}
		}

		const enableSmartCommit = config.get<boolean>('enableSmartCommit') === true;
		const enableCommitSigning = config.get<boolean>('enableCommitSigning') === true;
		const noStagedChanges = repository.indexGroup.resourceStates.length === 0;
		const noUnstagedChanges = repository.workingTreeGroup.resourceStates.length === 0;

		// no changes, and the user has not configured to commit all in this case
		if (!noUnstagedChanges && noStagedChanges && !enableSmartCommit) {

			// prompt the user if we want to commit all or not
			const message = localize('no staged changes', "There are no staged changes to commit.\n\nWould you like to automatically stage all your changes and commit them directly?");
			const yes = localize('yes', "Yes");
			const always = localize('always', "Always");
			const pick = await window.showWarningMessage(message, { modal: true }, yes, always);

			if (pick === always) {
				config.update('enableSmartCommit', true, true);
			} else if (pick !== yes) {
				return false; // do not commit on cancel
			}
		}

		if (!opts) {
			opts = { all: noStagedChanges };
		} else if (!opts.all && noStagedChanges) {
			opts = { ...opts, all: true };
		}

		// enable signing of commits if configurated
		opts.signCommit = enableCommitSigning;

		if (config.get<boolean>('alwaysSignOff')) {
			opts.signoff = true;
		}

		if (
			(
				// no changes
				(noStagedChanges && noUnstagedChanges)
				// or no staged changes and not `all`
				|| (!opts.all && noStagedChanges)
			)
			&& !opts.empty
		) {
			window.showInformationMessage(localize('no changes', "There are no changes to commit."));
			return false;
		}

		const message = await getCommitMessage();

		if (!message) {
			return false;
		}

		await repository.commit(message, opts);

		const postCommitCommand = config.get<'none' | 'push' | 'sync'>('postCommitCommand');

		switch (postCommitCommand) {
			case 'push':
				await this._push(repository, { pushType: PushType.Push, silent: true });
				break;
			case 'sync':
				await this.sync(repository);
				break;
		}

		return true;
	}

	private async commitWithAnyInput(repository: Repository, opts?: CommitOptions): Promise<void> {
		const message = repository.inputBox.value;
		const getCommitMessage = async () => {
			if (message) {
				return message;
			}

			let value: string | undefined = undefined;

			if (opts && opts.amend && repository.HEAD && repository.HEAD.commit) {
				value = (await repository.getCommit(repository.HEAD.commit)).message;
			}

			return await window.showInputBox({
				value,
				placeHolder: localize('commit message', "Commit message"),
				prompt: localize('provide commit message', "Please provide a commit message"),
				ignoreFocusOut: true
			});
		};

		const didCommit = await this.smartCommit(repository, getCommitMessage, opts);

		if (message && didCommit) {
			repository.inputBox.value = await repository.getCommitTemplate();
		}
	}

	@command('git.commit', { repository: true })
	async commit(repository: Repository): Promise<void> {
		await this.commitWithAnyInput(repository);
	}

	@command('git.commitWithInput', { repository: true })
	async commitWithInput(repository: Repository): Promise<void> {
		if (!repository.inputBox.value) {
			return;
		}

		const didCommit = await this.smartCommit(repository, async () => repository.inputBox.value);

		if (didCommit) {
			repository.inputBox.value = await repository.getCommitTemplate();
		}
	}

	@command('git.commitStaged', { repository: true })
	async commitStaged(repository: Repository): Promise<void> {
		await this.commitWithAnyInput(repository, { all: false });
	}

	@command('git.commitStagedSigned', { repository: true })
	async commitStagedSigned(repository: Repository): Promise<void> {
		await this.commitWithAnyInput(repository, { all: false, signoff: true });
	}

	@command('git.commitStagedAmend', { repository: true })
	async commitStagedAmend(repository: Repository): Promise<void> {
		await this.commitWithAnyInput(repository, { all: false, amend: true });
	}

	@command('git.commitAll', { repository: true })
	async commitAll(repository: Repository): Promise<void> {
		await this.commitWithAnyInput(repository, { all: true });
	}

	@command('git.commitAllSigned', { repository: true })
	async commitAllSigned(repository: Repository): Promise<void> {
		await this.commitWithAnyInput(repository, { all: true, signoff: true });
	}

	@command('git.commitAllAmend', { repository: true })
	async commitAllAmend(repository: Repository): Promise<void> {
		await this.commitWithAnyInput(repository, { all: true, amend: true });
	}

	@command('git.commitEmpty', { repository: true })
	async commitEmpty(repository: Repository): Promise<void> {
		const root = Uri.file(repository.root);
		const config = workspace.getConfiguration('git', root);
		const shouldPrompt = config.get<boolean>('confirmEmptyCommits') === true;

		if (shouldPrompt) {
			const message = localize('confirm emtpy commit', "Are you sure you want to create an empty commit?");
			const yes = localize('yes', "Yes");
			const neverAgain = localize('yes never again', "Yes, Don't Show Again");
			const pick = await window.showWarningMessage(message, { modal: true }, yes, neverAgain);

			if (pick === neverAgain) {
				await config.update('confirmEmptyCommits', false, true);
			} else if (pick !== yes) {
				return;
			}
		}

		await this.commitWithAnyInput(repository, { empty: true });
	}

	@command('git.restoreCommitTemplate', { repository: true })
	async restoreCommitTemplate(repository: Repository): Promise<void> {
		repository.inputBox.value = await repository.getCommitTemplate();
	}

	@command('git.undoCommit', { repository: true })
	async undoCommit(repository: Repository): Promise<void> {
		const HEAD = repository.HEAD;

		if (!HEAD || !HEAD.commit) {
			window.showWarningMessage(localize('no more', "Can't undo because HEAD doesn't point to any commit."));
			return;
		}

		const commit = await repository.getCommit('HEAD');

		if (commit.parents.length > 0) {
			await repository.reset('HEAD~');
		} else {
			await repository.deleteRef('HEAD');
			await this.unstageAll(repository);
		}

		repository.inputBox.value = commit.message;
	}

	@command('git.checkout', { repository: true })
	async checkout(repository: Repository, treeish: string): Promise<boolean> {
		if (typeof treeish === 'string') {
			await repository.checkout(treeish);
			return true;
		}

		const config = workspace.getConfiguration('git');
		const checkoutType = config.get<string>('checkoutType') || 'all';
		const includeTags = checkoutType === 'all' || checkoutType === 'tags';
		const includeRemotes = checkoutType === 'all' || checkoutType === 'remote';

		const createBranch = new CreateBranchItem(this);

		const heads = repository.refs.filter(ref => ref.type === RefType.Head)
			.map(ref => new CheckoutItem(ref));

		const tags = (includeTags ? repository.refs.filter(ref => ref.type === RefType.Tag) : [])
			.map(ref => new CheckoutTagItem(ref));

		const remoteHeads = (includeRemotes ? repository.refs.filter(ref => ref.type === RefType.RemoteHead) : [])
			.map(ref => new CheckoutRemoteHeadItem(ref));

		const picks = [createBranch, ...heads, ...tags, ...remoteHeads];
		const placeHolder = localize('select a ref to checkout', 'Select a ref to checkout');
		const choice = await window.showQuickPick(picks, { placeHolder });

		if (!choice) {
			return false;
		}

		await choice.run(repository);
		return true;
	}

	@command('git.branch', { repository: true })
	async branch(repository: Repository): Promise<void> {
		const config = workspace.getConfiguration('git');
		const branchValidationRegex = config.get<string>('branchValidationRegex')!;
		const branchWhitespaceChar = config.get<string>('branchWhitespaceChar')!;
		const validateName = new RegExp(branchValidationRegex);
		const sanitize = (name: string) => {
			name = name.trim();

			if (!name) {
				return name;
			}

			return name.replace(/^\.|\/\.|\.\.|~|\^|:|\/$|\.lock$|\.lock\/|\\|\*|\s|^\s*$|\.$|\[|\]$/g, branchWhitespaceChar);
		};

		const result = await window.showInputBox({
			placeHolder: localize('branch name', "Branch name"),
			prompt: localize('provide branch name', "Please provide a branch name"),
			ignoreFocusOut: true,
			validateInput: (name: string) => {
				if (validateName.test(sanitize(name))) {
					return null;
				}

				return localize('branch name format invalid', "Branch name needs to match regex: {0}", branchValidationRegex);
			}
		});

		const name = sanitize(result || '');

		if (!name) {
			return;
		}

		await repository.branch(name, true);
	}

	@command('git.deleteBranch', { repository: true })
	async deleteBranch(repository: Repository, name: string, force?: boolean): Promise<void> {
		let run: (force?: boolean) => Promise<void>;
		if (typeof name === 'string') {
			run = force => repository.deleteBranch(name, force);
		} else {
			const currentHead = repository.HEAD && repository.HEAD.name;
			const heads = repository.refs.filter(ref => ref.type === RefType.Head && ref.name !== currentHead)
				.map(ref => new BranchDeleteItem(ref));

			const placeHolder = localize('select branch to delete', 'Select a branch to delete');
			const choice = await window.showQuickPick<BranchDeleteItem>(heads, { placeHolder });

			if (!choice || !choice.branchName) {
				return;
			}
			name = choice.branchName;
			run = force => choice.run(repository, force);
		}

		try {
			await run(force);
		} catch (err) {
			if (err.gitErrorCode !== GitErrorCodes.BranchNotFullyMerged) {
				throw err;
			}

			const message = localize('confirm force delete branch', "The branch '{0}' is not fully merged. Delete anyway?", name);
			const yes = localize('delete branch', "Delete Branch");
			const pick = await window.showWarningMessage(message, { modal: true }, yes);

			if (pick === yes) {
				await run(true);
			}
		}
	}

	@command('git.renameBranch', { repository: true })
	async renameBranch(repository: Repository): Promise<void> {
		const placeHolder = localize('provide branch name', "Please provide a branch name");
		const name = await window.showInputBox({ placeHolder });

		if (!name || name.trim().length === 0) {
			return;
		}

		try {
			await repository.renameBranch(name);
		} catch (err) {
			switch (err.gitErrorCode) {
				case GitErrorCodes.InvalidBranchName:
					window.showErrorMessage(localize('invalid branch name', 'Invalid branch name'));
					return;
				case GitErrorCodes.BranchAlreadyExists:
					window.showErrorMessage(localize('branch already exists', "A branch named '{0}' already exists", name));
					return;
				default:
					throw err;
			}
		}
	}

	@command('git.merge', { repository: true })
	async merge(repository: Repository): Promise<void> {
		const config = workspace.getConfiguration('git');
		const checkoutType = config.get<string>('checkoutType') || 'all';
		const includeRemotes = checkoutType === 'all' || checkoutType === 'remote';

		const heads = repository.refs.filter(ref => ref.type === RefType.Head)
			.filter(ref => ref.name || ref.commit)
			.map(ref => new MergeItem(ref as Branch));

		const remoteHeads = (includeRemotes ? repository.refs.filter(ref => ref.type === RefType.RemoteHead) : [])
			.filter(ref => ref.name || ref.commit)
			.map(ref => new MergeItem(ref as Branch));

		const picks = [...heads, ...remoteHeads];
		const placeHolder = localize('select a branch to merge from', 'Select a branch to merge from');
		const choice = await window.showQuickPick<MergeItem>(picks, { placeHolder });

		if (!choice) {
			return;
		}

		await choice.run(repository);
	}

	@command('git.createTag', { repository: true })
	async createTag(repository: Repository): Promise<void> {
		const inputTagName = await window.showInputBox({
			placeHolder: localize('tag name', "Tag name"),
			prompt: localize('provide tag name', "Please provide a tag name"),
			ignoreFocusOut: true
		});

		if (!inputTagName) {
			return;
		}

		const inputMessage = await window.showInputBox({
			placeHolder: localize('tag message', "Message"),
			prompt: localize('provide tag message', "Please provide a message to annotate the tag"),
			ignoreFocusOut: true
		});

		const name = inputTagName.replace(/^\.|\/\.|\.\.|~|\^|:|\/$|\.lock$|\.lock\/|\\|\*|\s|^\s*$|\.$/g, '-');
		const message = inputMessage || name;
		await repository.tag(name, message);
	}

	@command('git.fetch', { repository: true })
	async fetch(repository: Repository): Promise<void> {
		if (repository.remotes.length === 0) {
			window.showWarningMessage(localize('no remotes to fetch', "This repository has no remotes configured to fetch from."));
			return;
		}

		await repository.fetchDefault();
	}

	@command('git.fetchAll', { repository: true })
	async fetchAll(repository: Repository): Promise<void> {
		if (repository.remotes.length === 0) {
			window.showWarningMessage(localize('no remotes to fetch', "This repository has no remotes configured to fetch from."));
			return;
		}

		await repository.fetchAll();
	}

	@command('git.pullFrom', { repository: true })
	async pullFrom(repository: Repository): Promise<void> {
		const remotes = repository.remotes;

		if (remotes.length === 0) {
			window.showWarningMessage(localize('no remotes to pull', "Your repository has no remotes configured to pull from."));
			return;
		}

		const remotePicks = remotes.filter(r => r.fetchUrl !== undefined).map(r => ({ label: r.name, description: r.fetchUrl! }));
		const placeHolder = localize('pick remote pull repo', "Pick a remote to pull the branch from");
		const remotePick = await window.showQuickPick(remotePicks, { placeHolder });

		if (!remotePick) {
			return;
		}

		const remoteRefs = repository.refs;
		const remoteRefsFiltered = remoteRefs.filter(r => (r.remote === remotePick.label));
		const branchPicks = remoteRefsFiltered.map(r => ({ label: r.name })) as { label: string; description: string }[];
		const branchPlaceHolder = localize('pick branch pull', "Pick a branch to pull from");
		const branchPick = await window.showQuickPick(branchPicks, { placeHolder: branchPlaceHolder });

		if (!branchPick) {
			return;
		}

		const remoteCharCnt = remotePick.label.length;

		await repository.pullFrom(false, remotePick.label, branchPick.label.slice(remoteCharCnt + 1));
	}

	@command('git.pull', { repository: true })
	async pull(repository: Repository): Promise<void> {
		const remotes = repository.remotes;

		if (remotes.length === 0) {
			window.showWarningMessage(localize('no remotes to pull', "Your repository has no remotes configured to pull from."));
			return;
		}

		await repository.pull(repository.HEAD);
	}

	@command('git.pullRebase', { repository: true })
	async pullRebase(repository: Repository): Promise<void> {
		const remotes = repository.remotes;

		if (remotes.length === 0) {
			window.showWarningMessage(localize('no remotes to pull', "Your repository has no remotes configured to pull from."));
			return;
		}

		await repository.pullWithRebase(repository.HEAD);
	}

	private async _push(repository: Repository, pushOptions: PushOptions) {
		const remotes = repository.remotes;

		if (remotes.length === 0) {
			if (!pushOptions.silent) {
				window.showWarningMessage(localize('no remotes to push', "Your repository has no remotes configured to push to."));
			}
			return;
		}

		const config = workspace.getConfiguration('git', Uri.file(repository.root));
		let forcePushMode: ForcePushMode | undefined = undefined;

		if (pushOptions.forcePush) {
			if (!config.get<boolean>('allowForcePush')) {
				await window.showErrorMessage(localize('force push not allowed', "Force push is not allowed, please enable it with the 'git.allowForcePush' setting."));
				return;
			}

			forcePushMode = config.get<boolean>('useForcePushWithLease') === true ? ForcePushMode.ForceWithLease : ForcePushMode.Force;

			if (config.get<boolean>('confirmForcePush')) {
				const message = localize('confirm force push', "You are about to force push your changes, this can be destructive and could inadvertedly overwrite changes made by others.\n\nAre you sure to continue?");
				const yes = localize('ok', "OK");
				const neverAgain = localize('never ask again', "OK, Don't Ask Again");
				const pick = await window.showWarningMessage(message, { modal: true }, yes, neverAgain);

				if (pick === neverAgain) {
					config.update('confirmForcePush', false, true);
				} else if (pick !== yes) {
					return;
				}
			}
		}

		if (pushOptions.pushType === PushType.PushTags) {
			await repository.pushTags(undefined, forcePushMode);

			window.showInformationMessage(localize('push with tags success', "Successfully pushed with tags."));
			return;
		}

		if (!repository.HEAD || !repository.HEAD.name) {
			if (!pushOptions.silent) {
				window.showWarningMessage(localize('nobranch', "Please check out a branch to push to a remote."));
			}
			return;
		}

		if (pushOptions.pushType === PushType.Push) {
			try {
				await repository.push(repository.HEAD, forcePushMode);
			} catch (err) {
				if (err.gitErrorCode !== GitErrorCodes.NoUpstreamBranch) {
					throw err;
				}

				if (pushOptions.silent) {
					return;
				}

				const branchName = repository.HEAD.name;
				const message = localize('confirm publish branch', "The branch '{0}' has no upstream branch. Would you like to publish this branch?", branchName);
				const yes = localize('ok', "OK");
				const pick = await window.showWarningMessage(message, { modal: true }, yes);

				if (pick === yes) {
					await this.publish(repository);
				}
			}
		} else {
			const branchName = repository.HEAD.name;
			const picks = remotes.filter(r => r.pushUrl !== undefined).map(r => ({ label: r.name, description: r.pushUrl! }));
			const placeHolder = localize('pick remote', "Pick a remote to publish the branch '{0}' to:", branchName);
			const pick = await window.showQuickPick(picks, { placeHolder });

			if (!pick) {
				return;
			}

			await repository.pushTo(pick.label, branchName, undefined, forcePushMode);
		}
	}

	@command('git.push', { repository: true })
	async push(repository: Repository): Promise<void> {
		await this._push(repository, { pushType: PushType.Push });
	}

	@command('git.pushForce', { repository: true })
	async pushForce(repository: Repository): Promise<void> {
		await this._push(repository, { pushType: PushType.Push, forcePush: true });
	}

	@command('git.pushWithTags', { repository: true })
	async pushWithTags(repository: Repository): Promise<void> {
		await this._push(repository, { pushType: PushType.PushTags });
	}

	@command('git.pushWithTagsForce', { repository: true })
	async pushWithTagsForce(repository: Repository): Promise<void> {
		await this._push(repository, { pushType: PushType.PushTags, forcePush: true });
	}

	@command('git.pushTo', { repository: true })
	async pushTo(repository: Repository): Promise<void> {
		await this._push(repository, { pushType: PushType.PushTo });
	}

	@command('git.pushToForce', { repository: true })
	async pushToForce(repository: Repository): Promise<void> {
		await this._push(repository, { pushType: PushType.PushTo, forcePush: true });
	}

	private async _sync(repository: Repository, rebase: boolean): Promise<void> {
		const HEAD = repository.HEAD;

		if (!HEAD || !HEAD.upstream) {
			return;
		}

		const remoteName = HEAD.remote || HEAD.upstream.remote;
		const remote = repository.remotes.find(r => r.name === remoteName);
		const isReadonly = remote && remote.isReadOnly;

		const config = workspace.getConfiguration('git');
		const shouldPrompt = !isReadonly && config.get<boolean>('confirmSync') === true;

		if (shouldPrompt) {
			const message = localize('sync is unpredictable', "This action will push and pull commits to and from '{0}/{1}'.", HEAD.upstream.remote, HEAD.upstream.name);
			const yes = localize('ok', "OK");
			const neverAgain = localize('never again', "OK, Don't Show Again");
			const pick = await window.showWarningMessage(message, { modal: true }, yes, neverAgain);

			if (pick === neverAgain) {
				await config.update('confirmSync', false, true);
			} else if (pick !== yes) {
				return;
			}
		}

		if (rebase) {
			await repository.syncRebase(HEAD);
		} else {
			await repository.sync(HEAD);
		}
	}

	@command('git.sync', { repository: true })
	sync(repository: Repository): Promise<void> {
		return this._sync(repository, false);
	}

	@command('git._syncAll')
	async syncAll(): Promise<void> {
		await Promise.all(this.model.repositories.map(async repository => {
			const HEAD = repository.HEAD;

			if (!HEAD || !HEAD.upstream) {
				return;
			}

			await repository.sync(HEAD);
		}));
	}

	@command('git.syncRebase', { repository: true })
	syncRebase(repository: Repository): Promise<void> {
		return this._sync(repository, true);
	}

	@command('git.publish', { repository: true })
	async publish(repository: Repository): Promise<void> {
		const remotes = repository.remotes;

		if (remotes.length === 0) {
			window.showWarningMessage(localize('no remotes to publish', "Your repository has no remotes configured to publish to."));
			return;
		}

		const branchName = repository.HEAD && repository.HEAD.name || '';
		const selectRemote = async () => {
			const picks = repository.remotes.map(r => r.name);
			const placeHolder = localize('pick remote', "Pick a remote to publish the branch '{0}' to:", branchName);
			return await window.showQuickPick(picks, { placeHolder });
		};
		const choice = remotes.length === 1 ? remotes[0].name : await selectRemote();

		if (!choice) {
			return;
		}

		await repository.pushTo(choice, branchName, true);
	}

	@command('git.ignore')
	async ignore(...resourceStates: SourceControlResourceState[]): Promise<void> {
		resourceStates = resourceStates.filter(s => !!s);

		if (resourceStates.length === 0 || (resourceStates[0] && !(resourceStates[0].resourceUri instanceof Uri))) {
			const resource = this.getSCMResource();

			if (!resource) {
				return;
			}

			resourceStates = [resource];
		}

		const resources = resourceStates
			.filter(s => s instanceof Resource)
			.map(r => r.resourceUri);

		if (!resources.length) {
			return;
		}

		await this.runByRepository(resources, async (repository, resources) => repository.ignore(resources));
	}

	private async _stash(repository: Repository, includeUntracked = false): Promise<void> {
		const noUnstagedChanges = repository.workingTreeGroup.resourceStates.length === 0;
		const noStagedChanges = repository.indexGroup.resourceStates.length === 0;

		if (noUnstagedChanges && noStagedChanges) {
			window.showInformationMessage(localize('no changes stash', "There are no changes to stash."));
			return;
		}

		const message = await this.getStashMessage();

		if (typeof message === 'undefined') {
			return;
		}

		await repository.createStash(message, includeUntracked);
	}

	private async getStashMessage(): Promise<string | undefined> {
		return await window.showInputBox({
			prompt: localize('provide stash message', "Optionally provide a stash message"),
			placeHolder: localize('stash message', "Stash message")
		});
	}

	@command('git.stash', { repository: true })
	stash(repository: Repository): Promise<void> {
		return this._stash(repository);
	}

	@command('git.stashIncludeUntracked', { repository: true })
	stashIncludeUntracked(repository: Repository): Promise<void> {
		return this._stash(repository, true);
	}

	@command('git.stashPop', { repository: true })
	async stashPop(repository: Repository): Promise<void> {
		const placeHolder = localize('pick stash to pop', "Pick a stash to pop");
		const stash = await this.pickStash(repository, placeHolder);

		if (!stash) {
			return;
		}

		await repository.popStash(stash.index);
	}

	@command('git.stashPopLatest', { repository: true })
	async stashPopLatest(repository: Repository): Promise<void> {
		const stashes = await repository.getStashes();

		if (stashes.length === 0) {
			window.showInformationMessage(localize('no stashes', "There are no stashes in the repository."));
			return;
		}

		await repository.popStash();
	}

	@command('git.stashApply', { repository: true })
	async stashApply(repository: Repository): Promise<void> {
		const placeHolder = localize('pick stash to apply', "Pick a stash to apply");
		const stash = await this.pickStash(repository, placeHolder);

		if (!stash) {
			return;
		}

		await repository.applyStash(stash.index);
	}

	@command('git.stashApplyLatest', { repository: true })
	async stashApplyLatest(repository: Repository): Promise<void> {
		const stashes = await repository.getStashes();

		if (stashes.length === 0) {
			window.showInformationMessage(localize('no stashes', "There are no stashes in the repository."));
			return;
		}

		await repository.applyStash();
	}

	private async pickStash(repository: Repository, placeHolder: string): Promise<Stash | undefined> {
		const stashes = await repository.getStashes();

		if (stashes.length === 0) {
			window.showInformationMessage(localize('no stashes', "There are no stashes in the repository."));
			return;
		}

		const picks = stashes.map(stash => ({ label: `#${stash.index}:  ${stash.description}`, description: '', details: '', stash }));
		const result = await window.showQuickPick(picks, { placeHolder });
		return result && result.stash;
	}

	private createCommand(id: string, key: string, method: Function, options: CommandOptions): (...args: any[]) => any {
		const result = (...args: any[]) => {
			let result: Promise<any>;

			if (!options.repository) {
				result = Promise.resolve(method.apply(this, args));
			} else {
				// try to guess the repository based on the first argument
				const repository = this.model.getRepository(args[0]);
				let repositoryPromise: Promise<Repository | undefined>;

				if (repository) {
					repositoryPromise = Promise.resolve(repository);
				} else if (this.model.repositories.length === 1) {
					repositoryPromise = Promise.resolve(this.model.repositories[0]);
				} else {
					repositoryPromise = this.model.pickRepository();
				}

				result = repositoryPromise.then(repository => {
					if (!repository) {
						return Promise.resolve();
					}

					return Promise.resolve(method.apply(this, [repository, ...args]));
				});
			}

			/* __GDPR__
				"git.command" : {
					"command" : { "classification": "SystemMetaData", "purpose": "FeatureInsight" }
				}
			*/
			this.telemetryReporter.sendTelemetryEvent('git.command', { command: id });

			return result.catch(async err => {
				const options: MessageOptions = {
					modal: true
				};

				let message: string;
				let type: 'error' | 'warning' = 'error';

				const choices = new Map<string, () => void>();
				const openOutputChannelChoice = localize('open git log', "Open Git Log");
				const outputChannel = this.outputChannel as OutputChannel;
				choices.set(openOutputChannelChoice, () => outputChannel.show());

				switch (err.gitErrorCode) {
					case GitErrorCodes.DirtyWorkTree:
						message = localize('clean repo', "Please clean your repository working tree before checkout.");
						break;
					case GitErrorCodes.PushRejected:
						message = localize('cant push', "Can't push refs to remote. Try running 'Pull' first to integrate your changes.");
						break;
					case GitErrorCodes.Conflict:
						message = localize('merge conflicts', "There are merge conflicts. Resolve them before committing.");
						type = 'warning';
						options.modal = false;
						break;
					case GitErrorCodes.StashConflict:
						message = localize('stash merge conflicts', "There were merge conflicts while applying the stash.");
						type = 'warning';
						options.modal = false;
						break;
					case GitErrorCodes.NoUserNameConfigured:
					case GitErrorCodes.NoUserEmailConfigured:
						message = localize('missing user info', "Make sure you configure your 'user.name' and 'user.email' in git.");
						choices.set(localize('learn more', "Learn More"), () => commands.executeCommand('vscode.open', Uri.parse('https://git-scm.com/book/en/v2/Getting-Started-First-Time-Git-Setup')));
						break;
					default:
						const hint = (err.stderr || err.message || String(err))
							.replace(/^error: /mi, '')
							.replace(/^> husky.*$/mi, '')
							.split(/[\r\n]/)
							.filter((line: string) => !!line)
						[0];

						message = hint
							? localize('git error details', "Git: {0}", hint)
							: localize('git error', "Git error");

						break;
				}

				if (!message) {
					console.error(err);
					return;
				}

				const allChoices = Array.from(choices.keys());
				const result = type === 'error'
					? await window.showErrorMessage(message, options, ...allChoices)
					: await window.showWarningMessage(message, options, ...allChoices);

				if (result) {
					const resultFn = choices.get(result);

					if (resultFn) {
						resultFn();
					}
				}
			});
		};

		// patch this object, so people can call methods directly
		(this as any)[key] = result;

		return result;
	}

	private getSCMResource(uri?: Uri): Resource | undefined {
		uri = uri ? uri : (window.activeTextEditor && window.activeTextEditor.document.uri);

		this.outputChannel.appendLine(`git.getSCMResource.uri ${uri && uri.toString()}`);
		for (const r of this.model.repositories.map(r => r.root)) {
			this.outputChannel.appendLine(`repo root ${r}`);
		}

		if (!uri) {
			return undefined;
		}

		if (uri.scheme === 'git') {
			const { path } = fromGitUri(uri);
			uri = Uri.file(path);
		}

		if (uri.scheme === 'file') {
			const uriString = uri.toString();
			const repository = this.model.getRepository(uri);

			if (!repository) {
				return undefined;
			}

			return repository.workingTreeGroup.resourceStates.filter(r => r.resourceUri.toString() === uriString)[0]
				|| repository.indexGroup.resourceStates.filter(r => r.resourceUri.toString() === uriString)[0];
		}
		return undefined;
	}

	private runByRepository<T>(resource: Uri, fn: (repository: Repository, resource: Uri) => Promise<T>): Promise<T[]>;
	private runByRepository<T>(resources: Uri[], fn: (repository: Repository, resources: Uri[]) => Promise<T>): Promise<T[]>;
	private async runByRepository<T>(arg: Uri | Uri[], fn: (repository: Repository, resources: any) => Promise<T>): Promise<T[]> {
		const resources = arg instanceof Uri ? [arg] : arg;
		const isSingleResource = arg instanceof Uri;

		const groups = resources.reduce((result, resource) => {
			let repository = this.model.getRepository(resource);

			if (!repository) {
				console.warn('Could not find git repository for ', resource);
				return result;
			}

			// Could it be a submodule?
			if (pathEquals(resource.fsPath, repository.root)) {
				repository = this.model.getRepositoryForSubmodule(resource) || repository;
			}

			const tuple = result.filter(p => p.repository === repository)[0];

			if (tuple) {
				tuple.resources.push(resource);
			} else {
				result.push({ repository, resources: [resource] });
			}

			return result;
		}, [] as { repository: Repository, resources: Uri[] }[]);

		const promises = groups
			.map(({ repository, resources }) => fn(repository as Repository, isSingleResource ? resources[0] : resources));

		return Promise.all(promises);
	}

	dispose(): void {
		this.disposables.forEach(d => d.dispose());
	}
}
