/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import * as path from 'path';
import * as vscode from 'vscode';
import { OpenDocumentLinkCommand } from '../commands/openDocumentLink';
import { getUriForLinkWithKnownExternalScheme } from '../util/links';

function normalizeLink(
	document: vscode.TextDocument,
	link: string,
	base: string
): vscode.Uri {
	const externalSchemeUri = getUriForLinkWithKnownExternalScheme(link);
	if (externalSchemeUri) {
		return externalSchemeUri;
	}

	// Assume it must be an relative or absolute file path
	// Use a fake scheme to avoid parse warnings
	const tempUri = vscode.Uri.parse(`vscode-resource:${link}`);

	let resourcePath = tempUri.path;
	if (!tempUri.path && document.uri.scheme === 'file') {
		resourcePath = document.uri.path;
	} else if (tempUri.path[0] === '/') {
		const root = vscode.workspace.getWorkspaceFolder(document.uri);
		if (root) {
			resourcePath = path.join(root.uri.fsPath, tempUri.path);
		}
	} else {
		resourcePath = base ? path.join(base, tempUri.path) : tempUri.path;
	}

	return OpenDocumentLinkCommand.createCommandUri(resourcePath, tempUri.fragment);
}

function matchAll(
	pattern: RegExp,
	text: string
): Array<RegExpMatchArray> {
	const out: RegExpMatchArray[] = [];
	pattern.lastIndex = 0;
	let match: RegExpMatchArray | null;
	while ((match = pattern.exec(text))) {
		out.push(match);
	}
	return out;
}

export default class LinkProvider implements vscode.DocumentLinkProvider {
	private readonly linkPattern = /(\[[^\]]*\]\(\s*)((([^\s\(\)]|\(\S*?\))+))\s*(".*?")?\)/g;
	private readonly referenceLinkPattern = /(\[([^\]]+)\]\[\s*?)([^\s\]]*?)\]/g;
	private readonly definitionPattern = /^([\t ]*\[([^\]]+)\]:\s*)(\S+)/gm;

	public provideDocumentLinks(
		document: vscode.TextDocument,
		_token: vscode.CancellationToken
	): vscode.DocumentLink[] {
		const base = document.uri.scheme === 'file' ? path.dirname(document.uri.fsPath) : '';
		const text = document.getText();

		return this.providerInlineLinks(text, document, base)
			.concat(this.provideReferenceLinks(text, document, base));
	}

	private providerInlineLinks(
		text: string,
		document: vscode.TextDocument,
		base: string
	): vscode.DocumentLink[] {
		const results: vscode.DocumentLink[] = [];
		for (const match of matchAll(this.linkPattern, text)) {
			const pre = match[1];
			const link = match[2];
			const offset = (match.index || 0) + pre.length;
			const linkStart = document.positionAt(offset);
			const linkEnd = document.positionAt(offset + link.length);
			try {
				results.push(new vscode.DocumentLink(
					new vscode.Range(linkStart, linkEnd),
					normalizeLink(document, link, base)));
			} catch (e) {
				// noop
			}
		}

		return results;
	}

	private provideReferenceLinks(
		text: string,
		document: vscode.TextDocument,
		base: string
	): vscode.DocumentLink[] {
		const results: vscode.DocumentLink[] = [];

		const definitions = this.getDefinitions(text, document);
		for (const match of matchAll(this.referenceLinkPattern, text)) {
			let linkStart: vscode.Position;
			let linkEnd: vscode.Position;
			let reference = match[3];
			if (reference) { // [text][ref]
				const pre = match[1];
				const offset = (match.index || 0) + pre.length;
				linkStart = document.positionAt(offset);
				linkEnd = document.positionAt(offset + reference.length);
			} else if (match[2]) { // [ref][]
				reference = match[2];
				const offset = (match.index || 0) + 1;
				linkStart = document.positionAt(offset);
				linkEnd = document.positionAt(offset + match[2].length);
			} else {
				continue;
			}

			try {
				const link = definitions.get(reference);
				if (link) {
					results.push(new vscode.DocumentLink(
						new vscode.Range(linkStart, linkEnd),
						vscode.Uri.parse(`command:_markdown.moveCursorToPosition?${encodeURIComponent(JSON.stringify([link.linkRange.start.line, link.linkRange.start.character]))}`)));
				}
			} catch (e) {
				// noop
			}
		}

		for (const definition of Array.from(definitions.values())) {
			try {
				results.push(new vscode.DocumentLink(
					definition.linkRange,
					normalizeLink(document, definition.link, base)));
			} catch (e) {
				// noop
			}
		}

		return results;
	}

	private getDefinitions(text: string, document: vscode.TextDocument) {
		const out = new Map<string, { link: string, linkRange: vscode.Range }>();
		for (const match of matchAll(this.definitionPattern, text)) {
			const pre = match[1];
			const reference = match[2];
			const link = match[3].trim();

			const offset = (match.index || 0) + pre.length;
			const linkStart = document.positionAt(offset);
			const linkEnd = document.positionAt(offset + link.length);

			out.set(reference, {
				link: link,
				linkRange: new vscode.Range(linkStart, linkEnd)
			});
		}
		return out;
	}
}
