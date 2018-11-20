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
import { ConfigurationDependentRegistration, VersionDependentRegistration } from '../utils/dependentRegistration';
import { CachedNavTreeResponse, ReferencesCodeLens, TypeScriptBaseCodeLensProvider } from './baseCodeLensProvider';
const localize = nls.loadMessageBundle();

export default class TypeScriptImplementationsCodeLensProvider extends TypeScriptBaseCodeLensProvider {

	public async resolveCodeLens(
		inputCodeLens: vscode.CodeLens,
		_token: vscode.CancellationToken,
	): Promise<vscode.CodeLens> {
		const codeLens = inputCodeLens as ReferencesCodeLens;
		try {
			const locations: vscode.Location[] | undefined = await vscode.commands.executeCommand<vscode.Location[]>('vscode.executeImplementationProvider', codeLens.document, codeLens.range.start);
			if (locations) {
				codeLens.command = this.getCommand(locations, codeLens);
				return codeLens;
			}
		} catch {
			// noop
		}

		codeLens.command = {
			title: localize('implementationsErrorLabel', 'Could not determine implementations'),
			command: ''
		};
		return codeLens;
	}

	private getCommand(locations: vscode.Location[], codeLens: ReferencesCodeLens): vscode.Command | undefined {
		return {
			title: this.getTitle(locations),
			command: locations.length ? 'editor.action.showReferences' : '',
			arguments: [codeLens.document, codeLens.range.start, locations]
		};
	}

	private getTitle(locations: vscode.Location[]): string {
		return locations.length === 1
			? localize('oneImplementationLabel', '1 implementation')
			: localize('manyImplementationLabel', '{0} implementations', locations.length);
	}

	protected extractSymbol(
		document: vscode.TextDocument,
		item: Proto.NavigationTree,
		_parent: Proto.NavigationTree | null
	): vscode.Range | null {
		switch (item.kind) {
			case PConst.Kind.interface:
				return super.getSymbolRange(document, item);

			case PConst.Kind.class:
			case PConst.Kind.memberFunction:
			case PConst.Kind.memberVariable:
			case PConst.Kind.memberGetAccessor:
			case PConst.Kind.memberSetAccessor:
				if (item.kindModifiers.match(/\babstract\b/g)) {
					return super.getSymbolRange(document, item);
				}
				break;
		}
		return null;
	}
}

export function register(
	selector: vscode.DocumentSelector,
	modeId: string,
	client: ITypeScriptServiceClient,
	cachedResponse: CachedNavTreeResponse,
) {
	return new VersionDependentRegistration(client, API.v220, () =>
		new ConfigurationDependentRegistration(modeId, 'implementationsCodeLens.enabled', () => {
			return vscode.languages.registerCodeLensProvider(selector,
				new TypeScriptImplementationsCodeLensProvider(client, cachedResponse));
		}));
}
