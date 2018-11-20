/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

/* --------------------------------------------------------------------------------------------
 * Includes code from typescript-sublime-plugin project, obtained from
 * https://github.com/Microsoft/TypeScript-Sublime-Plugin/blob/master/TypeScript%20Indent.tmPreferences
 * ------------------------------------------------------------------------------------------ */

import * as vscode from 'vscode';
import { Disposable } from '../utils/dispose';
import * as languageModeIds from '../utils/languageModeIds';

const jsTsLanguageConfiguration: vscode.LanguageConfiguration = {
	indentationRules: {
		decreaseIndentPattern: /^((?!.*?\/\*).*\*\/)?\s*[\}\]].*$/,
		increaseIndentPattern: /^((?!\/\/).)*(\{[^}"'`]*|\([^)"'`]*|\[[^\]"'`]*)$/
	},
	wordPattern: /(-?\d*\.\d\w*)|([^\`\~\!\@\#\%\^\&\*\(\)\-\=\+\[\{\]\}\\\|\;\:\'\"\,\.\<\>\/\?\s]+)/g,
	onEnterRules: [
		{
			// e.g. /** | */
			beforeText: /^\s*\/\*\*(?!\/)([^\*]|\*(?!\/))*$/,
			afterText: /^\s*\*\/$/,
			action: { indentAction: vscode.IndentAction.IndentOutdent, appendText: ' * ' },
		}, {
			// e.g. /** ...|
			beforeText: /^\s*\/\*\*(?!\/)([^\*]|\*(?!\/))*$/,
			action: { indentAction: vscode.IndentAction.None, appendText: ' * ' },
		}, {
			// e.g.  * ...|
			beforeText: /^(\t|[ ])*[ ]\*([ ]([^\*]|\*(?!\/))*)?$/,
			oneLineAboveText: /^(\s*(\/\*\*|\*)).*/,
			action: { indentAction: vscode.IndentAction.None, appendText: '* ' },
		}, {
			// e.g.  */|
			beforeText: /^(\t|[ ])*[ ]\*\/\s*$/,
			action: { indentAction: vscode.IndentAction.None, removeText: 1 },
		},
		{
			// e.g.  *-----*/|
			beforeText: /^(\t|[ ])*[ ]\*[^/]*\*\/\s*$/,
			action: { indentAction: vscode.IndentAction.None, removeText: 1 },
		}
	]
};

const EMPTY_ELEMENTS: string[] = ['area', 'base', 'br', 'col', 'embed', 'hr', 'img', 'input', 'keygen', 'link', 'menuitem', 'meta', 'param', 'source', 'track', 'wbr'];

const jsxTagsLanguageConfiguration: vscode.LanguageConfiguration = {
	wordPattern: /(-?\d*\.\d\w*)|([^\`\~\!\@\$\^\&\*\(\)\=\+\[\{\]\}\\\|\;\:\'\"\,\.\<\>\/\s]+)/g,
	onEnterRules: [
		{
			beforeText: new RegExp(`<(?!(?:${EMPTY_ELEMENTS.join('|')}))([_:\\w][_:\\w-.\\d]*)([^/>]*(?!/)>)[^<]*$`, 'i'),
			afterText: /^<\/([_:\w][_:\w-.\d]*)\s*>$/i,
			action: { indentAction: vscode.IndentAction.IndentOutdent }
		},
		{
			beforeText: new RegExp(`<(?!(?:${EMPTY_ELEMENTS.join('|')}))(\\w[\\w\\d]*)([^/>]*(?!/)>)[^<]*$`, 'i'),
			action: { indentAction: vscode.IndentAction.Indent }
		}
	],
};

export class LanguageConfigurationManager extends Disposable {

	constructor() {
		super();
		const standardLanguages = [
			languageModeIds.javascript,
			languageModeIds.javascriptreact,
			languageModeIds.typescript,
			languageModeIds.typescriptreact,
		];
		for (const language of standardLanguages) {
			this.registerConfiguration(language, jsTsLanguageConfiguration);
		}

		this.registerConfiguration(languageModeIds.jsxTags, jsxTagsLanguageConfiguration);
	}

	private registerConfiguration(language: string, config: vscode.LanguageConfiguration) {
		this._register(vscode.languages.setLanguageConfiguration(language, config));
	}
}
