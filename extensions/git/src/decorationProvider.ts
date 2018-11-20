/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import { window, workspace, Uri, Disposable, Event, EventEmitter, DecorationData, DecorationProvider, ThemeColor } from 'vscode';
import * as path from 'path';
import { Repository, GitResourceGroup } from './repository';
import { Model } from './model';
import { debounce } from './decorators';
import { filterEvent, dispose, anyEvent, fireEvent } from './util';
import { GitErrorCodes, Status } from './api/git';

type Callback = { resolve: (status: boolean) => void, reject: (err: any) => void };

class GitIgnoreDecorationProvider implements DecorationProvider {

	readonly onDidChangeDecorations: Event<Uri[]>;
	private queue = new Map<string, { repository: Repository; queue: Map<string, Callback>; }>();
	private disposables: Disposable[] = [];

	constructor(private model: Model) {
		//todo@joh -> events when the ignore status actually changes, not only when the file changes
		this.onDidChangeDecorations = fireEvent(anyEvent<any>(
			filterEvent(workspace.onDidSaveTextDocument, e => e.fileName.endsWith('.gitignore')),
			model.onDidOpenRepository,
			model.onDidCloseRepository
		));

		this.disposables.push(window.registerDecorationProvider(this));
	}

	provideDecoration(uri: Uri): Promise<DecorationData | undefined> {
		const repository = this.model.getRepository(uri);

		if (!repository) {
			return Promise.resolve(undefined);
		}

		let queueItem = this.queue.get(repository.root);

		if (!queueItem) {
			queueItem = { repository, queue: new Map<string, Callback>() };
			this.queue.set(repository.root, queueItem);
		}

		return new Promise<boolean>((resolve, reject) => {
			queueItem!.queue.set(uri.fsPath, { resolve, reject });
			this.checkIgnoreSoon();
		}).then(ignored => {
			if (ignored) {
				return <DecorationData>{
					priority: 3,
					color: new ThemeColor('gitDecoration.ignoredResourceForeground')
				};
			}
			return undefined;
		});
	}

	@debounce(500)
	private checkIgnoreSoon(): void {
		const queue = new Map(this.queue.entries());
		this.queue.clear();

		for (const [, item] of queue) {
			const paths = [...item.queue.keys()];

			item.repository.checkIgnore(paths).then(ignoreSet => {
				for (const [key, value] of item.queue.entries()) {
					value.resolve(ignoreSet.has(key));
				}
			}, err => {
				if (err.gitErrorCode !== GitErrorCodes.IsInSubmodule) {
					console.error(err);
				}

				for (const [, value] of item.queue.entries()) {
					value.reject(err);
				}
			});
		}
	}

	dispose(): void {
		this.disposables.forEach(d => d.dispose());
		this.queue.clear();
	}
}

class GitDecorationProvider implements DecorationProvider {

	private static SubmoduleDecorationData: DecorationData = {
		title: 'Submodule',
		letter: 'S',
		color: new ThemeColor('gitDecoration.submoduleResourceForeground')
	};

	private readonly _onDidChangeDecorations = new EventEmitter<Uri[]>();
	readonly onDidChangeDecorations: Event<Uri[]> = this._onDidChangeDecorations.event;

	private disposables: Disposable[] = [];
	private decorations = new Map<string, DecorationData>();

	constructor(private repository: Repository) {
		this.disposables.push(
			window.registerDecorationProvider(this),
			repository.onDidRunGitStatus(this.onDidRunGitStatus, this)
		);
	}

	private onDidRunGitStatus(): void {
		let newDecorations = new Map<string, DecorationData>();

		this.collectSubmoduleDecorationData(newDecorations);
		this.collectDecorationData(this.repository.indexGroup, newDecorations);
		this.collectDecorationData(this.repository.workingTreeGroup, newDecorations);
		this.collectDecorationData(this.repository.mergeGroup, newDecorations);

		const uris = new Set([...this.decorations.keys()].concat([...newDecorations.keys()]));
		this.decorations = newDecorations;
		this._onDidChangeDecorations.fire([...uris.values()].map(Uri.parse));
	}

	private collectDecorationData(group: GitResourceGroup, bucket: Map<string, DecorationData>): void {
		group.resourceStates.forEach(r => {
			if (r.resourceDecoration
				&& r.type !== Status.DELETED
				&& r.type !== Status.INDEX_DELETED
			) {
				// not deleted and has a decoration
				bucket.set(r.original.toString(), r.resourceDecoration);
			}
		});
	}

	private collectSubmoduleDecorationData(bucket: Map<string, DecorationData>): void {
		for (const submodule of this.repository.submodules) {
			bucket.set(Uri.file(path.join(this.repository.root, submodule.path)).toString(), GitDecorationProvider.SubmoduleDecorationData);
		}
	}

	provideDecoration(uri: Uri): DecorationData | undefined {
		return this.decorations.get(uri.toString());
	}

	dispose(): void {
		this.disposables.forEach(d => d.dispose());
	}
}


export class GitDecorations {

	private disposables: Disposable[] = [];
	private modelDisposables: Disposable[] = [];
	private providers = new Map<Repository, Disposable>();

	constructor(private model: Model) {
		this.disposables.push(new GitIgnoreDecorationProvider(model));

		const onEnablementChange = filterEvent(workspace.onDidChangeConfiguration, e => e.affectsConfiguration('git.decorations.enabled'));
		onEnablementChange(this.update, this, this.disposables);
		this.update();
	}

	private update(): void {
		const enabled = workspace.getConfiguration('git').get('decorations.enabled');

		if (enabled) {
			this.enable();
		} else {
			this.disable();
		}
	}

	private enable(): void {
		this.model.onDidOpenRepository(this.onDidOpenRepository, this, this.modelDisposables);
		this.model.onDidCloseRepository(this.onDidCloseRepository, this, this.modelDisposables);
		this.model.repositories.forEach(this.onDidOpenRepository, this);
	}

	private disable(): void {
		this.modelDisposables = dispose(this.modelDisposables);
		this.providers.forEach(value => value.dispose());
		this.providers.clear();
	}

	private onDidOpenRepository(repository: Repository): void {
		const provider = new GitDecorationProvider(repository);
		this.providers.set(repository, provider);
	}

	private onDidCloseRepository(repository: Repository): void {
		const provider = this.providers.get(repository);

		if (provider) {
			provider.dispose();
			this.providers.delete(repository);
		}
	}

	dispose(): void {
		this.disable();
		this.disposables = dispose(this.disposables);
	}
}
