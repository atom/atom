/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import { workspace, WorkspaceFoldersChangeEvent, Uri, window, Event, EventEmitter, QuickPickItem, Disposable, SourceControl, SourceControlResourceGroup, TextEditor, Memento, OutputChannel } from 'vscode';
import { Repository, RepositoryState } from './repository';
import { memoize, sequentialize, debounce } from './decorators';
import { dispose, anyEvent, filterEvent, isDescendant, firstIndex } from './util';
import { Git } from './git';
import * as path from 'path';
import * as fs from 'fs';
import * as nls from 'vscode-nls';
import { fromGitUri } from './uri';
import { GitErrorCodes } from './api/git';

const localize = nls.loadMessageBundle();

class RepositoryPick implements QuickPickItem {
	@memoize get label(): string {
		return path.basename(this.repository.root);
	}

	@memoize get description(): string {
		return [this.repository.headLabel, this.repository.syncLabel]
			.filter(l => !!l)
			.join(' ');
	}

	constructor(public readonly repository: Repository, public readonly index: number) { }
}

export interface ModelChangeEvent {
	repository: Repository;
	uri: Uri;
}

export interface OriginalResourceChangeEvent {
	repository: Repository;
	uri: Uri;
}

interface OpenRepository extends Disposable {
	repository: Repository;
}

export class Model {

	private _onDidOpenRepository = new EventEmitter<Repository>();
	readonly onDidOpenRepository: Event<Repository> = this._onDidOpenRepository.event;

	private _onDidCloseRepository = new EventEmitter<Repository>();
	readonly onDidCloseRepository: Event<Repository> = this._onDidCloseRepository.event;

	private _onDidChangeRepository = new EventEmitter<ModelChangeEvent>();
	readonly onDidChangeRepository: Event<ModelChangeEvent> = this._onDidChangeRepository.event;

	private _onDidChangeOriginalResource = new EventEmitter<OriginalResourceChangeEvent>();
	readonly onDidChangeOriginalResource: Event<OriginalResourceChangeEvent> = this._onDidChangeOriginalResource.event;

	private openRepositories: OpenRepository[] = [];
	get repositories(): Repository[] { return this.openRepositories.map(r => r.repository); }

	private possibleGitRepositoryPaths = new Set<string>();

	private disposables: Disposable[] = [];

	constructor(readonly git: Git, private globalState: Memento, private outputChannel: OutputChannel) {
		workspace.onDidChangeWorkspaceFolders(this.onDidChangeWorkspaceFolders, this, this.disposables);
		this.onDidChangeWorkspaceFolders({ added: workspace.workspaceFolders || [], removed: [] });

		window.onDidChangeVisibleTextEditors(this.onDidChangeVisibleTextEditors, this, this.disposables);
		this.onDidChangeVisibleTextEditors(window.visibleTextEditors);

		workspace.onDidChangeConfiguration(this.onDidChangeConfiguration, this, this.disposables);

		const fsWatcher = workspace.createFileSystemWatcher('**');
		this.disposables.push(fsWatcher);

		const onWorkspaceChange = anyEvent(fsWatcher.onDidChange, fsWatcher.onDidCreate, fsWatcher.onDidDelete);
		const onGitRepositoryChange = filterEvent(onWorkspaceChange, uri => /\/\.git\//.test(uri.path));
		const onPossibleGitRepositoryChange = filterEvent(onGitRepositoryChange, uri => !this.getRepository(uri));
		onPossibleGitRepositoryChange(this.onPossibleGitRepositoryChange, this, this.disposables);

		this.scanWorkspaceFolders();
	}

	/**
	 * Scans the first level of each workspace folder, looking
	 * for git repositories.
	 */
	private async scanWorkspaceFolders(): Promise<void> {
		const config = workspace.getConfiguration('git');
		const autoRepositoryDetection = config.get<boolean | 'subFolders' | 'openEditors'>('autoRepositoryDetection');

		if (autoRepositoryDetection !== true && autoRepositoryDetection !== 'subFolders') {
			return;
		}

		for (const folder of workspace.workspaceFolders || []) {
			const root = folder.uri.fsPath;

			try {
				const children = await new Promise<string[]>((c, e) => fs.readdir(root, (err, r) => err ? e(err) : c(r)));

				children
					.filter(child => child !== '.git')
					.forEach(child => this.openRepository(path.join(root, child)));

				const folderConfig = workspace.getConfiguration('git', folder.uri);
				const paths = folderConfig.get<string[]>('scanRepositories') || [];

				for (const possibleRepositoryPath of paths) {
					if (path.isAbsolute(possibleRepositoryPath)) {
						console.warn(localize('not supported', "Absolute paths not supported in 'git.scanRepositories' setting."));
						continue;
					}

					this.openRepository(path.join(root, possibleRepositoryPath));
				}
			} catch (err) {
				// noop
			}
		}
	}

	private onPossibleGitRepositoryChange(uri: Uri): void {
		this.eventuallyScanPossibleGitRepository(uri.fsPath.replace(/\.git.*$/, ''));
	}

	private eventuallyScanPossibleGitRepository(path: string) {
		this.possibleGitRepositoryPaths.add(path);
		this.eventuallyScanPossibleGitRepositories();
	}

	@debounce(500)
	private eventuallyScanPossibleGitRepositories(): void {
		for (const path of this.possibleGitRepositoryPaths) {
			this.openRepository(path);
		}

		this.possibleGitRepositoryPaths.clear();
	}

	private async onDidChangeWorkspaceFolders({ added, removed }: WorkspaceFoldersChangeEvent): Promise<void> {
		const possibleRepositoryFolders = added
			.filter(folder => !this.getOpenRepository(folder.uri));

		const activeRepositoriesList = window.visibleTextEditors
			.map(editor => this.getRepository(editor.document.uri))
			.filter(repository => !!repository) as Repository[];

		const activeRepositories = new Set<Repository>(activeRepositoriesList);
		const openRepositoriesToDispose = removed
			.map(folder => this.getOpenRepository(folder.uri))
			.filter(r => !!r)
			.filter(r => !activeRepositories.has(r!.repository))
			.filter(r => !(workspace.workspaceFolders || []).some(f => isDescendant(f.uri.fsPath, r!.repository.root))) as OpenRepository[];

		possibleRepositoryFolders.forEach(p => this.openRepository(p.uri.fsPath));
		openRepositoriesToDispose.forEach(r => r.dispose());
	}

	private onDidChangeConfiguration(): void {
		const possibleRepositoryFolders = (workspace.workspaceFolders || [])
			.filter(folder => workspace.getConfiguration('git', folder.uri).get<boolean>('enabled') === true)
			.filter(folder => !this.getOpenRepository(folder.uri));

		const openRepositoriesToDispose = this.openRepositories
			.map(repository => ({ repository, root: Uri.file(repository.repository.root) }))
			.filter(({ root }) => workspace.getConfiguration('git', root).get<boolean>('enabled') !== true)
			.map(({ repository }) => repository);

		possibleRepositoryFolders.forEach(p => this.openRepository(p.uri.fsPath));
		openRepositoriesToDispose.forEach(r => r.dispose());
	}

	private onDidChangeVisibleTextEditors(editors: TextEditor[]): void {
		const config = workspace.getConfiguration('git');
		const autoRepositoryDetection = config.get<boolean | 'subFolders' | 'openEditors'>('autoRepositoryDetection');

		if (autoRepositoryDetection !== true && autoRepositoryDetection !== 'openEditors') {
			return;
		}

		editors.forEach(editor => {
			const uri = editor.document.uri;

			if (uri.scheme !== 'file') {
				return;
			}

			const repository = this.getRepository(uri);

			if (repository) {
				return;
			}

			this.openRepository(path.dirname(uri.fsPath));
		});
	}

	@sequentialize
	async openRepository(path: string): Promise<void> {
		if (this.getRepository(path)) {
			return;
		}

		const config = workspace.getConfiguration('git', Uri.file(path));
		const enabled = config.get<boolean>('enabled') === true;

		if (!enabled) {
			return;
		}

		try {
			const rawRoot = await this.git.getRepositoryRoot(path);

			// This can happen whenever `path` has the wrong case sensitivity in
			// case insensitive file systems
			// https://github.com/Microsoft/vscode/issues/33498
			const repositoryRoot = Uri.file(rawRoot).fsPath;

			if (this.getRepository(repositoryRoot)) {
				return;
			}

			const config = workspace.getConfiguration('git');
			const ignoredRepos = new Set(config.get<Array<string>>('ignoredRepositories'));

			if (ignoredRepos.has(rawRoot)) {
				return;
			}

			const repository = new Repository(this.git.open(repositoryRoot), this.globalState);

			this.open(repository);
		} catch (err) {
			if (err.gitErrorCode === GitErrorCodes.NotAGitRepository) {
				return;
			}

			// console.error('Failed to find repository:', err);
		}
	}

	private open(repository: Repository): void {
		this.outputChannel.appendLine(`Open repository: ${repository.root}`);

		const onDidDisappearRepository = filterEvent(repository.onDidChangeState, state => state === RepositoryState.Disposed);
		const disappearListener = onDidDisappearRepository(() => dispose());
		const changeListener = repository.onDidChangeRepository(uri => this._onDidChangeRepository.fire({ repository, uri }));
		const originalResourceChangeListener = repository.onDidChangeOriginalResource(uri => this._onDidChangeOriginalResource.fire({ repository, uri }));

		const shouldDetectSubmodules = workspace
			.getConfiguration('git', Uri.file(repository.root))
			.get<boolean>('detectSubmodules') as boolean;

		const submodulesLimit = workspace
			.getConfiguration('git', Uri.file(repository.root))
			.get<number>('detectSubmodulesLimit') as number;

		const checkForSubmodules = () => {
			if (!shouldDetectSubmodules) {
				return;
			}

			if (repository.submodules.length > submodulesLimit) {
				window.showWarningMessage(localize('too many submodules', "The '{0}' repository has {1} submodules which won't be opened automatically. You can still open each one individually by opening a file within.", path.basename(repository.root), repository.submodules.length));
				statusListener.dispose();
			}

			repository.submodules
				.slice(0, submodulesLimit)
				.map(r => path.join(repository.root, r.path))
				.forEach(p => this.eventuallyScanPossibleGitRepository(p));
		};

		const statusListener = repository.onDidRunGitStatus(checkForSubmodules);
		checkForSubmodules();

		const dispose = () => {
			disappearListener.dispose();
			changeListener.dispose();
			originalResourceChangeListener.dispose();
			statusListener.dispose();
			repository.dispose();

			this.openRepositories = this.openRepositories.filter(e => e !== openRepository);
			this._onDidCloseRepository.fire(repository);
		};

		const openRepository = { repository, dispose };
		this.openRepositories.push(openRepository);
		this._onDidOpenRepository.fire(repository);
	}

	close(repository: Repository): void {
		const openRepository = this.getOpenRepository(repository);

		if (!openRepository) {
			return;
		}

		this.outputChannel.appendLine(`Close repository: ${repository.root}`);
		openRepository.dispose();
	}

	async pickRepository(): Promise<Repository | undefined> {
		if (this.openRepositories.length === 0) {
			throw new Error(localize('no repositories', "There are no available repositories"));
		}

		const picks = this.openRepositories.map((e, index) => new RepositoryPick(e.repository, index));
		const active = window.activeTextEditor;
		const repository = active && this.getRepository(active.document.fileName);
		const index = firstIndex(picks, pick => pick.repository === repository);

		// Move repository pick containing the active text editor to appear first
		if (index > -1) {
			picks.unshift(...picks.splice(index, 1));
		}

		const placeHolder = localize('pick repo', "Choose a repository");
		const pick = await window.showQuickPick(picks, { placeHolder });

		return pick && pick.repository;
	}

	getRepository(sourceControl: SourceControl): Repository | undefined;
	getRepository(resourceGroup: SourceControlResourceGroup): Repository | undefined;
	getRepository(path: string): Repository | undefined;
	getRepository(resource: Uri): Repository | undefined;
	getRepository(hint: any): Repository | undefined {
		const liveRepository = this.getOpenRepository(hint);
		return liveRepository && liveRepository.repository;
	}

	private getOpenRepository(repository: Repository): OpenRepository | undefined;
	private getOpenRepository(sourceControl: SourceControl): OpenRepository | undefined;
	private getOpenRepository(resourceGroup: SourceControlResourceGroup): OpenRepository | undefined;
	private getOpenRepository(path: string): OpenRepository | undefined;
	private getOpenRepository(resource: Uri): OpenRepository | undefined;
	private getOpenRepository(hint: any): OpenRepository | undefined {
		if (!hint) {
			return undefined;
		}

		if (hint instanceof Repository) {
			return this.openRepositories.filter(r => r.repository === hint)[0];
		}

		if (typeof hint === 'string') {
			hint = Uri.file(hint);
		}

		if (hint instanceof Uri) {
			let resourcePath: string;

			if (hint.scheme === 'git') {
				resourcePath = fromGitUri(hint).path;
			} else {
				resourcePath = hint.fsPath;
			}

			outer:
			for (const liveRepository of this.openRepositories.sort((a, b) => b.repository.root.length - a.repository.root.length)) {
				if (!isDescendant(liveRepository.repository.root, resourcePath)) {
					continue;
				}

				for (const submodule of liveRepository.repository.submodules) {
					const submoduleRoot = path.join(liveRepository.repository.root, submodule.path);

					if (isDescendant(submoduleRoot, resourcePath)) {
						continue outer;
					}
				}

				return liveRepository;
			}

			return undefined;
		}

		for (const liveRepository of this.openRepositories) {
			const repository = liveRepository.repository;

			if (hint === repository.sourceControl) {
				return liveRepository;
			}

			if (hint === repository.mergeGroup || hint === repository.indexGroup || hint === repository.workingTreeGroup) {
				return liveRepository;
			}
		}

		return undefined;
	}

	getRepositoryForSubmodule(submoduleUri: Uri): Repository | undefined {
		for (const repository of this.repositories) {
			for (const submodule of repository.submodules) {
				const submodulePath = path.join(repository.root, submodule.path);

				if (submodulePath === submoduleUri.fsPath) {
					return repository;
				}
			}
		}

		return undefined;
	}

	dispose(): void {
		const openRepositories = [...this.openRepositories];
		openRepositories.forEach(r => r.dispose());
		this.openRepositories = [];

		this.possibleGitRepositoryPaths.clear();
		this.disposables = dispose(this.disposables);
	}
}