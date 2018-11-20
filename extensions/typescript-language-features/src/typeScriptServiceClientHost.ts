/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

/* --------------------------------------------------------------------------------------------
 * Includes code from typescript-sublime-plugin project, obtained from
 * https://github.com/Microsoft/TypeScript-Sublime-Plugin/blob/master/TypeScript%20Indent.tmPreferences
 * ------------------------------------------------------------------------------------------ */

import * as vscode from 'vscode';
import { DiagnosticKind } from './features/diagnostics';
import FileConfigurationManager from './features/fileConfigurationManager';
import LanguageProvider from './languageProvider';
import * as Proto from './protocol';
import * as PConst from './protocol.const';
import TypeScriptServiceClient from './typescriptServiceClient';
import API from './utils/api';
import { CommandManager } from './utils/commandManager';
import { Disposable } from './utils/dispose';
import { DiagnosticLanguage, LanguageDescription } from './utils/languageDescription';
import LogDirectoryProvider from './utils/logDirectoryProvider';
import { PluginManager } from './utils/plugins';
import * as typeConverters from './utils/typeConverters';
import TypingsStatus, { AtaProgressReporter } from './utils/typingsStatus';
import VersionStatus from './utils/versionStatus';

// Style check diagnostics that can be reported as warnings
const styleCheckDiagnostics = [
	6133, 	// variable is declared but never used
	6138, 	// property is declared but its value is never read
	7027,	// unreachable code detected
	7028,	// unused label
	7029,	// fall through case in switch
	7030	// not all code paths return a value
];

export default class TypeScriptServiceClientHost extends Disposable {
	private readonly typingsStatus: TypingsStatus;
	private readonly client: TypeScriptServiceClient;
	private readonly languages: LanguageProvider[] = [];
	private readonly languagePerId = new Map<string, LanguageProvider>();
	private readonly versionStatus: VersionStatus;
	private readonly fileConfigurationManager: FileConfigurationManager;

	private reportStyleCheckAsWarnings: boolean = true;

	constructor(
		descriptions: LanguageDescription[],
		workspaceState: vscode.Memento,
		pluginManager: PluginManager,
		private readonly commandManager: CommandManager,
		logDirectoryProvider: LogDirectoryProvider,
		onCompletionAccepted: (item: vscode.CompletionItem) => void,
	) {
		super();
		const handleProjectCreateOrDelete = () => {
			this.client.executeWithoutWaitingForResponse('reloadProjects', null);
			this.triggerAllDiagnostics();
		};
		const handleProjectChange = () => {
			setTimeout(() => {
				this.triggerAllDiagnostics();
			}, 1500);
		};
		const configFileWatcher = this._register(vscode.workspace.createFileSystemWatcher('**/[tj]sconfig.json'));
		configFileWatcher.onDidCreate(handleProjectCreateOrDelete, this, this._disposables);
		configFileWatcher.onDidDelete(handleProjectCreateOrDelete, this, this._disposables);
		configFileWatcher.onDidChange(handleProjectChange, this, this._disposables);

		const allModeIds = this.getAllModeIds(descriptions);
		this.client = this._register(new TypeScriptServiceClient(
			workspaceState,
			version => this.versionStatus.onDidChangeTypeScriptVersion(version),
			pluginManager,
			logDirectoryProvider,
			allModeIds));

		this.client.onDiagnosticsReceived(({ kind, resource, diagnostics }) => {
			this.diagnosticsReceived(kind, resource, diagnostics);
		}, null, this._disposables);

		this.client.onConfigDiagnosticsReceived(diag => this.configFileDiagnosticsReceived(diag), null, this._disposables);
		this.client.onResendModelsRequested(() => this.populateService(), null, this._disposables);

		this.versionStatus = this._register(new VersionStatus(resource => this.client.toPath(resource)));

		this._register(new AtaProgressReporter(this.client));
		this.typingsStatus = this._register(new TypingsStatus(this.client));
		this.fileConfigurationManager = this._register(new FileConfigurationManager(this.client));

		for (const description of descriptions) {
			const manager = new LanguageProvider(this.client, description, this.commandManager, this.client.telemetryReporter, this.typingsStatus, this.fileConfigurationManager, onCompletionAccepted);
			this.languages.push(manager);
			this._register(manager);
			this.languagePerId.set(description.id, manager);
		}

		import('./features/updatePathsOnRename').then(module =>
			this._register(module.register(this.client, this.fileConfigurationManager, uri => this.handles(uri))));

		import('./features/workspaceSymbols').then(module =>
			this._register(module.register(this.client, allModeIds)));

		this.client.ensureServiceStarted();
		this.client.onReady(() => {
			if (this.client.apiVersion.lt(API.v230)) {
				return;
			}

			const languages = new Set<string>();
			for (const plugin of pluginManager.plugins) {
				for (const language of plugin.languages) {
					languages.add(language);
				}
			}
			if (languages.size) {
				const description: LanguageDescription = {
					id: 'typescript-plugins',
					modeIds: Array.from(languages.values()),
					diagnosticSource: 'ts-plugin',
					diagnosticLanguage: DiagnosticLanguage.TypeScript,
					diagnosticOwner: 'typescript',
					isExternal: true
				};
				const manager = new LanguageProvider(this.client, description, this.commandManager, this.client.telemetryReporter, this.typingsStatus, this.fileConfigurationManager, onCompletionAccepted);
				this.languages.push(manager);
				this._register(manager);
				this.languagePerId.set(description.id, manager);
			}
		});

		this.client.onTsServerStarted(() => {
			this.triggerAllDiagnostics();
		});

		vscode.workspace.onDidChangeConfiguration(this.configurationChanged, this, this._disposables);
		this.configurationChanged();
	}

	private getAllModeIds(descriptions: LanguageDescription[]) {
		const allModeIds: string[] = [];
		for (const description of descriptions) {
			allModeIds.push(...description.modeIds);
		}
		return allModeIds;
	}

	public get serviceClient(): TypeScriptServiceClient {
		return this.client;
	}

	public reloadProjects(): void {
		this.client.executeWithoutWaitingForResponse('reloadProjects', null);
		this.triggerAllDiagnostics();
	}

	public async handles(resource: vscode.Uri): Promise<boolean> {
		const provider = await this.findLanguage(resource);
		if (provider) {
			return true;
		}
		return this.client.bufferSyncSupport.handles(resource);
	}

	private configurationChanged(): void {
		const typescriptConfig = vscode.workspace.getConfiguration('typescript');

		this.reportStyleCheckAsWarnings = typescriptConfig.get('reportStyleChecksAsWarnings', true);
	}

	private async findLanguage(resource: vscode.Uri): Promise<LanguageProvider | undefined> {
		try {
			const doc = await vscode.workspace.openTextDocument(resource);
			return this.languages.find(language => language.handles(resource, doc));
		} catch {
			return undefined;
		}
	}

	private triggerAllDiagnostics() {
		for (const language of this.languagePerId.values()) {
			language.triggerAllDiagnostics();
		}
	}

	private populateService(): void {
		this.fileConfigurationManager.reset();
		this.client.bufferSyncSupport.reOpenDocuments();
		this.client.bufferSyncSupport.requestAllDiagnostics();

		// See https://github.com/Microsoft/TypeScript/issues/5530
		vscode.workspace.saveAll(false).then(() => {
			for (const language of this.languagePerId.values()) {
				language.reInitialize();
			}
		});
	}

	private async diagnosticsReceived(
		kind: DiagnosticKind,
		resource: vscode.Uri,
		diagnostics: Proto.Diagnostic[]
	): Promise<void> {
		const language = await this.findLanguage(resource);
		if (language) {
			language.diagnosticsReceived(
				kind,
				resource,
				this.createMarkerDatas(diagnostics, language.diagnosticSource));
		}
	}

	private configFileDiagnosticsReceived(event: Proto.ConfigFileDiagnosticEvent): void {
		// See https://github.com/Microsoft/TypeScript/issues/10384
		const body = event.body;
		if (!body || !body.diagnostics || !body.configFile) {
			return;
		}

		(this.findLanguage(this.client.toResource(body.configFile))).then(language => {
			if (!language) {
				return;
			}
			if (body.diagnostics.length === 0) {
				language.configFileDiagnosticsReceived(this.client.toResource(body.configFile), []);
			} else if (body.diagnostics.length >= 1) {
				vscode.workspace.openTextDocument(vscode.Uri.file(body.configFile)).then((document) => {
					let curly: [number, number, number] | undefined = undefined;
					let nonCurly: [number, number, number] | undefined = undefined;
					let diagnostic: vscode.Diagnostic;
					for (let index = 0; index < document.lineCount; index++) {
						const line = document.lineAt(index);
						const text = line.text;
						const firstNonWhitespaceCharacterIndex = line.firstNonWhitespaceCharacterIndex;
						if (firstNonWhitespaceCharacterIndex < text.length) {
							if (text.charAt(firstNonWhitespaceCharacterIndex) === '{') {
								curly = [index, firstNonWhitespaceCharacterIndex, firstNonWhitespaceCharacterIndex + 1];
								break;
							} else {
								const matches = /\s*([^\s]*)(?:\s*|$)/.exec(text.substr(firstNonWhitespaceCharacterIndex));
								if (matches && matches.length >= 1) {
									nonCurly = [index, firstNonWhitespaceCharacterIndex, firstNonWhitespaceCharacterIndex + matches[1].length];
								}
							}
						}
					}
					const match = curly || nonCurly;
					if (match) {
						diagnostic = new vscode.Diagnostic(new vscode.Range(match[0], match[1], match[0], match[2]), body.diagnostics[0].text);
					} else {
						diagnostic = new vscode.Diagnostic(new vscode.Range(0, 0, 0, 0), body.diagnostics[0].text);
					}
					if (diagnostic) {
						diagnostic.source = language.diagnosticSource;
						language.configFileDiagnosticsReceived(this.client.toResource(body.configFile), [diagnostic]);
					}
				}, _error => {
					language.configFileDiagnosticsReceived(this.client.toResource(body.configFile), [new vscode.Diagnostic(new vscode.Range(0, 0, 0, 0), body.diagnostics[0].text)]);
				});
			}
		});
	}

	private createMarkerDatas(
		diagnostics: Proto.Diagnostic[],
		source: string
	): (vscode.Diagnostic & { reportUnnecessary: any })[] {
		return diagnostics.map(tsDiag => this.tsDiagnosticToVsDiagnostic(tsDiag, source));
	}

	private tsDiagnosticToVsDiagnostic(diagnostic: Proto.Diagnostic, source: string): vscode.Diagnostic & { reportUnnecessary: any } {
		const { start, end, text } = diagnostic;
		const range = new vscode.Range(typeConverters.Position.fromLocation(start), typeConverters.Position.fromLocation(end));
		const converted = new vscode.Diagnostic(range, text);
		converted.severity = this.getDiagnosticSeverity(diagnostic);
		converted.source = diagnostic.source || source;
		if (diagnostic.code) {
			converted.code = diagnostic.code;
		}
		const relatedInformation = diagnostic.relatedInformation;
		if (relatedInformation) {
			converted.relatedInformation = relatedInformation.map((info: any) => {
				let span = info.span;
				if (!span) {
					return undefined;
				}
				return new vscode.DiagnosticRelatedInformation(typeConverters.Location.fromTextSpan(this.client.toResource(span.file), span), info.message);
			}).filter((x: any) => !!x) as vscode.DiagnosticRelatedInformation[];
		}
		if (diagnostic.reportsUnnecessary) {
			converted.tags = [vscode.DiagnosticTag.Unnecessary];
		}
		(converted as vscode.Diagnostic & { reportUnnecessary: any }).reportUnnecessary = diagnostic.reportsUnnecessary;
		return converted as vscode.Diagnostic & { reportUnnecessary: any };
	}

	private getDiagnosticSeverity(diagnostic: Proto.Diagnostic): vscode.DiagnosticSeverity {
		if (this.reportStyleCheckAsWarnings
			&& this.isStyleCheckDiagnostic(diagnostic.code)
			&& diagnostic.category === PConst.DiagnosticCategory.error
		) {
			return vscode.DiagnosticSeverity.Warning;
		}

		switch (diagnostic.category) {
			case PConst.DiagnosticCategory.error:
				return vscode.DiagnosticSeverity.Error;

			case PConst.DiagnosticCategory.warning:
				return vscode.DiagnosticSeverity.Warning;

			case PConst.DiagnosticCategory.suggestion:
				return vscode.DiagnosticSeverity.Hint;

			default:
				return vscode.DiagnosticSeverity.Error;
		}
	}

	private isStyleCheckDiagnostic(code: number | undefined): boolean {
		return code ? styleCheckDiagnostics.indexOf(code) !== -1 : false;
	}
}
