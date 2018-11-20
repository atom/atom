/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import * as dom from 'vs/base/browser/dom';
import { Color } from 'vs/base/common/color';
import { Emitter, Event } from 'vs/base/common/event';
import { TokenizationRegistry } from 'vs/editor/common/modes';
import { ITokenThemeRule, TokenTheme, generateTokensCSSForColorMap } from 'vs/editor/common/modes/supports/tokenization';
import { BuiltinTheme, IStandaloneTheme, IStandaloneThemeData, IStandaloneThemeService } from 'vs/editor/standalone/common/standaloneThemeService';
import { hc_black, vs, vs_dark } from 'vs/editor/standalone/common/themes';
import { IEnvironmentService } from 'vs/platform/environment/common/environment';
import { Registry } from 'vs/platform/registry/common/platform';
import { ColorIdentifier, Extensions, IColorRegistry } from 'vs/platform/theme/common/colorRegistry';
import { Extensions as ThemingExtensions, ICssStyleCollector, IIconTheme, IThemingRegistry } from 'vs/platform/theme/common/themeService';

const VS_THEME_NAME = 'vs';
const VS_DARK_THEME_NAME = 'vs-dark';
const HC_BLACK_THEME_NAME = 'hc-black';

const colorRegistry = Registry.as<IColorRegistry>(Extensions.ColorContribution);
const themingRegistry = Registry.as<IThemingRegistry>(ThemingExtensions.ThemingContribution);

class StandaloneTheme implements IStandaloneTheme {
	public readonly id: string;
	public readonly themeName: string;

	private themeData: IStandaloneThemeData;
	private colors: { [colorId: string]: Color } | null;
	private defaultColors: { [colorId: string]: Color | null; };
	private _tokenTheme: TokenTheme | null;

	constructor(name: string, standaloneThemeData: IStandaloneThemeData) {
		this.themeData = standaloneThemeData;
		let base = standaloneThemeData.base;
		if (name.length > 0) {
			this.id = base + ' ' + name;
			this.themeName = name;
		} else {
			this.id = base;
			this.themeName = base;
		}
		this.colors = null;
		this.defaultColors = Object.create(null);
		this._tokenTheme = null;
	}

	public get base(): string {
		return this.themeData.base;
	}

	public notifyBaseUpdated() {
		if (this.themeData.inherit) {
			this.colors = null;
			this._tokenTheme = null;
		}
	}

	private getColors(): { [colorId: string]: Color } {
		if (!this.colors) {
			let colors: { [colorId: string]: Color } = Object.create(null);
			for (let id in this.themeData.colors) {
				colors[id] = Color.fromHex(this.themeData.colors[id]);
			}
			if (this.themeData.inherit) {
				let baseData = getBuiltinRules(this.themeData.base);
				for (let id in baseData.colors) {
					if (!colors[id]) {
						colors[id] = Color.fromHex(baseData.colors[id]);
					}

				}
			}
			this.colors = colors;
		}
		return this.colors;
	}

	public getColor(colorId: ColorIdentifier, useDefault?: boolean): Color | null {
		const color = this.getColors()[colorId];
		if (color) {
			return color;
		}
		if (useDefault !== false) {
			return this.getDefault(colorId);
		}
		return null;
	}

	private getDefault(colorId: ColorIdentifier): Color | null {
		let color = this.defaultColors[colorId];
		if (color) {
			return color;
		}
		color = colorRegistry.resolveDefaultColor(colorId, this);
		this.defaultColors[colorId] = color;
		return color;
	}

	public defines(colorId: ColorIdentifier): boolean {
		return Object.prototype.hasOwnProperty.call(this.getColors(), colorId);
	}

	public get type() {
		switch (this.base) {
			case VS_THEME_NAME: return 'light';
			case HC_BLACK_THEME_NAME: return 'hc';
			default: return 'dark';
		}
	}

	public get tokenTheme(): TokenTheme {
		if (!this._tokenTheme) {
			let rules: ITokenThemeRule[] = [];
			let encodedTokensColors: string[] = [];
			if (this.themeData.inherit) {
				let baseData = getBuiltinRules(this.themeData.base);
				rules = baseData.rules;
				if (baseData.encodedTokensColors) {
					encodedTokensColors = baseData.encodedTokensColors;
				}
			}
			rules = rules.concat(this.themeData.rules);
			if (this.themeData.encodedTokensColors) {
				encodedTokensColors = this.themeData.encodedTokensColors;
			}
			this._tokenTheme = TokenTheme.createFromRawTokenTheme(rules, encodedTokensColors);
		}
		return this._tokenTheme;
	}
}

function isBuiltinTheme(themeName: string): themeName is BuiltinTheme {
	return (
		themeName === VS_THEME_NAME
		|| themeName === VS_DARK_THEME_NAME
		|| themeName === HC_BLACK_THEME_NAME
	);
}

function getBuiltinRules(builtinTheme: BuiltinTheme): IStandaloneThemeData {
	switch (builtinTheme) {
		case VS_THEME_NAME:
			return vs;
		case VS_DARK_THEME_NAME:
			return vs_dark;
		case HC_BLACK_THEME_NAME:
			return hc_black;
	}
}

function newBuiltInTheme(builtinTheme: BuiltinTheme): StandaloneTheme {
	let themeData = getBuiltinRules(builtinTheme);
	return new StandaloneTheme(builtinTheme, themeData);
}

export class StandaloneThemeServiceImpl implements IStandaloneThemeService {

	_serviceBrand: any;

	private _knownThemes: Map<string, StandaloneTheme>;
	private _styleElement: HTMLStyleElement;
	private _theme: IStandaloneTheme;
	private readonly _onThemeChange: Emitter<IStandaloneTheme>;
	private readonly _onIconThemeChange: Emitter<IIconTheme>;
	private environment: IEnvironmentService = Object.create(null);

	constructor() {
		this._onThemeChange = new Emitter<IStandaloneTheme>();
		this._onIconThemeChange = new Emitter<IIconTheme>();

		this._knownThemes = new Map<string, StandaloneTheme>();
		this._knownThemes.set(VS_THEME_NAME, newBuiltInTheme(VS_THEME_NAME));
		this._knownThemes.set(VS_DARK_THEME_NAME, newBuiltInTheme(VS_DARK_THEME_NAME));
		this._knownThemes.set(HC_BLACK_THEME_NAME, newBuiltInTheme(HC_BLACK_THEME_NAME));
		this._styleElement = dom.createStyleSheet();
		this._styleElement.className = 'monaco-colors';
		this.setTheme(VS_THEME_NAME);
	}

	public get onThemeChange(): Event<IStandaloneTheme> {
		return this._onThemeChange.event;
	}

	public defineTheme(themeName: string, themeData: IStandaloneThemeData): void {
		if (!/^[a-z0-9\-]+$/i.test(themeName)) {
			throw new Error('Illegal theme name!');
		}
		if (!isBuiltinTheme(themeData.base) && !isBuiltinTheme(themeName)) {
			throw new Error('Illegal theme base!');
		}
		// set or replace theme
		this._knownThemes.set(themeName, new StandaloneTheme(themeName, themeData));

		if (isBuiltinTheme(themeName)) {
			this._knownThemes.forEach(theme => {
				if (theme.base === themeName) {
					theme.notifyBaseUpdated();
				}
			});
		}
		if (this._theme && this._theme.themeName === themeName) {
			this.setTheme(themeName); // refresh theme
		}
	}

	public getTheme(): IStandaloneTheme {
		return this._theme;
	}

	public setTheme(themeName: string): string {
		let theme: StandaloneTheme;
		if (this._knownThemes.has(themeName)) {
			theme = this._knownThemes.get(themeName);
		} else {
			theme = this._knownThemes.get(VS_THEME_NAME);
		}
		if (this._theme === theme) {
			// Nothing to do
			return theme.id;
		}
		this._theme = theme;

		let cssRules: string[] = [];
		let hasRule: { [rule: string]: boolean; } = {};
		let ruleCollector: ICssStyleCollector = {
			addRule: (rule: string) => {
				if (!hasRule[rule]) {
					cssRules.push(rule);
					hasRule[rule] = true;
				}
			}
		};
		themingRegistry.getThemingParticipants().forEach(p => p(theme, ruleCollector, this.environment));

		let tokenTheme = theme.tokenTheme;
		let colorMap = tokenTheme.getColorMap();
		ruleCollector.addRule(generateTokensCSSForColorMap(colorMap));

		this._styleElement.innerHTML = cssRules.join('\n');

		TokenizationRegistry.setColorMap(colorMap);
		this._onThemeChange.fire(theme);

		return theme.id;
	}

	public getIconTheme(): IIconTheme {
		return {
			hasFileIcons: false,
			hasFolderIcons: false,
			hidesExplorerArrows: false
		};
	}

	public get onIconThemeChange(): Event<IIconTheme> {
		return this._onIconThemeChange.event;
	}
}
