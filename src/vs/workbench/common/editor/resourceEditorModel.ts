/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import { BaseTextEditorModel } from 'vs/workbench/common/editor/textEditorModel';
import { URI } from 'vs/base/common/uri';
import { IModeService } from 'vs/editor/common/services/modeService';
import { IModelService } from 'vs/editor/common/services/modelService';

/**
 * An editor model whith an in-memory, readonly content that is backed by an existing editor model.
 */
export class ResourceEditorModel extends BaseTextEditorModel {

	constructor(
		resource: URI,
		@IModeService modeService: IModeService,
		@IModelService modelService: IModelService
	) {
		super(modelService, modeService, resource);

		// TODO@Joao: force this class to dispose the underlying model
		this.createdEditorModel = true;
	}

	isReadonly(): boolean {
		return true;
	}
}