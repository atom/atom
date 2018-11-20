/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import * as nls from 'vs/nls';
import { URI } from 'vs/base/common/uri';
import { TPromise } from 'vs/base/common/winjs.base';
import { EditorInput } from 'vs/workbench/common/editor';

export class RuntimeExtensionsInput extends EditorInput {

	static readonly ID = 'workbench.runtimeExtensions.input';

	constructor() {
		super();
	}

	getTypeId(): string {
		return RuntimeExtensionsInput.ID;
	}

	getName(): string {
		return nls.localize('extensionsInputName', "Running Extensions");
	}

	matches(other: any): boolean {
		if (!(other instanceof RuntimeExtensionsInput)) {
			return false;
		}
		return true;
	}

	resolve(): TPromise<any> {
		return TPromise.as(null);
	}

	supportsSplitEditor(): boolean {
		return false;
	}

	getResource(): URI {
		return URI.from({
			scheme: 'runtime-extensions',
			path: 'default'
		});
	}
}
