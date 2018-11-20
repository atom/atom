/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import * as assert from 'assert';
import * as path from 'path';
import { getPathFromAmdModule } from 'vs/base/common/amd';
import { Keybinding, ResolvedKeybinding, SimpleKeybinding } from 'vs/base/common/keyCodes';
import { ScanCodeBinding } from 'vs/base/common/scanCode';
import { readFile, writeFile } from 'vs/base/node/pfs';
import { IKeyboardEvent } from 'vs/platform/keybinding/common/keybinding';
import { IKeyboardMapper } from 'vs/workbench/services/keybinding/common/keyboardMapper';

export interface IResolvedKeybinding {
	label: string | null;
	ariaLabel: string | null;
	electronAccelerator: string | null;
	userSettingsLabel: string | null;
	isWYSIWYG: boolean;
	isChord: boolean;
	dispatchParts: [string | null, string | null];
}

function toIResolvedKeybinding(kb: ResolvedKeybinding): IResolvedKeybinding {
	return {
		label: kb.getLabel(),
		ariaLabel: kb.getAriaLabel(),
		electronAccelerator: kb.getElectronAccelerator(),
		userSettingsLabel: kb.getUserSettingsLabel(),
		isWYSIWYG: kb.isWYSIWYG(),
		isChord: kb.isChord(),
		dispatchParts: kb.getDispatchParts(),
	};
}

export function assertResolveKeybinding(mapper: IKeyboardMapper, keybinding: Keybinding, expected: IResolvedKeybinding[]): void {
	let actual: IResolvedKeybinding[] = mapper.resolveKeybinding(keybinding).map(toIResolvedKeybinding);
	assert.deepEqual(actual, expected);
}

export function assertResolveKeyboardEvent(mapper: IKeyboardMapper, keyboardEvent: IKeyboardEvent, expected: IResolvedKeybinding): void {
	let actual = toIResolvedKeybinding(mapper.resolveKeyboardEvent(keyboardEvent));
	assert.deepEqual(actual, expected);
}

export function assertResolveUserBinding(mapper: IKeyboardMapper, firstPart: SimpleKeybinding | ScanCodeBinding, chordPart: SimpleKeybinding | ScanCodeBinding, expected: IResolvedKeybinding[]): void {
	let actual: IResolvedKeybinding[] = mapper.resolveUserBinding(firstPart, chordPart).map(toIResolvedKeybinding);
	assert.deepEqual(actual, expected);
}

export function readRawMapping<T>(file: string): Promise<T> {
	return readFile(getPathFromAmdModule(require, `vs/workbench/services/keybinding/test/${file}.js`)).then((buff) => {
		let contents = buff.toString();
		let func = new Function('define', contents);
		let rawMappings: T | null = null;
		func(function (value: T) {
			rawMappings = value;
		});
		return rawMappings!;
	});
}

export function assertMapping(writeFileIfDifferent: boolean, mapper: IKeyboardMapper, file: string): Promise<void> {
	const filePath = path.normalize(getPathFromAmdModule(require, `vs/workbench/services/keybinding/test/${file}`));

	return readFile(filePath).then((buff) => {
		let expected = buff.toString();
		const actual = mapper.dumpDebugInfo();
		if (actual !== expected && writeFileIfDifferent) {
			const destPath = filePath.replace(/vscode\/out\/vs/, 'vscode/src/vs');
			writeFile(destPath, actual);
		}

		assert.deepEqual(actual.split(/\r\n|\n/), expected.split(/\r\n|\n/));
	});
}
