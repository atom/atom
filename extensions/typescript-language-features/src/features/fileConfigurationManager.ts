/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import * as vscode from 'vscode';
import * as Proto from '../protocol';
import { ITypeScriptServiceClient } from '../typescriptService';
import API from '../utils/api';
import { isTypeScriptDocument } from '../utils/languageModeIds';
import { ResourceMap } from '../utils/resourceMap';


function objsAreEqual<T>(a: T, b: T): boolean {
	let keys = Object.keys(a);
	for (let i = 0; i < keys.length; i++) {
		let key = keys[i];
		if ((a as any)[key] !== (b as any)[key]) {
			return false;
		}
	}
	return true;
}

interface FileConfiguration {
	readonly formatOptions: Proto.FormatCodeSettings;
	readonly preferences: Proto.UserPreferences;
}

function areFileConfigurationsEqual(a: FileConfiguration, b: FileConfiguration): boolean {
	return (
		objsAreEqual(a.formatOptions, b.formatOptions)
		&& objsAreEqual(a.preferences, b.preferences)
	);
}

export default class FileConfigurationManager {
	private onDidCloseTextDocumentSub: vscode.Disposable | undefined;
	private readonly formatOptions = new ResourceMap<Promise<FileConfiguration | undefined>>();

	public constructor(
		private readonly client: ITypeScriptServiceClient
	) {
		this.onDidCloseTextDocumentSub = vscode.workspace.onDidCloseTextDocument(textDocument => {
			// When a document gets closed delete the cached formatting options.
			// This is necessary since the tsserver now closed a project when its
			// last file in it closes which drops the stored formatting options
			// as well.
			this.formatOptions.delete(textDocument.uri);
		});
	}

	public dispose() {
		if (this.onDidCloseTextDocumentSub) {
			this.onDidCloseTextDocumentSub.dispose();
			this.onDidCloseTextDocumentSub = undefined;
		}
	}

	public async ensureConfigurationForDocument(
		document: vscode.TextDocument,
		token: vscode.CancellationToken
	): Promise<void> {
		const formattingOptions = this.getFormattingOptions(document);
		if (formattingOptions) {
			return this.ensureConfigurationOptions(document, formattingOptions, token);
		}
	}

	private getFormattingOptions(
		document: vscode.TextDocument
	): vscode.FormattingOptions | undefined {
		const editor = vscode.window.visibleTextEditors.find(editor => editor.document.fileName === document.fileName);
		return editor
			? {
				tabSize: editor.options.tabSize,
				insertSpaces: editor.options.insertSpaces
			} as vscode.FormattingOptions
			: undefined;
	}

	public async ensureConfigurationOptions(
		document: vscode.TextDocument,
		options: vscode.FormattingOptions,
		token: vscode.CancellationToken
	): Promise<void> {
		const file = this.client.toPath(document.uri);
		if (!file) {
			return;
		}

		const currentOptions = this.getFileOptions(document, options);
		const cachedOptions = this.formatOptions.get(document.uri);
		if (cachedOptions) {
			const cachedOptionsValue = await cachedOptions;
			if (cachedOptionsValue && areFileConfigurationsEqual(cachedOptionsValue, currentOptions)) {
				return;
			}
		}

		let resolve: (x: FileConfiguration | undefined) => void;
		this.formatOptions.set(document.uri, new Promise<FileConfiguration | undefined>(r => resolve = r));

		const args: Proto.ConfigureRequestArguments = {
			file,
			...currentOptions,
		};
		try {
			const response = await this.client.execute('configure', args, token);
			resolve!(response.type === 'response' ? currentOptions : undefined);
		} finally {
			resolve!(undefined);
		}
	}

	public async setGlobalConfigurationFromDocument(
		document: vscode.TextDocument,
		token: vscode.CancellationToken,
	): Promise<void> {
		const formattingOptions = this.getFormattingOptions(document);
		if (!formattingOptions) {
			return;
		}

		const args: Proto.ConfigureRequestArguments = {
			file: undefined /*global*/,
			...this.getFileOptions(document, formattingOptions),
		};
		await this.client.execute('configure', args, token);
	}

	public reset() {
		this.formatOptions.clear();
	}

	private getFileOptions(
		document: vscode.TextDocument,
		options: vscode.FormattingOptions
	): FileConfiguration {
		return {
			formatOptions: this.getFormatOptions(document, options),
			preferences: this.getPreferences(document)
		};
	}

	private getFormatOptions(
		document: vscode.TextDocument,
		options: vscode.FormattingOptions
	): Proto.FormatCodeSettings {
		const config = vscode.workspace.getConfiguration(
			isTypeScriptDocument(document) ? 'typescript.format' : 'javascript.format',
			document.uri);

		return {
			tabSize: options.tabSize,
			indentSize: options.tabSize,
			convertTabsToSpaces: options.insertSpaces,
			// We can use \n here since the editor normalizes later on to its line endings.
			newLineCharacter: '\n',
			insertSpaceAfterCommaDelimiter: config.get<boolean>('insertSpaceAfterCommaDelimiter'),
			insertSpaceAfterConstructor: config.get<boolean>('insertSpaceAfterConstructor'),
			insertSpaceAfterSemicolonInForStatements: config.get<boolean>('insertSpaceAfterSemicolonInForStatements'),
			insertSpaceBeforeAndAfterBinaryOperators: config.get<boolean>('insertSpaceBeforeAndAfterBinaryOperators'),
			insertSpaceAfterKeywordsInControlFlowStatements: config.get<boolean>('insertSpaceAfterKeywordsInControlFlowStatements'),
			insertSpaceAfterFunctionKeywordForAnonymousFunctions: config.get<boolean>('insertSpaceAfterFunctionKeywordForAnonymousFunctions'),
			insertSpaceBeforeFunctionParenthesis: config.get<boolean>('insertSpaceBeforeFunctionParenthesis'),
			insertSpaceAfterOpeningAndBeforeClosingNonemptyParenthesis: config.get<boolean>('insertSpaceAfterOpeningAndBeforeClosingNonemptyParenthesis'),
			insertSpaceAfterOpeningAndBeforeClosingNonemptyBrackets: config.get<boolean>('insertSpaceAfterOpeningAndBeforeClosingNonemptyBrackets'),
			insertSpaceAfterOpeningAndBeforeClosingNonemptyBraces: config.get<boolean>('insertSpaceAfterOpeningAndBeforeClosingNonemptyBraces'),
			insertSpaceAfterOpeningAndBeforeClosingTemplateStringBraces: config.get<boolean>('insertSpaceAfterOpeningAndBeforeClosingTemplateStringBraces'),
			insertSpaceAfterOpeningAndBeforeClosingJsxExpressionBraces: config.get<boolean>('insertSpaceAfterOpeningAndBeforeClosingJsxExpressionBraces'),
			insertSpaceAfterTypeAssertion: config.get<boolean>('insertSpaceAfterTypeAssertion'),
			placeOpenBraceOnNewLineForFunctions: config.get<boolean>('placeOpenBraceOnNewLineForFunctions'),
			placeOpenBraceOnNewLineForControlBlocks: config.get<boolean>('placeOpenBraceOnNewLineForControlBlocks'),
		};
	}

	private getPreferences(document: vscode.TextDocument): Proto.UserPreferences {
		if (this.client.apiVersion.lt(API.v290)) {
			return {};
		}

		const preferences = vscode.workspace.getConfiguration(
			isTypeScriptDocument(document) ? 'typescript.preferences' : 'javascript.preferences',
			document.uri);

		return {
			quotePreference: getQuoteStylePreference(preferences),
			importModuleSpecifierPreference: getImportModuleSpecifierPreference(preferences),
			allowTextChangesInNewFiles: document.uri.scheme === 'file'
		};
	}
}

function getQuoteStylePreference(config: vscode.WorkspaceConfiguration) {
	switch (config.get<string>('quoteStyle')) {
		case 'single': return 'single';
		case 'double': return 'double';
		default: return undefined;
	}
}

function getImportModuleSpecifierPreference(config: vscode.WorkspaceConfiguration) {
	switch (config.get<string>('importModuleSpecifier')) {
		case 'relative': return 'relative';
		case 'non-relative': return 'non-relative';
		default: return undefined;
	}
}