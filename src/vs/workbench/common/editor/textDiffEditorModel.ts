/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import { TPromise } from 'vs/base/common/winjs.base';
import { IDiffEditorModel } from 'vs/editor/common/editorCommon';
import { EditorModel } from 'vs/workbench/common/editor';
import { BaseTextEditorModel } from 'vs/workbench/common/editor/textEditorModel';
import { DiffEditorModel } from 'vs/workbench/common/editor/diffEditorModel';

/**
 * The base text editor model for the diff editor. It is made up of two text editor models, the original version
 * and the modified version.
 */
export class TextDiffEditorModel extends DiffEditorModel {
	private _textDiffEditorModel: IDiffEditorModel;

	constructor(originalModel: BaseTextEditorModel, modifiedModel: BaseTextEditorModel) {
		super(originalModel, modifiedModel);

		this.updateTextDiffEditorModel();
	}

	get originalModel(): BaseTextEditorModel {
		return this._originalModel as BaseTextEditorModel;
	}

	get modifiedModel(): BaseTextEditorModel {
		return this._modifiedModel as BaseTextEditorModel;
	}

	load(): TPromise<EditorModel> {
		return super.load().then(() => {
			this.updateTextDiffEditorModel();

			return this;
		});
	}

	private updateTextDiffEditorModel(): void {
		if (this.originalModel.isResolved() && this.modifiedModel.isResolved()) {

			// Create new
			if (!this._textDiffEditorModel) {
				this._textDiffEditorModel = {
					original: this.originalModel.textEditorModel,
					modified: this.modifiedModel.textEditorModel
				};
			}

			// Update existing
			else {
				this._textDiffEditorModel.original = this.originalModel.textEditorModel;
				this._textDiffEditorModel.modified = this.modifiedModel.textEditorModel;
			}
		}
	}

	get textDiffEditorModel(): IDiffEditorModel {
		return this._textDiffEditorModel;
	}

	isResolved(): boolean {
		return !!this._textDiffEditorModel;
	}

	isReadonly(): boolean {
		return this.modifiedModel.isReadonly();
	}

	dispose(): void {

		// Free the diff editor model but do not propagate the dispose() call to the two models
		// inside. We never created the two models (original and modified) so we can not dispose
		// them without sideeffects. Rather rely on the models getting disposed when their related
		// inputs get disposed from the diffEditorInput.
		this._textDiffEditorModel = null;

		super.dispose();
	}
}
