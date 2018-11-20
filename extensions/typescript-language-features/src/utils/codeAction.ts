/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import * as vscode from 'vscode';
import * as Proto from '../protocol';
import { ITypeScriptServiceClient } from '../typescriptService';
import * as typeConverters from './typeConverters';

export function getEditForCodeAction(
	client: ITypeScriptServiceClient,
	action: Proto.CodeAction
): vscode.WorkspaceEdit | undefined {
	return action.changes && action.changes.length
		? typeConverters.WorkspaceEdit.fromFileCodeEdits(client, action.changes)
		: undefined;
}

export async function applyCodeAction(
	client: ITypeScriptServiceClient,
	action: Proto.CodeAction,
	token: vscode.CancellationToken
): Promise<boolean> {
	const workspaceEdit = getEditForCodeAction(client, action);
	if (workspaceEdit) {
		if (!(await vscode.workspace.applyEdit(workspaceEdit))) {
			return false;
		}
	}
	return applyCodeActionCommands(client, action.commands, token);
}

export async function applyCodeActionCommands(
	client: ITypeScriptServiceClient,
	commands: ReadonlyArray<{}> | undefined,
	token: vscode.CancellationToken,
): Promise<boolean> {
	if (commands && commands.length) {
		for (const command of commands) {
			await client.execute('applyCodeActionCommand', { command }, token);
		}
	}
	return true;
}