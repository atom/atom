/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import * as vscode from 'vscode';
import * as Proto from '../protocol';
import { ITypeScriptServiceClient } from '../typescriptService';
import API from '../utils/api';
import { VersionDependentRegistration } from '../utils/dependentRegistration';
import * as typeConverters from '../utils/typeConverters';

class TypeScriptFoldingProvider implements vscode.FoldingRangeProvider {
	public constructor(
		private readonly client: ITypeScriptServiceClient
	) { }

	async provideFoldingRanges(
		document: vscode.TextDocument,
		_context: vscode.FoldingContext,
		token: vscode.CancellationToken
	): Promise<vscode.FoldingRange[] | undefined> {
		const file = this.client.toPath(document.uri);
		if (!file) {
			return;
		}

		const args: Proto.FileRequestArgs = { file };
		const response = await this.client.execute('getOutliningSpans', args, token);
		if (response.type !== 'response' || !response.body) {
			return;
		}

		return response.body
			.map(span => this.convertOutliningSpan(span, document))
			.filter(foldingRange => !!foldingRange) as vscode.FoldingRange[];
	}

	private convertOutliningSpan(
		span: Proto.OutliningSpan,
		document: vscode.TextDocument
	): vscode.FoldingRange | undefined {
		const range = typeConverters.Range.fromTextSpan(span.textSpan);
		const kind = TypeScriptFoldingProvider.getFoldingRangeKind(span);

		// Workaround for #49904
		if (span.kind === 'comment') {
			const line = document.lineAt(range.start.line).text;
			if (line.match(/\/\/\s*#endregion/gi)) {
				return undefined;
			}
		}

		const start = range.start.line;
		// workaround for #47240
		const end = (range.end.character > 0 && document.getText(new vscode.Range(range.end.translate(0, -1), range.end)) === '}')
			? Math.max(range.end.line - 1, range.start.line)
			: range.end.line;

		return new vscode.FoldingRange(start, end, kind);
	}

	private static getFoldingRangeKind(span: Proto.OutliningSpan): vscode.FoldingRangeKind | undefined {
		switch (span.kind) {
			case 'comment': return vscode.FoldingRangeKind.Comment;
			case 'region': return vscode.FoldingRangeKind.Region;
			case 'imports': return vscode.FoldingRangeKind.Imports;
			case 'code':
			default: return undefined;
		}
	}
}

export function register(
	selector: vscode.DocumentSelector,
	client: ITypeScriptServiceClient,
): vscode.Disposable {
	return new VersionDependentRegistration(client, API.v280, () => {
		return vscode.languages.registerFoldingRangeProvider(selector,
			new TypeScriptFoldingProvider(client));
	});
}