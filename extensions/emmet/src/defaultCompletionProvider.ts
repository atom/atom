/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import * as vscode from 'vscode';
import { Node, Stylesheet } from 'EmmetNode';
import { isValidLocationForEmmetAbbreviation } from './abbreviationActions';
import { getEmmetHelper, getMappingForIncludedLanguages, parsePartialStylesheet, getEmmetConfiguration, getEmmetMode, isStyleSheet, parseDocument, getEmbeddedCssNodeIfAny, isStyleAttribute, getNode } from './util';

export class DefaultCompletionItemProvider implements vscode.CompletionItemProvider {

	private lastCompletionType: string | undefined;

	public provideCompletionItems(document: vscode.TextDocument, position: vscode.Position, _: vscode.CancellationToken, context: vscode.CompletionContext): Thenable<vscode.CompletionList | undefined> | undefined {
		const completionResult = this.provideCompletionItemsInternal(document, position, context);
		if (!completionResult) {
			this.lastCompletionType = undefined;
			return;
		}

		return completionResult.then(completionList => {
			if (!completionList || !completionList.items.length) {
				this.lastCompletionType = undefined;
				return completionList;
			}
			const item = completionList.items[0];
			const expandedText = item.documentation ? item.documentation.toString() : '';

			if (expandedText.startsWith('<')) {
				this.lastCompletionType = 'html';
			} else if (expandedText.indexOf(':') > 0 && expandedText.endsWith(';')) {
				this.lastCompletionType = 'css';
			} else {
				this.lastCompletionType = undefined;
			}
			return completionList;
		});
	}

	private provideCompletionItemsInternal(document: vscode.TextDocument, position: vscode.Position, context: vscode.CompletionContext): Thenable<vscode.CompletionList | undefined> | undefined {
		const emmetConfig = vscode.workspace.getConfiguration('emmet');
		const excludedLanguages = emmetConfig['excludeLanguages'] ? emmetConfig['excludeLanguages'] : [];
		if (excludedLanguages.indexOf(document.languageId) > -1) {
			return;
		}

		const mappedLanguages = getMappingForIncludedLanguages();
		const isSyntaxMapped = mappedLanguages[document.languageId] ? true : false;
		let syntax = getEmmetMode((isSyntaxMapped ? mappedLanguages[document.languageId] : document.languageId), excludedLanguages);

		if (!syntax
			|| emmetConfig['showExpandedAbbreviation'] === 'never'
			|| ((isSyntaxMapped || syntax === 'jsx') && emmetConfig['showExpandedAbbreviation'] !== 'always')) {
			return;
		}

		const helper = getEmmetHelper();
		let validateLocation = syntax === 'html' || syntax === 'jsx' || syntax === 'xml';
		let rootNode: Node | undefined = undefined;
		let currentNode: Node | null = null;

		if (document.languageId === 'html') {
			if (context.triggerKind === vscode.CompletionTriggerKind.TriggerForIncompleteCompletions) {
				switch (this.lastCompletionType) {
					case 'html':
						validateLocation = false;
						break;
					case 'css':
						validateLocation = false;
						syntax = 'css';
						break;
					default:
						break;
				}

			}
			if (validateLocation) {
				rootNode = parseDocument(document, false);
				currentNode = getNode(rootNode, position, true);
				if (isStyleAttribute(currentNode, position)) {
					syntax = 'css';
					validateLocation = false;
				} else {
					const embeddedCssNode = getEmbeddedCssNodeIfAny(document, currentNode, position);
					if (embeddedCssNode) {
						currentNode = getNode(embeddedCssNode, position, true);
						syntax = 'css';
					}
				}
			}

		}

		const extractAbbreviationResults = helper.extractAbbreviation(document, position, !isStyleSheet(syntax));
		if (!extractAbbreviationResults || !helper.isAbbreviationValid(syntax, extractAbbreviationResults.abbreviation)) {
			return;
		}

		if (isStyleSheet(document.languageId) && context.triggerKind !== vscode.CompletionTriggerKind.TriggerForIncompleteCompletions) {
			validateLocation = true;
			let usePartialParsing = vscode.workspace.getConfiguration('emmet')['optimizeStylesheetParsing'] === true;
			rootNode = usePartialParsing && document.lineCount > 1000 ? parsePartialStylesheet(document, position) : <Stylesheet>parseDocument(document, false);
			if (!rootNode) {
				return;
			}
			currentNode = getNode(rootNode, position, true);
		}



		if (validateLocation && !isValidLocationForEmmetAbbreviation(document, rootNode, currentNode, syntax, position, extractAbbreviationResults.abbreviationRange)) {
			return;
		}

		let noiseCheckPromise: Thenable<any> = Promise.resolve();

		// Fix for https://github.com/Microsoft/vscode/issues/32647
		// Check for document symbols in js/ts/jsx/tsx and avoid triggering emmet for abbreviations of the form symbolName.sometext
		// Presence of > or * or + in the abbreviation denotes valid abbreviation that should trigger emmet
		if (!isStyleSheet(syntax) && (document.languageId === 'javascript' || document.languageId === 'javascriptreact' || document.languageId === 'typescript' || document.languageId === 'typescriptreact')) {
			let abbreviation: string = extractAbbreviationResults.abbreviation;
			if (abbreviation.startsWith('this.')) {
				noiseCheckPromise = Promise.resolve(true);
			} else {
				noiseCheckPromise = vscode.commands.executeCommand<vscode.SymbolInformation[]>('vscode.executeDocumentSymbolProvider', document.uri).then((symbols: vscode.SymbolInformation[] | undefined) => {
					return symbols && symbols.find(x => abbreviation === x.name || (abbreviation.startsWith(x.name + '.') && !/>|\*|\+/.test(abbreviation)));
				});
			}
		}

		return noiseCheckPromise.then((noise): vscode.CompletionList | undefined => {
			if (noise) {
				return;
			}

			let result = helper.doComplete(document, position, syntax, getEmmetConfiguration(syntax!));
			let newItems: vscode.CompletionItem[] = [];
			if (result && result.items) {
				result.items.forEach((item: any) => {
					let newItem = new vscode.CompletionItem(item.label);
					newItem.documentation = item.documentation;
					newItem.detail = item.detail;
					newItem.insertText = new vscode.SnippetString(item.textEdit.newText);
					let oldrange = item.textEdit.range;
					newItem.range = new vscode.Range(oldrange.start.line, oldrange.start.character, oldrange.end.line, oldrange.end.character);

					newItem.filterText = item.filterText;
					newItem.sortText = item.sortText;

					if (emmetConfig['showSuggestionsAsSnippets'] === true) {
						newItem.kind = vscode.CompletionItemKind.Snippet;
					}
					newItems.push(newItem);
				});
			}

			return new vscode.CompletionList(newItems, true);
		});
	}
}