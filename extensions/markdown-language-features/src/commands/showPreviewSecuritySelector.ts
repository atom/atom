/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import * as vscode from 'vscode';
import { Command } from '../commandManager';
import { PreviewSecuritySelector } from '../security';
import { isMarkdownFile } from '../util/file';
import { MarkdownPreviewManager } from '../features/previewManager';

export class ShowPreviewSecuritySelectorCommand implements Command {
	public readonly id = 'markdown.showPreviewSecuritySelector';

	public constructor(
		private readonly previewSecuritySelector: PreviewSecuritySelector,
		private readonly previewManager: MarkdownPreviewManager
	) { }

	public execute(resource: string | undefined) {
		if (this.previewManager.activePreviewResource) {
			this.previewSecuritySelector.showSecutitySelectorForResource(this.previewManager.activePreviewResource);
		} else if (resource) {
			const source = vscode.Uri.parse(resource);
			this.previewSecuritySelector.showSecutitySelectorForResource(source.query ? vscode.Uri.parse(source.query) : source);
		} else if (vscode.window.activeTextEditor && isMarkdownFile(vscode.window.activeTextEditor.document)) {
			this.previewSecuritySelector.showSecutitySelectorForResource(vscode.window.activeTextEditor.document.uri);
		}
	}
}