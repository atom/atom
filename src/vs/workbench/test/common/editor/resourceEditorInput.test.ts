/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import * as assert from 'assert';
import { URI } from 'vs/base/common/uri';
import { ResourceEditorInput } from 'vs/workbench/common/editor/resourceEditorInput';
import { ResourceEditorModel } from 'vs/workbench/common/editor/resourceEditorModel';
import { IInstantiationService } from 'vs/platform/instantiation/common/instantiation';
import { workbenchInstantiationService } from 'vs/workbench/test/workbenchTestServices';
import { IModelService } from 'vs/editor/common/services/modelService';
import { IModeService } from 'vs/editor/common/services/modeService';
import { snapshotToString } from 'vs/platform/files/common/files';

class ServiceAccessor {
	constructor(
		@IModelService public modelService: IModelService,
		@IModeService public modeService: IModeService
	) {
	}
}

suite('Workbench resource editor input', () => {

	let instantiationService: IInstantiationService;
	let accessor: ServiceAccessor;

	setup(() => {
		instantiationService = workbenchInstantiationService();
		accessor = instantiationService.createInstance(ServiceAccessor);
	});

	test('simple', () => {
		let resource = URI.from({ scheme: 'inmemory', authority: null, path: 'thePath' });
		accessor.modelService.createModel('function test() {}', accessor.modeService.create('text'), resource);
		let input: ResourceEditorInput = instantiationService.createInstance(ResourceEditorInput, 'The Name', 'The Description', resource);

		return input.resolve().then((model: ResourceEditorModel) => {
			assert.ok(model);
			assert.equal(snapshotToString(model.createSnapshot()), 'function test() {}');
		});
	});
});