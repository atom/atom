/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import * as vscode from 'vscode';
import * as nls from 'vscode-nls';
import * as Proto from '../protocol';
import { ITypeScriptServiceClient } from '../typescriptService';
import API from '../utils/api';
import { Command, CommandManager } from '../utils/commandManager';
import { VersionDependentRegistration } from '../utils/dependentRegistration';
import * as typeconverts from '../utils/typeConverters';
import FileConfigurationManager from './fileConfigurationManager';
import TelemetryReporter from '../utils/telemetry';
import { nulToken } from '../utils/cancellation';

const localize = nls.loadMessageBundle();


class OrganizeImportsCommand implements Command {
	public static readonly Id = '_typescript.organizeImports';

	public readonly id = OrganizeImportsCommand.Id;

	constructor(
		private readonly client: ITypeScriptServiceClient,
		private readonly telemetryReporter: TelemetryReporter,
	) { }

	public async execute(file: string): Promise<boolean> {
		/* __GDPR__
			"organizeImports.execute" : {
				"${include}": [
					"${TypeScriptCommonProperties}"
				]
			}
		*/
		this.telemetryReporter.logTelemetry('organizeImports.execute', {});

		const args: Proto.OrganizeImportsRequestArgs = {
			scope: {
				type: 'file',
				args: {
					file
				}
			}
		};
		const response = await this.client.execute('organizeImports', args, nulToken);
		if (response.type !== 'response' || !response.body) {
			return false;
		}

		const edits = typeconverts.WorkspaceEdit.fromFileCodeEdits(this.client, response.body);
		return vscode.workspace.applyEdit(edits);
	}
}

export class OrganizeImportsCodeActionProvider implements vscode.CodeActionProvider {
	public constructor(
		private readonly client: ITypeScriptServiceClient,
		commandManager: CommandManager,
		private readonly fileConfigManager: FileConfigurationManager,
		telemetryReporter: TelemetryReporter,

	) {
		commandManager.register(new OrganizeImportsCommand(client, telemetryReporter));
	}

	public readonly metadata: vscode.CodeActionProviderMetadata = {
		providedCodeActionKinds: [vscode.CodeActionKind.SourceOrganizeImports]
	};

	public provideCodeActions(
		document: vscode.TextDocument,
		_range: vscode.Range,
		context: vscode.CodeActionContext,
		token: vscode.CancellationToken
	): vscode.CodeAction[] {
		const file = this.client.toPath(document.uri);
		if (!file) {
			return [];
		}

		if (!context.only || !context.only.contains(vscode.CodeActionKind.SourceOrganizeImports)) {
			return [];
		}

		this.fileConfigManager.ensureConfigurationForDocument(document, token);

		const action = new vscode.CodeAction(
			localize('oraganizeImportsAction.title', "Organize Imports"),
			vscode.CodeActionKind.SourceOrganizeImports);
		action.command = { title: '', command: OrganizeImportsCommand.Id, arguments: [file] };
		return [action];
	}
}

export function register(
	selector: vscode.DocumentSelector,
	client: ITypeScriptServiceClient,
	commandManager: CommandManager,
	fileConfigurationManager: FileConfigurationManager,
	telemetryReporter: TelemetryReporter,
) {
	return new VersionDependentRegistration(client, API.v280, () => {
		const organizeImportsProvider = new OrganizeImportsCodeActionProvider(client, commandManager, fileConfigurationManager, telemetryReporter);
		return vscode.languages.registerCodeActionsProvider(selector,
			organizeImportsProvider,
			organizeImportsProvider.metadata);
	});
}
