/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import { basename } from 'path';
import * as vscode from 'vscode';
import { CachedNavTreeResponse } from './features/baseCodeLensProvider';
import { DiagnosticKind } from './features/diagnostics';
import FileConfigurationManager from './features/fileConfigurationManager';
import TypeScriptServiceClient from './typescriptServiceClient';
import { CommandManager } from './utils/commandManager';
import { Disposable } from './utils/dispose';
import * as fileSchemes from './utils/fileSchemes';
import { LanguageDescription } from './utils/languageDescription';
import { memoize } from './utils/memoize';
import TelemetryReporter from './utils/telemetry';
import TypingsStatus from './utils/typingsStatus';


const validateSetting = 'validate.enable';
const suggestionSetting = 'suggestionActions.enabled';

export default class LanguageProvider extends Disposable {

	constructor(
		private readonly client: TypeScriptServiceClient,
		private readonly description: LanguageDescription,
		private readonly commandManager: CommandManager,
		private readonly telemetryReporter: TelemetryReporter,
		private readonly typingsStatus: TypingsStatus,
		private readonly fileConfigurationManager: FileConfigurationManager,
		private readonly onCompletionAccepted: (item: vscode.CompletionItem) => void,
	) {
		super();
		vscode.workspace.onDidChangeConfiguration(this.configurationChanged, this, this._disposables);
		this.configurationChanged();

		client.onReady(() => this.registerProviders());
	}

	@memoize
	private get documentSelector(): vscode.DocumentFilter[] {
		const documentSelector = [];
		for (const language of this.description.modeIds) {
			for (const scheme of fileSchemes.supportedSchemes) {
				documentSelector.push({ language, scheme });
			}
		}
		return documentSelector;
	}

	private async registerProviders(): Promise<void> {
		const selector = this.documentSelector;

		const cachedResponse = new CachedNavTreeResponse();

		this._register((await import('./features/completions')).register(selector, this.description.id, this.client, this.typingsStatus, this.fileConfigurationManager, this.commandManager, this.onCompletionAccepted));
		this._register((await import('./features/definitions')).register(selector, this.client));
		this._register((await import('./features/directiveCommentCompletions')).register(selector, this.client));
		this._register((await import('./features/documentHighlight')).register(selector, this.client));
		this._register((await import('./features/documentSymbol')).register(selector, this.client));
		this._register((await import('./features/folding')).register(selector, this.client));
		this._register((await import('./features/formatting')).register(selector, this.description.id, this.client, this.fileConfigurationManager));
		this._register((await import('./features/hover')).register(selector, this.client));
		this._register((await import('./features/implementations')).register(selector, this.client));
		this._register((await import('./features/implementationsCodeLens')).register(selector, this.description.id, this.client, cachedResponse));
		this._register((await import('./features/jsDocCompletions')).register(selector, this.client));
		this._register((await import('./features/organizeImports')).register(selector, this.client, this.commandManager, this.fileConfigurationManager, this.telemetryReporter));
		this._register((await import('./features/quickFix')).register(selector, this.client, this.fileConfigurationManager, this.commandManager, this.client.diagnosticsManager, this.telemetryReporter));
		this._register((await import('./features/refactor')).register(selector, this.client, this.fileConfigurationManager, this.commandManager, this.telemetryReporter));
		this._register((await import('./features/references')).register(selector, this.client));
		this._register((await import('./features/referencesCodeLens')).register(selector, this.description.id, this.client, cachedResponse));
		this._register((await import('./features/rename')).register(selector, this.client));
		this._register((await import('./features/signatureHelp')).register(selector, this.client));
		this._register((await import('./features/tagClosing')).register(selector, this.description.id, this.client));
		this._register((await import('./features/typeDefinitions')).register(selector, this.client));
	}

	private configurationChanged(): void {
		const config = vscode.workspace.getConfiguration(this.id, null);
		this.updateValidate(config.get(validateSetting, true));
		this.updateSuggestionDiagnostics(config.get(suggestionSetting, true));
	}

	public handles(resource: vscode.Uri, doc: vscode.TextDocument): boolean {
		if (doc && this.description.modeIds.indexOf(doc.languageId) >= 0) {
			return true;
		}

		const base = basename(resource.fsPath);
		return !!base && base === this.description.configFile;
	}

	private get id(): string {
		return this.description.id;
	}

	public get diagnosticSource(): string {
		return this.description.diagnosticSource;
	}

	private updateValidate(value: boolean) {
		this.client.diagnosticsManager.setValidate(this._diagnosticLanguage, value);
	}

	private updateSuggestionDiagnostics(value: boolean) {
		this.client.diagnosticsManager.setEnableSuggestions(this._diagnosticLanguage, value);
	}

	public reInitialize(): void {
		this.client.diagnosticsManager.reInitialize();
	}

	public triggerAllDiagnostics(): void {
		this.client.bufferSyncSupport.requestAllDiagnostics();
	}

	public diagnosticsReceived(diagnosticsKind: DiagnosticKind, file: vscode.Uri, diagnostics: (vscode.Diagnostic & { reportUnnecessary: any })[]): void {
		const config = vscode.workspace.getConfiguration(this.id, file);
		const reportUnnecessary = config.get<boolean>('showUnused', true);
		this.client.diagnosticsManager.updateDiagnostics(file, this._diagnosticLanguage, diagnosticsKind, diagnostics.filter(diag => {
			if (!reportUnnecessary) {
				diag.tags = undefined;
				if (diag.reportUnnecessary && diag.severity === vscode.DiagnosticSeverity.Hint) {
					return false;
				}
			}
			return true;
		}));
	}

	public configFileDiagnosticsReceived(file: vscode.Uri, diagnostics: vscode.Diagnostic[]): void {
		this.client.diagnosticsManager.configFileDiagnosticsReceived(file, diagnostics);
	}

	private get _diagnosticLanguage() {
		return this.description.diagnosticLanguage;
	}
}