/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import { IDisposable, IReference } from 'vs/base/common/lifecycle';
import { URI } from 'vs/base/common/uri';
import { TPromise } from 'vs/base/common/winjs.base';
import { ITextModel } from 'vs/editor/common/model';
import { IEditorModel } from 'vs/platform/editor/common/editor';
import { createDecorator } from 'vs/platform/instantiation/common/instantiation';

export const ITextModelService = createDecorator<ITextModelService>('textModelService');

export interface ITextModelService {
	_serviceBrand: any;

	/**
	 * Provided a resource URI, it will return a model reference
	 * which should be disposed once not needed anymore.
	 */
	createModelReference(resource: URI): TPromise<IReference<ITextEditorModel>>;

	/**
	 * Registers a specific `scheme` content provider.
	 */
	registerTextModelContentProvider(scheme: string, provider: ITextModelContentProvider): IDisposable;
}

export interface ITextModelContentProvider {

	/**
	 * Given a resource, return the content of the resource as `ITextModel`.
	 */
	provideTextContent(resource: URI): Thenable<ITextModel>;
}

export interface ITextEditorModel extends IEditorModel {

	/**
	 * Provides access to the underlying `ITextModel`.
	 */
	textEditorModel: ITextModel;

	isReadonly(): boolean;
}
