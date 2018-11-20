/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import * as fs from 'fs';
import * as path from 'path';
import * as vscode from 'vscode';
import * as nls from 'vscode-nls';
import { ITypeScriptServiceClient } from '../typescriptService';
import { Lazy } from '../utils/lazy';
import { isImplicitProjectConfigFile } from '../utils/tsconfig';
import TsConfigProvider, { TSConfig } from '../utils/tsconfigProvider';


const localize = nls.loadMessageBundle();

type AutoDetect = 'on' | 'off' | 'build' | 'watch';


const exists = (file: string): Promise<boolean> =>
	new Promise<boolean>((resolve, _reject) => {
		fs.exists(file, (value: boolean) => {
			resolve(value);
		});
	});


interface TypeScriptTaskDefinition extends vscode.TaskDefinition {
	tsconfig: string;
	option?: string;
}

/**
 * Provides tasks for building `tsconfig.json` files in a project.
 */
class TscTaskProvider implements vscode.TaskProvider {
	private autoDetect: AutoDetect = 'on';
	private readonly tsconfigProvider: TsConfigProvider;
	private readonly disposables: vscode.Disposable[] = [];

	public constructor(
		private readonly client: Lazy<ITypeScriptServiceClient>
	) {
		this.tsconfigProvider = new TsConfigProvider();

		vscode.workspace.onDidChangeConfiguration(this.onConfigurationChanged, this, this.disposables);
		this.onConfigurationChanged();
	}

	dispose() {
		this.disposables.forEach(x => x.dispose());
	}

	public async provideTasks(token: vscode.CancellationToken): Promise<vscode.Task[]> {
		const folders = vscode.workspace.workspaceFolders;
		if (!folders || !folders.length) {
			return [];
		}

		const configPaths: Set<string> = new Set();
		const tasks: vscode.Task[] = [];
		for (const project of await this.getAllTsConfigs(token)) {
			if (!configPaths.has(project.path)) {
				configPaths.add(project.path);
				tasks.push(...(await this.getTasksForProject(project)));
			}
		}
		return tasks;
	}

	public resolveTask(_task: vscode.Task): vscode.Task | undefined {
		return undefined;
	}

	private async getAllTsConfigs(token: vscode.CancellationToken): Promise<TSConfig[]> {
		const out = new Set<TSConfig>();
		const configs = [
			...await this.getTsConfigForActiveFile(token),
			...await this.getTsConfigsInWorkspace()
		];
		for (const config of configs) {
			if (await exists(config.path)) {
				out.add(config);
			}
		}
		return Array.from(out);
	}

	private async getTsConfigForActiveFile(token: vscode.CancellationToken): Promise<TSConfig[]> {
		const editor = vscode.window.activeTextEditor;
		if (editor) {
			if (path.basename(editor.document.fileName).match(/^tsconfig\.(.\.)?json$/)) {
				const uri = editor.document.uri;
				return [{
					path: uri.fsPath,
					workspaceFolder: vscode.workspace.getWorkspaceFolder(uri)
				}];
			}
		}

		const file = this.getActiveTypeScriptFile();
		if (!file) {
			return [];
		}

		const response = await this.client.value.execute(
			'projectInfo',
			{ file, needFileNameList: false },
			token);
		if (response.type !== 'response' || !response.body) {
			return [];
		}

		const { configFileName } = response.body;
		if (configFileName && !isImplicitProjectConfigFile(configFileName)) {
			const normalizedConfigPath = path.normalize(configFileName);
			const uri = vscode.Uri.file(normalizedConfigPath);
			const folder = vscode.workspace.getWorkspaceFolder(uri);
			return [{
				path: normalizedConfigPath,
				workspaceFolder: folder
			}];
		}

		return [];
	}

	private async getTsConfigsInWorkspace(): Promise<TSConfig[]> {
		return Array.from(await this.tsconfigProvider.getConfigsForWorkspace());
	}

	private static async getCommand(project: TSConfig): Promise<string> {
		if (project.workspaceFolder) {
			const localTsc = await TscTaskProvider.getLocalTscAtPath(path.dirname(project.path));
			if (localTsc) {
				return localTsc;
			}

			const workspaceTsc = await TscTaskProvider.getLocalTscAtPath(project.workspaceFolder.uri.fsPath);
			if (workspaceTsc) {
				return workspaceTsc;
			}
		}

		// Use global tsc version
		return 'tsc';
	}

	private static async getLocalTscAtPath(folderPath: string): Promise<string | undefined> {
		const platform = process.platform;
		const bin = path.join(folderPath, 'node_modules', '.bin');
		if (platform === 'win32' && await exists(path.join(bin, 'tsc.cmd'))) {
			return path.join(bin, 'tsc.cmd');
		} else if ((platform === 'linux' || platform === 'darwin') && await exists(path.join(bin, 'tsc'))) {
			return path.join(bin, 'tsc');
		}
		return undefined;
	}

	private getActiveTypeScriptFile(): string | null {
		const editor = vscode.window.activeTextEditor;
		if (editor) {
			const document = editor.document;
			if (document && (document.languageId === 'typescript' || document.languageId === 'typescriptreact')) {
				return this.client.value.toPath(document.uri);
			}
		}
		return null;
	}

	private async getTasksForProject(project: TSConfig): Promise<vscode.Task[]> {
		const command = await TscTaskProvider.getCommand(project);
		const args = await this.getBuildShellArgs(project);
		const label = this.getLabelForTasks(project);

		const tasks: vscode.Task[] = [];

		if (this.autoDetect === 'build' || this.autoDetect === 'on') {
			const buildTaskidentifier: TypeScriptTaskDefinition = { type: 'typescript', tsconfig: label };
			const buildTask = new vscode.Task(
				buildTaskidentifier,
				project.workspaceFolder || vscode.TaskScope.Workspace,
				localize('buildTscLabel', 'build - {0}', label),
				'tsc',
				new vscode.ShellExecution(command, args),
				'$tsc');
			buildTask.group = vscode.TaskGroup.Build;
			buildTask.isBackground = false;
			tasks.push(buildTask);
		}

		if (this.autoDetect === 'watch' || this.autoDetect === 'on') {
			const watchTaskidentifier: TypeScriptTaskDefinition = { type: 'typescript', tsconfig: label, option: 'watch' };
			const watchTask = new vscode.Task(
				watchTaskidentifier,
				project.workspaceFolder || vscode.TaskScope.Workspace,
				localize('buildAndWatchTscLabel', 'watch - {0}', label),
				'tsc',
				new vscode.ShellExecution(command, ['--watch', ...args]),
				'$tsc-watch');
			watchTask.group = vscode.TaskGroup.Build;
			watchTask.isBackground = true;
			tasks.push(watchTask);
		}

		return tasks;
	}

	private getBuildShellArgs(project: TSConfig): Promise<Array<string>> {
		const defaultArgs = ['-p', project.path];
		return new Promise<Array<string>>((resolve) => {
			fs.readFile(project.path, (error, result) => {
				if (error) {
					return resolve(defaultArgs);
				}

				try {
					const tsconfig = JSON.parse(result.toString());
					if (tsconfig.references) {
						return resolve(['-b', project.path]);
					}
				} catch {
					// noop
				}
				return resolve(defaultArgs);
			});
		});
	}

	private getLabelForTasks(project: TSConfig): string {
		if (project.workspaceFolder) {
			return path.relative(project.workspaceFolder.uri.fsPath, project.path);
		}
		return project.path;
	}

	private onConfigurationChanged(): void {
		const type = vscode.workspace.getConfiguration('typescript.tsc').get<AutoDetect>('autoDetect');
		this.autoDetect = typeof type === 'undefined' ? 'on' : type;
	}
}

/**
 * Manages registrations of TypeScript task providers with VS Code.
 */
export default class TypeScriptTaskProviderManager {
	private taskProviderSub: vscode.Disposable | undefined = undefined;
	private readonly disposables: vscode.Disposable[] = [];

	constructor(
		private readonly client: Lazy<ITypeScriptServiceClient>
	) {
		vscode.workspace.onDidChangeConfiguration(this.onConfigurationChanged, this, this.disposables);
		this.onConfigurationChanged();
	}

	dispose() {
		if (this.taskProviderSub) {
			this.taskProviderSub.dispose();
			this.taskProviderSub = undefined;
		}
		this.disposables.forEach(x => x.dispose());
	}

	private onConfigurationChanged() {
		const autoDetect = vscode.workspace.getConfiguration('typescript.tsc').get<AutoDetect>('autoDetect');
		if (this.taskProviderSub && autoDetect === 'off') {
			this.taskProviderSub.dispose();
			this.taskProviderSub = undefined;
		} else if (!this.taskProviderSub && autoDetect !== 'off') {
			this.taskProviderSub = vscode.workspace.registerTaskProvider('typescript', new TscTaskProvider(this.client));
		}
	}
}