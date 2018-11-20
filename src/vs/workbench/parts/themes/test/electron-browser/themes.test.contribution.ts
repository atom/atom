/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import * as paths from 'vs/base/common/paths';
import { URI } from 'vs/base/common/uri';
import { IModeService } from 'vs/editor/common/services/modeService';
import * as pfs from 'vs/base/node/pfs';
import { CommandsRegistry } from 'vs/platform/commands/common/commands';
import { IInstantiationService, ServicesAccessor } from 'vs/platform/instantiation/common/instantiation';
import { IWorkbenchThemeService, IColorTheme } from 'vs/workbench/services/themes/common/workbenchThemeService';
import { IEditorService } from 'vs/workbench/services/editor/common/editorService';
import { toResource } from 'vs/workbench/common/editor';
import { ITextMateService } from 'vs/workbench/services/textMate/electron-browser/textMateService';
import { IGrammar, StackElement } from 'vscode-textmate';
import { TokenizationRegistry, TokenMetadata } from 'vs/editor/common/modes';
import { ThemeRule, findMatchingThemeRule } from 'vs/workbench/services/textMate/electron-browser/TMHelper';
import { Color } from 'vs/base/common/color';

interface IToken {
	c: string;
	t: string;
	r: { [themeName: string]: string; };
}

interface IThemedToken {
	text: string;
	color: Color;
}

interface IThemesResult {
	[themeName: string]: {
		document: ThemeDocument;
		tokens: IThemedToken[];
	};
}

class ThemeDocument {
	private readonly _theme: IColorTheme;
	private readonly _cache: { [scopes: string]: ThemeRule; };
	private readonly _defaultColor: string;

	constructor(theme: IColorTheme) {
		this._theme = theme;
		this._cache = Object.create(null);
		this._defaultColor = '#000000';
		for (let i = 0, len = this._theme.tokenColors.length; i < len; i++) {
			let rule = this._theme.tokenColors[i];
			if (!rule.scope) {
				this._defaultColor = rule.settings.foreground;
			}
		}
	}

	private _generateExplanation(selector: string, color: Color): string {
		return `${selector}: ${Color.Format.CSS.formatHexA(color, true).toUpperCase()}`;
	}

	public explainTokenColor(scopes: string, color: Color): string {

		let matchingRule = this._findMatchingThemeRule(scopes);
		if (!matchingRule) {
			let expected = Color.fromHex(this._defaultColor);
			// No matching rule
			if (!color.equals(expected)) {
				throw new Error(`[${this._theme.label}]: Unexpected color ${Color.Format.CSS.formatHexA(color)} for ${scopes}. Expected default ${Color.Format.CSS.formatHexA(expected)}`);
			}
			return this._generateExplanation('default', color);
		}

		let expected = Color.fromHex(matchingRule.settings.foreground);
		if (!color.equals(expected)) {
			throw new Error(`[${this._theme.label}]: Unexpected color ${Color.Format.CSS.formatHexA(color)} for ${scopes}. Expected ${Color.Format.CSS.formatHexA(expected)} coming in from ${matchingRule.rawSelector}`);
		}
		return this._generateExplanation(matchingRule.rawSelector, color);
	}

	private _findMatchingThemeRule(scopes: string): ThemeRule {
		if (!this._cache[scopes]) {
			this._cache[scopes] = findMatchingThemeRule(this._theme, scopes.split(' '));
		}
		return this._cache[scopes];
	}
}

class Snapper {

	constructor(
		@IModeService private modeService: IModeService,
		@IWorkbenchThemeService private themeService: IWorkbenchThemeService,
		@ITextMateService private textMateService: ITextMateService
	) {
	}

	private _themedTokenize(grammar: IGrammar, lines: string[]): IThemedToken[] {
		let colorMap = TokenizationRegistry.getColorMap();
		let state: StackElement | null = null;
		let result: IThemedToken[] = [], resultLen = 0;
		for (let i = 0, len = lines.length; i < len; i++) {
			let line = lines[i];

			let tokenizationResult = grammar.tokenizeLine2(line, state);

			for (let j = 0, lenJ = tokenizationResult.tokens.length >>> 1; j < lenJ; j++) {
				let startOffset = tokenizationResult.tokens[(j << 1)];
				let metadata = tokenizationResult.tokens[(j << 1) + 1];
				let endOffset = j + 1 < lenJ ? tokenizationResult.tokens[((j + 1) << 1)] : line.length;
				let tokenText = line.substring(startOffset, endOffset);

				let color = TokenMetadata.getForeground(metadata);

				result[resultLen++] = {
					text: tokenText,
					color: colorMap[color]
				};
			}

			state = tokenizationResult.ruleStack;
		}

		return result;
	}

	private _tokenize(grammar: IGrammar, lines: string[]): IToken[] {
		let state: StackElement | null = null;
		let result: IToken[] = [], resultLen = 0;
		for (let i = 0, len = lines.length; i < len; i++) {
			let line = lines[i];

			let tokenizationResult = grammar.tokenizeLine(line, state);
			let lastScopes: string | null = null;

			for (let j = 0, lenJ = tokenizationResult.tokens.length; j < lenJ; j++) {
				let token = tokenizationResult.tokens[j];
				let tokenText = line.substring(token.startIndex, token.endIndex);
				let tokenScopes = token.scopes.join(' ');

				if (lastScopes === tokenScopes) {
					result[resultLen - 1].c += tokenText;
				} else {
					lastScopes = tokenScopes;
					result[resultLen++] = {
						c: tokenText,
						t: tokenScopes,
						r: {
							dark_plus: null,
							light_plus: null,
							dark_vs: null,
							light_vs: null,
							hc_black: null,
						}
					};
				}
			}

			state = tokenizationResult.ruleStack;
		}
		return result;
	}

	private async _getThemesResult(grammar: IGrammar, lines: string[]): Promise<IThemesResult> {
		let currentTheme = this.themeService.getColorTheme();

		let getThemeName = (id: string) => {
			let part = 'vscode-theme-defaults-themes-';
			let startIdx = id.indexOf(part);
			if (startIdx !== -1) {
				return id.substring(startIdx + part.length, id.length - 5);
			}
			return void 0;
		};

		let result: IThemesResult = {};

		let themeDatas = await this.themeService.getColorThemes();
		let defaultThemes = themeDatas.filter(themeData => !!getThemeName(themeData.id));
		for (let defaultTheme of defaultThemes) {
			let themeId = defaultTheme.id;
			let success = await this.themeService.setColorTheme(themeId, null);
			if (success) {
				let themeName = getThemeName(themeId);
				result[themeName] = {
					document: new ThemeDocument(this.themeService.getColorTheme()),
					tokens: this._themedTokenize(grammar, lines)
				};
			}
		}
		await this.themeService.setColorTheme(currentTheme.id, null);
		return result;
	}

	private _enrichResult(result: IToken[], themesResult: IThemesResult): void {
		let index: { [themeName: string]: number; } = {};
		let themeNames = Object.keys(themesResult);
		for (let t = 0; t < themeNames.length; t++) {
			let themeName = themeNames[t];
			index[themeName] = 0;
		}

		for (let i = 0, len = result.length; i < len; i++) {
			let token = result[i];

			for (let t = 0; t < themeNames.length; t++) {
				let themeName = themeNames[t];
				let themedToken = themesResult[themeName].tokens[index[themeName]];

				themedToken.text = themedToken.text.substr(token.c.length);
				token.r[themeName] = themesResult[themeName].document.explainTokenColor(token.t, themedToken.color);
				if (themedToken.text.length === 0) {
					index[themeName]++;
				}
			}
		}
	}

	public captureSyntaxTokens(fileName: string, content: string): Thenable<IToken[]> {
		const modeId = this.modeService.getModeIdByFilepathOrFirstLine(fileName);
		return this.textMateService.createGrammar(modeId).then((grammar) => {
			let lines = content.split(/\r\n|\r|\n/);

			let result = this._tokenize(grammar, lines);
			return this._getThemesResult(grammar, lines).then((themesResult) => {
				this._enrichResult(result, themesResult);
				return result.filter(t => t.c.length > 0);
			});
		});
	}
}

CommandsRegistry.registerCommand('_workbench.captureSyntaxTokens', function (accessor: ServicesAccessor, resource: URI) {

	let process = (resource: URI) => {
		let filePath = resource.fsPath;
		let fileName = paths.basename(filePath);
		let snapper = accessor.get(IInstantiationService).createInstance(Snapper);

		return pfs.readFile(filePath).then(content => {
			return snapper.captureSyntaxTokens(fileName, content.toString());
		});
	};

	if (!resource) {
		let editorService = accessor.get(IEditorService);
		let file = toResource(editorService.activeEditor, { filter: 'file' });
		if (file) {
			process(file).then(result => {
				console.log(result);
			});
		} else {
			console.log('No file editor active');
		}
	} else {
		return process(resource);
	}
	return undefined;
});
