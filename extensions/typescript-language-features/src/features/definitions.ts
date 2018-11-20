/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import * as vscode from 'vscode';
import { ITypeScriptServiceClient } from '../typescriptService';
import API from '../utils/api';
import * as typeConverters from '../utils/typeConverters';
import DefinitionProviderBase from './definitionProviderBase';

export default class TypeScriptDefinitionProvider extends DefinitionProviderBase implements vscode.DefinitionProvider {
	constructor(
		client: ITypeScriptServiceClient
	) {
		super(client);
	}

	public async provideDefinition(
		document: vscode.TextDocument,
		position: vscode.Position,
		token: vscode.CancellationToken
	): Promise<vscode.DefinitionLink[] | vscode.Definition | undefined> {
		if (this.client.apiVersion.gte(API.v270)) {
			const filepath = this.client.toPath(document.uri);
			if (!filepath) {
				return undefined;
			}

			const args = typeConverters.Position.toFileLocationRequestArgs(filepath, position);
			const response = await this.client.execute('definitionAndBoundSpan', args, token);
			if (response.type !== 'response' || !response.body) {
				return undefined;
			}

			const span = response.body.textSpan ? typeConverters.Range.fromTextSpan(response.body.textSpan) : undefined;
			return response.body.definitions
				.map(location => {
					const target = typeConverters.Location.fromTextSpan(this.client.toResource(location.file), location);
					return {
						originSelectionRange: span,
						targetRange: target.range,
						targetUri: target.uri,
					} as vscode.DefinitionLink;
				});
		}

		return this.getSymbolLocations('definition', document, position, token);
	}
}

export function register(
	selector: vscode.DocumentSelector,
	client: ITypeScriptServiceClient,
) {
	return vscode.languages.registerDefinitionProvider(selector,
		new TypeScriptDefinitionProvider(client));
}
