/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import { Location, getLocation, createScanner, SyntaxKind, ScanError } from 'jsonc-parser';
import { basename } from 'path';
import { BowerJSONContribution } from './bowerJSONContribution';
import { PackageJSONContribution } from './packageJSONContribution';
import { XHRRequest } from 'request-light';

import {
	CompletionItem, CompletionItemProvider, CompletionList, TextDocument, Position, Hover, HoverProvider,
	CancellationToken, Range, MarkedString, DocumentSelector, languages, Disposable
} from 'vscode';

export interface ISuggestionsCollector {
	add(suggestion: CompletionItem): void;
	error(message: string): void;
	log(message: string): void;
	setAsIncomplete(): void;
}

export interface IJSONContribution {
	getDocumentSelector(): DocumentSelector;
	getInfoContribution(fileName: string, location: Location): Thenable<MarkedString[] | null> | null;
	collectPropertySuggestions(fileName: string, location: Location, currentWord: string, addValue: boolean, isLast: boolean, result: ISuggestionsCollector): Thenable<any> | null;
	collectValueSuggestions(fileName: string, location: Location, result: ISuggestionsCollector): Thenable<any> | null;
	collectDefaultSuggestions(fileName: string, result: ISuggestionsCollector): Thenable<any>;
	resolveSuggestion?(item: CompletionItem): Thenable<CompletionItem | null> | null;
}

export function addJSONProviders(xhr: XHRRequest): Disposable {
	const contributions = [new PackageJSONContribution(xhr), new BowerJSONContribution(xhr)];
	const subscriptions: Disposable[] = [];
	contributions.forEach(contribution => {
		const selector = contribution.getDocumentSelector();
		subscriptions.push(languages.registerCompletionItemProvider(selector, new JSONCompletionItemProvider(contribution), '"', ':'));
		subscriptions.push(languages.registerHoverProvider(selector, new JSONHoverProvider(contribution)));
	});
	return Disposable.from(...subscriptions);
}

export class JSONHoverProvider implements HoverProvider {

	constructor(private jsonContribution: IJSONContribution) {
	}

	public provideHover(document: TextDocument, position: Position, _token: CancellationToken): Thenable<Hover> | null {
		const fileName = basename(document.fileName);
		const offset = document.offsetAt(position);
		const location = getLocation(document.getText(), offset);
		if (!location.previousNode) {
			return null;
		}
		const node = location.previousNode;
		if (node && node.offset <= offset && offset <= node.offset + node.length) {
			const promise = this.jsonContribution.getInfoContribution(fileName, location);
			if (promise) {
				return promise.then(htmlContent => {
					const range = new Range(document.positionAt(node.offset), document.positionAt(node.offset + node.length));
					const result: Hover = {
						contents: htmlContent || [],
						range: range
					};
					return result;
				});
			}
		}
		return null;
	}
}

export class JSONCompletionItemProvider implements CompletionItemProvider {

	constructor(private jsonContribution: IJSONContribution) {
	}

	public resolveCompletionItem(item: CompletionItem, _token: CancellationToken): Thenable<CompletionItem | null> {
		if (this.jsonContribution.resolveSuggestion) {
			const resolver = this.jsonContribution.resolveSuggestion(item);
			if (resolver) {
				return resolver;
			}
		}
		return Promise.resolve(item);
	}

	public provideCompletionItems(document: TextDocument, position: Position, _token: CancellationToken): Thenable<CompletionList | null> | null {

		const fileName = basename(document.fileName);

		const currentWord = this.getCurrentWord(document, position);
		let overwriteRange: Range;

		const items: CompletionItem[] = [];
		let isIncomplete = false;

		const offset = document.offsetAt(position);
		const location = getLocation(document.getText(), offset);

		const node = location.previousNode;
		if (node && node.offset <= offset && offset <= node.offset + node.length && (node.type === 'property' || node.type === 'string' || node.type === 'number' || node.type === 'boolean' || node.type === 'null')) {
			overwriteRange = new Range(document.positionAt(node.offset), document.positionAt(node.offset + node.length));
		} else {
			overwriteRange = new Range(document.positionAt(offset - currentWord.length), position);
		}

		const proposed: { [key: string]: boolean } = {};
		const collector: ISuggestionsCollector = {
			add: (suggestion: CompletionItem) => {
				if (!proposed[suggestion.label]) {
					proposed[suggestion.label] = true;
					suggestion.range = overwriteRange;
					items.push(suggestion);
				}
			},
			setAsIncomplete: () => isIncomplete = true,
			error: (message: string) => console.error(message),
			log: (message: string) => console.log(message)
		};

		let collectPromise: Thenable<any> | null = null;

		if (location.isAtPropertyKey) {
			const addValue = !location.previousNode || !location.previousNode.colonOffset;
			const isLast = this.isLast(document, position);
			collectPromise = this.jsonContribution.collectPropertySuggestions(fileName, location, currentWord, addValue, isLast, collector);
		} else {
			if (location.path.length === 0) {
				collectPromise = this.jsonContribution.collectDefaultSuggestions(fileName, collector);
			} else {
				collectPromise = this.jsonContribution.collectValueSuggestions(fileName, location, collector);
			}
		}
		if (collectPromise) {
			return collectPromise.then(() => {
				if (items.length > 0) {
					return new CompletionList(items, isIncomplete);
				}
				return null;
			});
		}
		return null;
	}

	private getCurrentWord(document: TextDocument, position: Position) {
		let i = position.character - 1;
		const text = document.lineAt(position.line).text;
		while (i >= 0 && ' \t\n\r\v":{[,'.indexOf(text.charAt(i)) === -1) {
			i--;
		}
		return text.substring(i + 1, position.character);
	}

	private isLast(document: TextDocument, position: Position): boolean {
		const scanner = createScanner(document.getText(), true);
		scanner.setPosition(document.offsetAt(position));
		let nextToken = scanner.scan();
		if (nextToken === SyntaxKind.StringLiteral && scanner.getTokenError() === ScanError.UnexpectedEndOfString) {
			nextToken = scanner.scan();
		}
		return nextToken === SyntaxKind.CloseBraceToken || nextToken === SyntaxKind.EOF;
	}
}

export const xhrDisabled = () => Promise.reject({ responseText: 'Use of online resources is disabled.' });