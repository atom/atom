/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import * as vscode from 'vscode';
import { ITypeScriptServiceClient } from '../typescriptService';
import API from '../utils/api';
import * as typeConverters from '../utils/typeConverters';


class TypeScriptReferenceSupport implements vscode.ReferenceProvider {
	public constructor(
		private readonly client: ITypeScriptServiceClient) { }

	public async provideReferences(
		document: vscode.TextDocument,
		position: vscode.Position,
		options: vscode.ReferenceContext,
		token: vscode.CancellationToken
	): Promise<vscode.Location[]> {
		const filepath = this.client.toPath(document.uri);
		if (!filepath) {
			return [];
		}

		const args = typeConverters.Position.toFileLocationRequestArgs(filepath, position);
		const response = await this.client.execute('references', args, token);
		if (response.type !== 'response' || !response.body) {
			return [];
		}

		const result: vscode.Location[] = [];
		const has203Features = this.client.apiVersion.gte(API.v203);
		for (const ref of response.body.refs) {
			if (!options.includeDeclaration && has203Features && ref.isDefinition) {
				continue;
			}
			const url = this.client.toResource(ref.file);
			const location = typeConverters.Location.fromTextSpan(url, ref);
			result.push(location);
		}
		return result;
	}
}

export function register(
	selector: vscode.DocumentSelector,
	client: ITypeScriptServiceClient
) {
	return vscode.languages.registerReferenceProvider(selector,
		new TypeScriptReferenceSupport(client));
}