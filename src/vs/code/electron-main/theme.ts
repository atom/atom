/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import { isWindows, isMacintosh } from 'vs/base/common/platform';
import { systemPreferences } from 'electron';
import { IStateService } from 'vs/platform/state/common/state';

export const DEFAULT_BG_LIGHT = '#FFFFFF';
export const DEFAULT_BG_DARK = '#1E1E1E';
export const DEFAULT_BG_HC_BLACK = '#000000';

export const THEME_STORAGE_KEY = 'theme';
export const THEME_BG_STORAGE_KEY = 'themeBackground';

export function getBackgroundColor(stateService: IStateService): string {
	if (isWindows && systemPreferences.isInvertedColorScheme()) {
		return DEFAULT_BG_HC_BLACK;
	}

	let background = stateService.getItem<string | null>(THEME_BG_STORAGE_KEY, null);
	if (!background) {
		let baseTheme: string;
		if (isWindows && systemPreferences.isInvertedColorScheme()) {
			baseTheme = 'hc-black';
		} else {
			baseTheme = stateService.getItem<string>(THEME_STORAGE_KEY, 'vs-dark').split(' ')[0];
		}

		background = (baseTheme === 'hc-black') ? DEFAULT_BG_HC_BLACK : (baseTheme === 'vs' ? DEFAULT_BG_LIGHT : DEFAULT_BG_DARK);
	}

	if (isMacintosh && background.toUpperCase() === DEFAULT_BG_DARK) {
		background = '#171717'; // https://github.com/electron/electron/issues/5150
	}

	return background;
}