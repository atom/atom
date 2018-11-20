/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import { Registry } from 'vs/platform/registry/common/platform';
import { IColorRegistry, Extensions, ColorContribution } from 'vs/platform/theme/common/colorRegistry';
import { editorMarkerNavigationError } from 'vs/editor/contrib/gotoError/gotoErrorWidget';
import { overviewRulerModifiedForeground } from 'vs/workbench/parts/scm/electron-browser/dirtydiffDecorator';
import { STATUS_BAR_DEBUGGING_BACKGROUND } from 'vs/workbench/parts/debug/browser/statusbarColorProvider';
import { debugExceptionWidgetBackground } from 'vs/workbench/parts/debug/browser/exceptionWidget';
import { debugToolBarBackground } from 'vs/workbench/parts/debug/browser/debugToolbar';
import { buttonBackground } from 'vs/workbench/parts/welcome/page/electron-browser/welcomePage';
import { embeddedEditorBackground } from 'vs/workbench/parts/welcome/walkThrough/electron-browser/walkThroughPart';
import { request, asText } from 'vs/base/node/request';
import * as pfs from 'vs/base/node/pfs';
import * as path from 'path';
import * as assert from 'assert';
import { getPathFromAmdModule } from 'vs/base/common/amd';
import { CancellationToken } from 'vs/base/common/cancellation';


interface ColorInfo {
	description: string;
	offset: number;
	length: number;
}

interface DescriptionDiff {
	docDescription: string;
	specDescription: string;
}

// add artificial dependencies to some files that are not loaded yet
export const forceColorLoad = [editorMarkerNavigationError, overviewRulerModifiedForeground, STATUS_BAR_DEBUGGING_BACKGROUND,
	debugExceptionWidgetBackground, debugToolBarBackground, buttonBackground, embeddedEditorBackground];

export const experimental: string[] = []; // 'settings.modifiedItemForeground', 'editorUnnecessary.foreground' ];

suite('Color Registry', function () {

	test('all colors documented', async function () {
		const reqContext = await request({ url: 'https://raw.githubusercontent.com/Microsoft/vscode-docs/vnext/docs/getstarted/theme-color-reference.md' }, CancellationToken.None);
		const content = await asText(reqContext);

		const expression = /\-\s*\`([\w\.]+)\`: (.*)/g;

		let m: RegExpExecArray;
		let colorsInDoc: { [id: string]: ColorInfo } = Object.create(null);
		while (m = expression.exec(content)) {
			colorsInDoc[m[1]] = { description: m[2], offset: m.index, length: m.length };
		}
		let missing = Object.create(null);
		let descriptionDiffs: { [id: string]: DescriptionDiff } = Object.create(null);

		let themingRegistry = Registry.as<IColorRegistry>(Extensions.ColorContribution);
		for (let color of themingRegistry.getColors()) {
			if (!colorsInDoc[color.id]) {
				if (!color.deprecationMessage) {
					missing[color.id] = getDescription(color);
				}
			} else {
				let docDescription = colorsInDoc[color.id].description;
				let specDescription = getDescription(color);
				if (docDescription !== specDescription) {
					descriptionDiffs[color.id] = { docDescription, specDescription };
				}
				delete colorsInDoc[color.id];
			}
		}
		let colorsInExtensions = await getColorsFromExtension();
		for (let colorId in colorsInExtensions) {
			if (!colorsInDoc[colorId]) {
				missing[colorId] = colorsInExtensions[colorId];
			} else {
				delete colorsInDoc[colorId];
			}
		}
		for (let colorId of experimental) {
			if (missing[colorId]) {
				delete missing[colorId];
			}
			if (colorsInDoc[colorId]) {
				assert.fail(`Color ${colorId} found in doc but marked experimental. Please remove from experimental list.`);
			}
		}

		let undocumentedKeys = Object.keys(missing).map(k => `${k}: ${missing[k]}`);
		assert.deepEqual(undocumentedKeys, [], 'Undocumented colors ids');

		let superfluousKeys = Object.keys(colorsInDoc);
		assert.deepEqual(superfluousKeys, [], 'Colors ids in doc that do not exist');

	});
});

function getDescription(color: ColorContribution) {
	let specDescription = color.description;
	if (color.deprecationMessage) {
		specDescription = specDescription + ' ' + color.deprecationMessage;
	}
	return specDescription;
}

async function getColorsFromExtension(): Promise<{ [id: string]: string }> {
	let extPath = getPathFromAmdModule(require, '../../../../../../extensions');
	let extFolders = await pfs.readDirsInDir(extPath);
	let result: { [id: string]: string } = Object.create(null);
	for (let folder of extFolders) {
		try {
			let packageJSON = JSON.parse((await pfs.readFile(path.join(extPath, folder, 'package.json'))).toString());
			let contributes = packageJSON['contributes'];
			if (contributes) {
				let colors = contributes['colors'];
				if (colors) {
					for (let color of colors) {
						let colorId = color['id'];
						if (colorId) {
							result[colorId] = colorId['description'];
						}
					}
				}
			}
		} catch (e) {
			// ignore
		}

	}
	return result;
}
