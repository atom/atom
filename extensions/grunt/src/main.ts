/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import * as path from 'path';
import * as fs from 'fs';
import * as cp from 'child_process';
import * as vscode from 'vscode';
import * as nls from 'vscode-nls';
const localize = nls.loadMessageBundle();

type AutoDetect = 'on' | 'off';

function exists(file: string): Promise<boolean> {
	return new Promise<boolean>((resolve, _reject) => {
		fs.exists(file, (value) => {
			resolve(value);
		});
	});
}

function exec(command: string, options: cp.ExecOptions): Promise<{ stdout: string; stderr: string }> {
	return new Promise<{ stdout: string; stderr: string }>((resolve, reject) => {
		cp.exec(command, options, (error, stdout, stderr) => {
			if (error) {
				reject({ error, stdout, stderr });
			}
			resolve({ stdout, stderr });
		});
	});
}

const buildNames: string[] = ['build', 'compile', 'watch'];
function isBuildTask(name: string): boolean {
	for (let buildName of buildNames) {
		if (name.indexOf(buildName) !== -1) {
			return true;
		}
	}
	return false;
}

const testNames: string[] = ['test'];
function isTestTask(name: string): boolean {
	for (let testName of testNames) {
		if (name.indexOf(testName) !== -1) {
			return true;
		}
	}
	return false;
}

let _channel: vscode.OutputChannel;
function getOutputChannel(): vscode.OutputChannel {
	if (!_channel) {
		_channel = vscode.window.createOutputChannel('Gulp Auto Detection');
	}
	return _channel;
}

interface GruntTaskDefinition extends vscode.TaskDefinition {
	task: string;
	file?: string;
}

class FolderDetector {

	private fileWatcher: vscode.FileSystemWatcher | undefined;
	private promise: Thenable<vscode.Task[]> | undefined;

	constructor(private _workspaceFolder: vscode.WorkspaceFolder) {
	}

	public get workspaceFolder(): vscode.WorkspaceFolder {
		return this._workspaceFolder;
	}

	public isEnabled(): boolean {
		return vscode.workspace.getConfiguration('grunt', this._workspaceFolder.uri).get<AutoDetect>('autoDetect') === 'on';
	}

	public start(): void {
		let pattern = path.join(this._workspaceFolder.uri.fsPath, '{node_modules,[Gg]runtfile.js}');
		this.fileWatcher = vscode.workspace.createFileSystemWatcher(pattern);
		this.fileWatcher.onDidChange(() => this.promise = undefined);
		this.fileWatcher.onDidCreate(() => this.promise = undefined);
		this.fileWatcher.onDidDelete(() => this.promise = undefined);
	}

	public async getTasks(): Promise<vscode.Task[]> {
		if (!this.promise) {
			this.promise = this.computeTasks();
		}
		return this.promise;
	}

	private async computeTasks(): Promise<vscode.Task[]> {
		let rootPath = this._workspaceFolder.uri.scheme === 'file' ? this._workspaceFolder.uri.fsPath : undefined;
		let emptyTasks: vscode.Task[] = [];
		if (!rootPath) {
			return emptyTasks;
		}
		if (!await exists(path.join(rootPath, 'gruntfile.js')) && !await exists(path.join(rootPath, 'Gruntfile.js'))) {
			return emptyTasks;
		}

		let command: string;
		let platform = process.platform;
		if (platform === 'win32' && await exists(path.join(rootPath!, 'node_modules', '.bin', 'grunt.cmd'))) {
			command = path.join('.', 'node_modules', '.bin', 'grunt.cmd');
		} else if ((platform === 'linux' || platform === 'darwin') && await exists(path.join(rootPath!, 'node_modules', '.bin', 'grunt'))) {
			command = path.join('.', 'node_modules', '.bin', 'grunt');
		} else {
			command = 'grunt';
		}

		let commandLine = `${command} --help --no-color`;
		try {
			let { stdout, stderr } = await exec(commandLine, { cwd: rootPath });
			if (stderr) {
				getOutputChannel().appendLine(stderr);
				getOutputChannel().show(true);
			}
			let result: vscode.Task[] = [];
			if (stdout) {
				// grunt lists tasks as follows (description is wrapped into a new line if too long):
				// ...
				// Available tasks
				//         uglify  Minify files with UglifyJS. *
				//         jshint  Validate files with JSHint. *
				//           test  Alias for "jshint", "qunit" tasks.
				//        default  Alias for "jshint", "qunit", "concat", "uglify" tasks.
				//           long  Alias for "eslint", "qunit", "browserify", "sass",
				//                 "autoprefixer", "uglify", tasks.
				//
				// Tasks run in the order specified

				let lines = stdout.split(/\r{0,1}\n/);
				let tasksStart = false;
				let tasksEnd = false;
				for (let line of lines) {
					if (line.length === 0) {
						continue;
					}
					if (!tasksStart && !tasksEnd) {
						if (line.indexOf('Available tasks') === 0) {
							tasksStart = true;
						}
					} else if (tasksStart && !tasksEnd) {
						if (line.indexOf('Tasks run in the order specified') === 0) {
							tasksEnd = true;
						} else {
							let regExp = /^\s*(\S.*\S)  \S/g;
							let matches = regExp.exec(line);
							if (matches && matches.length === 2) {
								let name = matches[1];
								let kind: GruntTaskDefinition = {
									type: 'grunt',
									task: name
								};
								let source = 'grunt';
								let options: vscode.ShellExecutionOptions = { cwd: this.workspaceFolder.uri.fsPath };
								let task = name.indexOf(' ') === -1
									? new vscode.Task(kind, this.workspaceFolder, name, source, new vscode.ShellExecution(`${command} ${name}`, options))
									: new vscode.Task(kind, this.workspaceFolder, name, source, new vscode.ShellExecution(`${command} "${name}"`, options));
								result.push(task);
								let lowerCaseTaskName = name.toLowerCase();
								if (isBuildTask(lowerCaseTaskName)) {
									task.group = vscode.TaskGroup.Build;
								} else if (isTestTask(lowerCaseTaskName)) {
									task.group = vscode.TaskGroup.Test;
								}
							}
						}
					}
				}
			}
			return result;
		} catch (err) {
			let channel = getOutputChannel();
			if (err.stderr) {
				channel.appendLine(err.stderr);
			}
			if (err.stdout) {
				channel.appendLine(err.stdout);
			}
			channel.appendLine(localize('execFailed', 'Auto detecting Grunt for folder {0} failed with error: {1}', this.workspaceFolder.name, err.error ? err.error.toString() : 'unknown'));
			channel.show(true);
			return emptyTasks;
		}
	}

	public dispose() {
		this.promise = undefined;
		if (this.fileWatcher) {
			this.fileWatcher.dispose();
		}
	}
}

class TaskDetector {

	private taskProvider: vscode.Disposable | undefined;
	private detectors: Map<string, FolderDetector> = new Map();

	constructor() {
	}

	public start(): void {
		let folders = vscode.workspace.workspaceFolders;
		if (folders) {
			this.updateWorkspaceFolders(folders, []);
		}
		vscode.workspace.onDidChangeWorkspaceFolders((event) => this.updateWorkspaceFolders(event.added, event.removed));
		vscode.workspace.onDidChangeConfiguration(this.updateConfiguration, this);
	}

	public dispose(): void {
		if (this.taskProvider) {
			this.taskProvider.dispose();
			this.taskProvider = undefined;
		}
		this.detectors.clear();
	}

	private updateWorkspaceFolders(added: vscode.WorkspaceFolder[], removed: vscode.WorkspaceFolder[]): void {
		for (let remove of removed) {
			let detector = this.detectors.get(remove.uri.toString());
			if (detector) {
				detector.dispose();
				this.detectors.delete(remove.uri.toString());
			}
		}
		for (let add of added) {
			let detector = new FolderDetector(add);
			if (detector.isEnabled()) {
				this.detectors.set(add.uri.toString(), detector);
				detector.start();
			}
		}
		this.updateProvider();
	}

	private updateConfiguration(): void {
		for (let detector of this.detectors.values()) {
			if (!detector.isEnabled()) {
				detector.dispose();
				this.detectors.delete(detector.workspaceFolder.uri.toString());
			}
		}
		let folders = vscode.workspace.workspaceFolders;
		if (folders) {
			for (let folder of folders) {
				if (!this.detectors.has(folder.uri.toString())) {
					let detector = new FolderDetector(folder);
					if (detector.isEnabled()) {
						this.detectors.set(folder.uri.toString(), detector);
						detector.start();
					}
				}
			}
		}
		this.updateProvider();
	}

	private updateProvider(): void {
		if (!this.taskProvider && this.detectors.size > 0) {
			this.taskProvider = vscode.workspace.registerTaskProvider('gulp', {
				provideTasks: () => {
					return this.getTasks();
				},
				resolveTask(_task: vscode.Task): vscode.Task | undefined {
					return undefined;
				}
			});
		}
		else if (this.taskProvider && this.detectors.size === 0) {
			this.taskProvider.dispose();
			this.taskProvider = undefined;
		}
	}

	public getTasks(): Promise<vscode.Task[]> {
		return this.computeTasks();
	}

	private computeTasks(): Promise<vscode.Task[]> {
		if (this.detectors.size === 0) {
			return Promise.resolve([]);
		} else if (this.detectors.size === 1) {
			return this.detectors.values().next().value.getTasks();
		} else {
			let promises: Promise<vscode.Task[]>[] = [];
			for (let detector of this.detectors.values()) {
				promises.push(detector.getTasks().then((value) => value, () => []));
			}
			return Promise.all(promises).then((values) => {
				let result: vscode.Task[] = [];
				for (let tasks of values) {
					if (tasks && tasks.length > 0) {
						result.push(...tasks);
					}
				}
				return result;
			});
		}
	}
}

let detector: TaskDetector;
export function activate(_context: vscode.ExtensionContext): void {
	detector = new TaskDetector();
	detector.start();
}

export function deactivate(): void {
	detector.dispose();
}