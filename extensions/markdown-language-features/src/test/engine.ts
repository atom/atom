/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import * as vscode from 'vscode';
import { MarkdownEngine } from '../markdownEngine';
import { MarkdownContributions } from '../markdownExtensions';
import { githubSlugifier } from '../slugify';

const emptyContributions = new class implements MarkdownContributions {
	readonly extensionPath = '';
	readonly previewScripts: vscode.Uri[] = [];
	readonly previewStyles: vscode.Uri[] = [];
	readonly previewResourceRoots: vscode.Uri[] = [];
	readonly markdownItPlugins: Promise<(md: any) => any>[] = [];
};

export function createNewMarkdownEngine(): MarkdownEngine {
	return new MarkdownEngine(emptyContributions, githubSlugifier);
}
