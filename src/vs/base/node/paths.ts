/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import { getPathFromAmdModule } from 'vs/base/common/amd';

interface IPaths {
	getAppDataPath(platform: string): string;
	getDefaultUserDataPath(platform: string): string;
}

const pathsPath = getPathFromAmdModule(require, 'paths');
const paths = require.__$__nodeRequire<IPaths>(pathsPath);
export const getAppDataPath = paths.getAppDataPath;
export const getDefaultUserDataPath = paths.getDefaultUserDataPath;
