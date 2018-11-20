/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import { ITokenThemeRule, TokenTheme } from 'vs/editor/common/modes/supports/tokenization';
import { createDecorator } from 'vs/platform/instantiation/common/instantiation';
import { ITheme, IThemeService } from 'vs/platform/theme/common/themeService';

export const IStandaloneThemeService = createDecorator<IStandaloneThemeService>('themeService');

export type BuiltinTheme = 'vs' | 'vs-dark' | 'hc-black';
export type IColors = { [colorId: string]: string; };

export interface IStandaloneThemeData {
	base: BuiltinTheme;
	inherit: boolean;
	rules: ITokenThemeRule[];
	encodedTokensColors?: string[];
	colors: IColors;
}

export interface IStandaloneTheme extends ITheme {
	tokenTheme: TokenTheme;
	themeName: string;
}

export interface IStandaloneThemeService extends IThemeService {
	_serviceBrand: any;

	setTheme(themeName: string): string;

	defineTheme(themeName: string, themeData: IStandaloneThemeData): void;

	getTheme(): IStandaloneTheme;
}
