/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import * as vscode from 'vscode';
import * as nls from 'vscode-nls';
import * as Proto from '../protocol';
import * as PConst from '../protocol.const';
import { ITypeScriptServiceClient } from '../typescriptService';
import API from '../utils/api';
import { nulToken } from '../utils/cancellation';
import { applyCodeAction } from '../utils/codeAction';
import { Command, CommandManager } from '../utils/commandManager';
import { ConfigurationDependentRegistration } from '../utils/dependentRegistration';
import { memoize } from '../utils/memoize';
import * as Previewer from '../utils/previewer';
import * as typeConverters from '../utils/typeConverters';
import TypingsStatus from '../utils/typingsStatus';
import FileConfigurationManager from './fileConfigurationManager';

const localize = nls.loadMessageBundle();

interface CommitCharactersSettings {
	readonly isNewIdentifierLocation: boolean;
	readonly isInValidCommitCharacterContext: boolean;
	readonly enableCallCompletions: boolean;
}

class MyCompletionItem extends vscode.CompletionItem {
	public readonly useCodeSnippet: boolean;

	constructor(
		public readonly position: vscode.Position,
		public readonly document: vscode.TextDocument,
		line: string,
		public readonly tsEntry: Proto.CompletionEntry,
		useCodeSnippetsOnMethodSuggest: boolean,
		public readonly commitCharactersSettings: CommitCharactersSettings,
		public readonly metadata: any | undefined,
	) {
		super(tsEntry.name, MyCompletionItem.convertKind(tsEntry.kind));

		if (tsEntry.isRecommended) {
			// Make sure isRecommended property always comes first
			// https://github.com/Microsoft/vscode/issues/40325
			this.sortText = tsEntry.sortText;
			this.preselect = true;
		} else if (tsEntry.source) {
			// De-prioritze auto-imports
			// https://github.com/Microsoft/vscode/issues/40311
			this.sortText = '\uffff' + tsEntry.sortText;
		} else {
			this.sortText = tsEntry.sortText;
		}

		this.position = position;
		this.useCodeSnippet = useCodeSnippetsOnMethodSuggest && (this.kind === vscode.CompletionItemKind.Function || this.kind === vscode.CompletionItemKind.Method);
		if (tsEntry.replacementSpan) {
			this.range = typeConverters.Range.fromTextSpan(tsEntry.replacementSpan);
		}

		if (tsEntry.insertText) {
			this.insertText = tsEntry.insertText;

			if (tsEntry.replacementSpan) {
				this.range = typeConverters.Range.fromTextSpan(tsEntry.replacementSpan);
				if (this.insertText[0] === '[') { // o.x -> o['x']
					this.filterText = '.' + this.label;
				}

				// Make sure we only replace a single line at most
				if (!this.range.isSingleLine) {
					this.range = new vscode.Range(this.range.start.line, this.range.start.character, this.range.start.line, line.length);
				}
			}
		}

		if (tsEntry.kindModifiers) {
			const kindModifiers = new Set(tsEntry.kindModifiers.split(/\s+/g));

			if (kindModifiers.has(PConst.KindModifiers.optional)) {
				if (!this.insertText) {
					this.insertText = this.label;
				}

				if (!this.filterText) {
					this.filterText = this.label;
				}
				this.label += '?';
			}

			if (kindModifiers.has(PConst.KindModifiers.color)) {
				this.kind = vscode.CompletionItemKind.Color;
			}

			if (tsEntry.kind === PConst.Kind.script) {
				for (const extModifier of PConst.KindModifiers.fileExtensionKindModifiers) {
					if (kindModifiers.has(extModifier)) {
						if (tsEntry.name.toLowerCase().endsWith(extModifier)) {
							this.detail = tsEntry.name;
						} else {
							this.detail = tsEntry.name + extModifier;
						}
						break;
					}
				}
			}
		}
		this.resolveRange(line);
	}

	private resolveRange(line: string): void {
		if (this.range) {
			return;
		}

		// Try getting longer, prefix based range for completions that span words
		const wordRange = this.document.getWordRangeAtPosition(this.position);
		const text = line.slice(Math.max(0, this.position.character - this.label.length), this.position.character).toLowerCase();
		const entryName = this.label.toLowerCase();
		for (let i = entryName.length; i >= 0; --i) {
			if (text.endsWith(entryName.substr(0, i)) && (!wordRange || wordRange.start.character > this.position.character - i)) {
				this.range = new vscode.Range(this.position.line, Math.max(0, this.position.character - i), this.position.line, this.position.character);
				break;
			}
		}
	}

	private static convertKind(kind: string): vscode.CompletionItemKind {
		switch (kind) {
			case PConst.Kind.primitiveType:
			case PConst.Kind.keyword:
				return vscode.CompletionItemKind.Keyword;
			case PConst.Kind.const:
				return vscode.CompletionItemKind.Constant;
			case PConst.Kind.let:
			case PConst.Kind.variable:
			case PConst.Kind.localVariable:
			case PConst.Kind.alias:
				return vscode.CompletionItemKind.Variable;
			case PConst.Kind.memberVariable:
			case PConst.Kind.memberGetAccessor:
			case PConst.Kind.memberSetAccessor:
				return vscode.CompletionItemKind.Field;
			case PConst.Kind.function:
				return vscode.CompletionItemKind.Function;
			case PConst.Kind.memberFunction:
			case PConst.Kind.constructSignature:
			case PConst.Kind.callSignature:
			case PConst.Kind.indexSignature:
				return vscode.CompletionItemKind.Method;
			case PConst.Kind.enum:
				return vscode.CompletionItemKind.Enum;
			case PConst.Kind.module:
			case PConst.Kind.externalModuleName:
				return vscode.CompletionItemKind.Module;
			case PConst.Kind.class:
			case PConst.Kind.type:
				return vscode.CompletionItemKind.Class;
			case PConst.Kind.interface:
				return vscode.CompletionItemKind.Interface;
			case PConst.Kind.warning:
			case PConst.Kind.script:
				return vscode.CompletionItemKind.File;
			case PConst.Kind.directory:
				return vscode.CompletionItemKind.Folder;
			case PConst.Kind.string:
				return vscode.CompletionItemKind.Constant;
		}
		return vscode.CompletionItemKind.Property;
	}

	@memoize
	public get commitCharacters(): string[] | undefined {
		if (this.commitCharactersSettings.isNewIdentifierLocation || !this.commitCharactersSettings.isInValidCommitCharacterContext) {
			return undefined;
		}

		const commitCharacters: string[] = [];
		switch (this.tsEntry.kind) {
			case PConst.Kind.memberGetAccessor:
			case PConst.Kind.memberSetAccessor:
			case PConst.Kind.constructSignature:
			case PConst.Kind.callSignature:
			case PConst.Kind.indexSignature:
			case PConst.Kind.enum:
			case PConst.Kind.interface:
				commitCharacters.push('.', ';');

				break;

			case PConst.Kind.module:
			case PConst.Kind.alias:
			case PConst.Kind.const:
			case PConst.Kind.let:
			case PConst.Kind.variable:
			case PConst.Kind.localVariable:
			case PConst.Kind.memberVariable:
			case PConst.Kind.class:
			case PConst.Kind.function:
			case PConst.Kind.memberFunction:
			case PConst.Kind.keyword:
			case PConst.Kind.parameter:
				commitCharacters.push('.', ',', ';');
				if (this.commitCharactersSettings.enableCallCompletions) {
					commitCharacters.push('(');
				}
				break;
		}
		return commitCharacters.length === 0 ? undefined : commitCharacters;
	}
}

class CompositeCommand implements Command {
	public static readonly ID = '_typescript.composite';
	public readonly id = CompositeCommand.ID;

	public execute(...commands: vscode.Command[]) {
		for (const command of commands) {
			vscode.commands.executeCommand(command.command, ...(command.arguments || []));
		}
	}
}

class CompletionAcceptedCommand implements Command {
	public static readonly ID = '_typescript.onCompletionAccepted';
	public readonly id = CompletionAcceptedCommand.ID;

	public constructor(
		private readonly onCompletionAccepted: (item: vscode.CompletionItem) => void,
	) { }

	public execute(item: vscode.CompletionItem) {
		this.onCompletionAccepted(item);
	}
}

class ApplyCompletionCodeActionCommand implements Command {
	public static readonly ID = '_typescript.applyCompletionCodeAction';
	public readonly id = ApplyCompletionCodeActionCommand.ID;

	public constructor(
		private readonly client: ITypeScriptServiceClient
	) { }

	public async execute(_file: string, codeActions: Proto.CodeAction[]): Promise<boolean> {
		if (codeActions.length === 0) {
			return true;
		}

		if (codeActions.length === 1) {
			return applyCodeAction(this.client, codeActions[0], nulToken);
		}

		interface MyQuickPickItem extends vscode.QuickPickItem {
			index: number;
		}

		const selection = await vscode.window.showQuickPick<MyQuickPickItem>(
			codeActions.map((action, i): MyQuickPickItem => ({
				label: action.description,
				description: '',
				index: i
			})), {
				placeHolder: localize('selectCodeAction', 'Select code action to apply')
			}
		);

		if (!selection) {
			return false;
		}

		const action = codeActions[selection.index];
		if (!action) {
			return false;
		}
		return applyCodeAction(this.client, action, nulToken);
	}
}

interface CompletionConfiguration {
	readonly useCodeSnippetsOnMethodSuggest: boolean;
	readonly nameSuggestions: boolean;
	readonly pathSuggestions: boolean;
	readonly autoImportSuggestions: boolean;
}

namespace CompletionConfiguration {
	export const useCodeSnippetsOnMethodSuggest = 'suggest.completeFunctionCalls';
	export const nameSuggestions = 'suggest.names';
	export const pathSuggestions = 'suggest.paths';
	export const autoImportSuggestions = 'suggest.autoImports';

	export function getConfigurationForResource(
		modeId: string,
		resource: vscode.Uri
	): CompletionConfiguration {
		const config = vscode.workspace.getConfiguration(modeId, resource);
		return {
			useCodeSnippetsOnMethodSuggest: config.get<boolean>(CompletionConfiguration.useCodeSnippetsOnMethodSuggest, false),
			pathSuggestions: config.get<boolean>(CompletionConfiguration.pathSuggestions, true),
			autoImportSuggestions: config.get<boolean>(CompletionConfiguration.autoImportSuggestions, true),
			nameSuggestions: config.get<boolean>(CompletionConfiguration.nameSuggestions, true)
		};
	}
}

class TypeScriptCompletionItemProvider implements vscode.CompletionItemProvider {

	public static readonly triggerCharacters = ['.', '"', '\'', '/', '@', '<'];

	constructor(
		private readonly client: ITypeScriptServiceClient,
		private readonly modeId: string,
		private readonly typingsStatus: TypingsStatus,
		private readonly fileConfigurationManager: FileConfigurationManager,
		commandManager: CommandManager,
		onCompletionAccepted: (item: vscode.CompletionItem) => void
	) {
		commandManager.register(new ApplyCompletionCodeActionCommand(this.client));
		commandManager.register(new CompositeCommand());
		commandManager.register(new CompletionAcceptedCommand(onCompletionAccepted));
	}

	public async provideCompletionItems(
		document: vscode.TextDocument,
		position: vscode.Position,
		token: vscode.CancellationToken,
		context: vscode.CompletionContext
	): Promise<vscode.CompletionList | null> {
		if (this.typingsStatus.isAcquiringTypings) {
			return Promise.reject<vscode.CompletionList>({
				label: localize(
					{ key: 'acquiringTypingsLabel', comment: ['Typings refers to the *.d.ts typings files that power our IntelliSense. It should not be localized'] },
					'Acquiring typings...'),
				detail: localize(
					{ key: 'acquiringTypingsDetail', comment: ['Typings refers to the *.d.ts typings files that power our IntelliSense. It should not be localized'] },
					'Acquiring typings definitions for IntelliSense.')
			});
		}

		const file = this.client.toPath(document.uri);
		if (!file) {
			return null;
		}

		const line = document.lineAt(position.line);
		const completionConfiguration = CompletionConfiguration.getConfigurationForResource(this.modeId, document.uri);

		if (!this.shouldTrigger(context, line, position)) {
			return null;
		}

		await this.client.interuptGetErr(() => this.fileConfigurationManager.ensureConfigurationForDocument(document, token));

		const args: Proto.CompletionsRequestArgs = {
			...typeConverters.Position.toFileLocationRequestArgs(file, position),
			includeExternalModuleExports: completionConfiguration.autoImportSuggestions,
			includeInsertTextCompletions: true,
			triggerCharacter: this.getTsTriggerCharacter(context),
		};

		let isNewIdentifierLocation = true;
		let isIncomplete = false;
		let entries: ReadonlyArray<Proto.CompletionEntry>;
		let metadata: any | undefined;
		if (this.client.apiVersion.gte(API.v300)) {
			const response = await this.client.interuptGetErr(() => this.client.execute('completionInfo', args, token));
			if (response.type !== 'response' || !response.body) {
				return null;
			}
			isNewIdentifierLocation = response.body.isNewIdentifierLocation;
			isIncomplete = (response as any).metadata && (response as any).metadata.isIncomplete;
			entries = response.body.entries;
			metadata = response.metadata;
		} else {
			const response = await this.client.interuptGetErr(() => this.client.execute('completions', args, token));
			if (response.type !== 'response' || !response.body) {
				return null;
			}

			entries = response.body;
			metadata = response.metadata;
		}

		const isInValidCommitCharacterContext = this.isInValidCommitCharacterContext(document, position);
		const items = entries
			.filter(entry => !shouldExcludeCompletionEntry(entry, completionConfiguration))
			.map(entry => new MyCompletionItem(position, document, line.text, entry, completionConfiguration.useCodeSnippetsOnMethodSuggest, {
				isNewIdentifierLocation,
				isInValidCommitCharacterContext,
				enableCallCompletions: !completionConfiguration.useCodeSnippetsOnMethodSuggest
			}, metadata));
		return new vscode.CompletionList(items, isIncomplete);
	}

	private getTsTriggerCharacter(context: vscode.CompletionContext): Proto.CompletionsTriggerCharacter | undefined {
		// Workaround for https://github.com/Microsoft/TypeScript/issues/27321
		if (context.triggerCharacter === '@'
			&& this.client.apiVersion.gte(API.v310) && this.client.apiVersion.lt(API.v320)
		) {
			return undefined;
		}

		return context.triggerCharacter as Proto.CompletionsTriggerCharacter;
	}

	public async resolveCompletionItem(
		item: vscode.CompletionItem,
		token: vscode.CancellationToken
	): Promise<vscode.CompletionItem | undefined> {
		if (!(item instanceof MyCompletionItem)) {
			return undefined;
		}

		const filepath = this.client.toPath(item.document.uri);
		if (!filepath) {
			return undefined;
		}

		const args: Proto.CompletionDetailsRequestArgs = {
			...typeConverters.Position.toFileLocationRequestArgs(filepath, item.position),
			entryNames: [
				item.tsEntry.source ? { name: item.tsEntry.name, source: item.tsEntry.source } : item.tsEntry.name
			]
		};

		const response = await this.client.execute('completionEntryDetails', args, token);
		if (response.type !== 'response' || !response.body) {
			return item;
		}

		const detail = response.body[0];

		if (!item.detail && detail.displayParts.length) {
			item.detail = Previewer.plain(detail.displayParts);
		}
		item.documentation = this.getDocumentation(detail, item);

		const codeAction = this.getCodeActions(detail, filepath);
		const commands: vscode.Command[] = [{
			command: CompletionAcceptedCommand.ID,
			title: '',
			arguments: [item]
		}];
		if (codeAction.command) {
			commands.push(codeAction.command);
		}
		item.additionalTextEdits = codeAction.additionalTextEdits;

		if (detail && item.useCodeSnippet) {
			const shouldCompleteFunction = await this.isValidFunctionCompletionContext(filepath, item.position, token);
			if (shouldCompleteFunction) {
				item.insertText = this.snippetForFunctionCall(item, detail);
				commands.push({ title: 'triggerParameterHints', command: 'editor.action.triggerParameterHints' });
			}
		}

		if (commands.length) {
			if (commands.length === 1) {
				item.command = commands[0];
			} else {
				item.command = {
					command: CompositeCommand.ID,
					title: '',
					arguments: commands
				};
			}
		}

		return item;
	}

	private getCodeActions(
		detail: Proto.CompletionEntryDetails,
		filepath: string
	): { command?: vscode.Command, additionalTextEdits?: vscode.TextEdit[] } {
		if (!detail.codeActions || !detail.codeActions.length) {
			return {};
		}

		// Try to extract out the additionalTextEdits for the current file.
		// Also check if we still have to apply other workspace edits and commands
		// using a vscode command
		const additionalTextEdits: vscode.TextEdit[] = [];
		let hasReaminingCommandsOrEdits = false;
		for (const tsAction of detail.codeActions) {
			if (tsAction.commands) {
				hasReaminingCommandsOrEdits = true;
			}

			// Apply all edits in the current file using `additionalTextEdits`
			if (tsAction.changes) {
				for (const change of tsAction.changes) {
					if (change.fileName === filepath) {
						additionalTextEdits.push(...change.textChanges.map(typeConverters.TextEdit.fromCodeEdit));
					} else {
						hasReaminingCommandsOrEdits = true;
					}
				}
			}
		}

		let command: vscode.Command | undefined = undefined;
		if (hasReaminingCommandsOrEdits) {
			// Create command that applies all edits not in the current file.
			command = {
				title: '',
				command: ApplyCompletionCodeActionCommand.ID,
				arguments: [filepath, detail.codeActions.map((x): Proto.CodeAction => ({
					commands: x.commands,
					description: x.description,
					changes: x.changes.filter(x => x.fileName !== filepath)
				}))]
			};
		}

		return {
			command,
			additionalTextEdits: additionalTextEdits.length ? additionalTextEdits : undefined
		};
	}

	private isInValidCommitCharacterContext(
		document: vscode.TextDocument,
		position: vscode.Position
	): boolean {
		if (this.client.apiVersion.lt(API.v320)) {
			// Workaround for https://github.com/Microsoft/TypeScript/issues/27742
			// Only enable dot completions when previous character not a dot preceeded by whitespace.
			// Prevents incorrectly completing while typing spread operators.
			if (position.character > 1) {
				const preText = document.getText(new vscode.Range(
					position.line, 0,
					position.line, position.character));
				return preText.match(/(\s|^)\.$/ig) === null;
			}
		}

		return true;
	}

	private shouldTrigger(
		context: vscode.CompletionContext,
		line: vscode.TextLine,
		position: vscode.Position
	): boolean {
		if (context.triggerCharacter && this.client.apiVersion.lt(API.v290)) {
			if ((context.triggerCharacter === '"' || context.triggerCharacter === '\'')) {
				// make sure we are in something that looks like the start of an import
				const pre = line.text.slice(0, position.character);
				if (!pre.match(/\b(from|import)\s*["']$/) && !pre.match(/\b(import|require)\(['"]$/)) {
					return false;
				}
			}

			if (context.triggerCharacter === '/') {
				// make sure we are in something that looks like an import path
				const pre = line.text.slice(0, position.character);
				if (!pre.match(/\b(from|import)\s*["'][^'"]*$/) && !pre.match(/\b(import|require)\(['"][^'"]*$/)) {
					return false;
				}
			}

			if (context.triggerCharacter === '@') {
				// make sure we are in something that looks like the start of a jsdoc comment
				const pre = line.text.slice(0, position.character);
				if (!pre.match(/^\s*\*[ ]?@/) && !pre.match(/\/\*\*+[ ]?@/)) {
					return false;
				}
			}

			if (context.triggerCharacter === '<') {
				return false;
			}
		}

		return true;
	}

	private getDocumentation(
		detail: Proto.CompletionEntryDetails,
		item: MyCompletionItem
	): vscode.MarkdownString | undefined {
		const documentation = new vscode.MarkdownString();
		if (detail.source) {
			const importPath = `'${Previewer.plain(detail.source)}'`;
			const autoImportLabel = localize('autoImportLabel', 'Auto import from {0}', importPath);
			item.detail = `${autoImportLabel}\n${item.detail}`;
		}
		Previewer.addMarkdownDocumentation(documentation, detail.documentation, detail.tags);

		return documentation.value.length ? documentation : undefined;
	}

	private async isValidFunctionCompletionContext(
		filepath: string,
		position: vscode.Position,
		token: vscode.CancellationToken
	): Promise<boolean> {
		// Workaround for https://github.com/Microsoft/TypeScript/issues/12677
		// Don't complete function calls inside of destructive assigments or imports
		try {
			const args: Proto.FileLocationRequestArgs = typeConverters.Position.toFileLocationRequestArgs(filepath, position);
			const response = await this.client.execute('quickinfo', args, token);
			if (response.type !== 'response') {
				return true;
			}

			const { body } = response;
			switch (body && body.kind) {
				case 'var':
				case 'let':
				case 'const':
				case 'alias':
					return false;
				default:
					return true;
			}
		} catch (e) {
			return true;
		}
	}

	private snippetForFunctionCall(
		item: vscode.CompletionItem,
		detail: Proto.CompletionEntryDetails
	): vscode.SnippetString {
		let hasOptionalParameters = false;
		let hasAddedParameters = false;

		const snippet = new vscode.SnippetString();
		const methodName = detail.displayParts.find(part => part.kind === 'methodName');
		if (item.insertText) {
			if (typeof item.insertText === 'string') {
				snippet.appendText(item.insertText);
			} else {
				return item.insertText;
			}
		} else {
			snippet.appendText((methodName && methodName.text) || item.label);
		}
		snippet.appendText('(');

		let parenCount = 0;
		let i = 0;
		for (; i < detail.displayParts.length; ++i) {
			const part = detail.displayParts[i];
			// Only take top level paren names
			if (part.kind === 'parameterName' && parenCount === 1) {
				const next = detail.displayParts[i + 1];
				// Skip optional parameters
				const nameIsFollowedByOptionalIndicator = next && next.text === '?';
				if (!nameIsFollowedByOptionalIndicator) {
					if (hasAddedParameters) {
						snippet.appendText(', ');
					}
					hasAddedParameters = true;
					snippet.appendPlaceholder(part.text);
				}
				hasOptionalParameters = hasOptionalParameters || nameIsFollowedByOptionalIndicator;
			} else if (part.kind === 'punctuation') {
				if (part.text === '(') {
					++parenCount;
				} else if (part.text === ')') {
					--parenCount;
				} else if (part.text === '...' && parenCount === 1) {
					// Found rest parmeter. Do not fill in any further arguments
					hasOptionalParameters = true;
					break;
				}
			}
		}
		if (hasOptionalParameters) {
			snippet.appendTabstop();
		}
		snippet.appendText(')');
		snippet.appendTabstop(0);
		return snippet;
	}
}

function shouldExcludeCompletionEntry(
	element: Proto.CompletionEntry,
	completionConfiguration: CompletionConfiguration
) {
	return (
		(!completionConfiguration.nameSuggestions && element.kind === PConst.Kind.warning)
		|| (!completionConfiguration.pathSuggestions &&
			(element.kind === PConst.Kind.directory || element.kind === PConst.Kind.script || element.kind === PConst.Kind.externalModuleName))
		|| (!completionConfiguration.autoImportSuggestions && element.hasAction)
	);
}

export function register(
	selector: vscode.DocumentSelector,
	modeId: string,
	client: ITypeScriptServiceClient,
	typingsStatus: TypingsStatus,
	fileConfigurationManager: FileConfigurationManager,
	commandManager: CommandManager,
	onCompletionAccepted: (item: vscode.CompletionItem) => void
) {
	return new ConfigurationDependentRegistration(modeId, 'suggest.enabled', () =>
		vscode.languages.registerCompletionItemProvider(selector,
			new TypeScriptCompletionItemProvider(client, modeId, typingsStatus, fileConfigurationManager, commandManager, onCompletionAccepted),
			...TypeScriptCompletionItemProvider.triggerCharacters));
}
