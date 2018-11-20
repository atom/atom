/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import * as nls from 'vs/nls';
import * as errors from 'vs/base/common/errors';
import { URI } from 'vs/base/common/uri';
import * as network from 'vs/base/common/network';
import { Disposable } from 'vs/base/common/lifecycle';
import { IReplaceService } from 'vs/workbench/parts/search/common/replace';
import { IEditorService } from 'vs/workbench/services/editor/common/editorService';
import { IModelService } from 'vs/editor/common/services/modelService';
import { IModeService } from 'vs/editor/common/services/modeService';
import { Match, FileMatch, FileMatchOrMatch, ISearchWorkbenchService } from 'vs/workbench/parts/search/common/searchModel';
import { IProgressRunner } from 'vs/platform/progress/common/progress';
import { ITextModelService, ITextModelContentProvider } from 'vs/editor/common/services/resolverService';
import { IWorkbenchContribution } from 'vs/workbench/common/contributions';
import { ScrollType } from 'vs/editor/common/editorCommon';
import { ITextModel, IIdentifiedSingleEditOperation } from 'vs/editor/common/model';
import { IInstantiationService } from 'vs/platform/instantiation/common/instantiation';
import { ResourceTextEdit } from 'vs/editor/common/modes';
import { createTextBufferFactoryFromSnapshot } from 'vs/editor/common/model/textModel';
import { ITextFileService } from 'vs/workbench/services/textfile/common/textfiles';
import { IBulkEditService } from 'vs/editor/browser/services/bulkEditService';
import { Range } from 'vs/editor/common/core/range';
import { EditOperation } from 'vs/editor/common/core/editOperation';
import { mergeSort } from 'vs/base/common/arrays';

const REPLACE_PREVIEW = 'replacePreview';

const toReplaceResource = (fileResource: URI): URI => {
	return fileResource.with({ scheme: network.Schemas.internal, fragment: REPLACE_PREVIEW, query: JSON.stringify({ scheme: fileResource.scheme }) });
};

const toFileResource = (replaceResource: URI): URI => {
	return replaceResource.with({ scheme: JSON.parse(replaceResource.query)['scheme'], fragment: '', query: '' });
};

export class ReplacePreviewContentProvider implements ITextModelContentProvider, IWorkbenchContribution {

	constructor(
		@IInstantiationService private instantiationService: IInstantiationService,
		@ITextModelService private textModelResolverService: ITextModelService
	) {
		this.textModelResolverService.registerTextModelContentProvider(network.Schemas.internal, this);
	}

	public provideTextContent(uri: URI): Thenable<ITextModel> {
		if (uri.fragment === REPLACE_PREVIEW) {
			return this.instantiationService.createInstance(ReplacePreviewModel).resolve(uri);
		}
		return null;
	}
}

class ReplacePreviewModel extends Disposable {
	constructor(
		@IModelService private modelService: IModelService,
		@IModeService private modeService: IModeService,
		@ITextModelService private textModelResolverService: ITextModelService,
		@IReplaceService private replaceService: IReplaceService,
		@ISearchWorkbenchService private searchWorkbenchService: ISearchWorkbenchService
	) {
		super();
	}

	resolve(replacePreviewUri: URI): Thenable<ITextModel> {
		const fileResource = toFileResource(replacePreviewUri);
		const fileMatch = <FileMatch>this.searchWorkbenchService.searchModel.searchResult.matches().filter(match => match.resource().toString() === fileResource.toString())[0];
		return this.textModelResolverService.createModelReference(fileResource).then(ref => {
			ref = this._register(ref);
			const sourceModel = ref.object.textEditorModel;
			const sourceModelModeId = sourceModel.getLanguageIdentifier().language;
			const replacePreviewModel = this.modelService.createModel(createTextBufferFactoryFromSnapshot(sourceModel.createSnapshot()), this.modeService.create(sourceModelModeId), replacePreviewUri);
			this._register(fileMatch.onChange(modelChange => this.update(sourceModel, replacePreviewModel, fileMatch, modelChange)));
			this._register(this.searchWorkbenchService.searchModel.onReplaceTermChanged(() => this.update(sourceModel, replacePreviewModel, fileMatch)));
			this._register(fileMatch.onDispose(() => replacePreviewModel.dispose())); // TODO@Sandeep we should not dispose a model directly but rather the reference (depends on https://github.com/Microsoft/vscode/issues/17073)
			this._register(replacePreviewModel.onWillDispose(() => this.dispose()));
			this._register(sourceModel.onWillDispose(() => this.dispose()));
			return replacePreviewModel;
		});
	}

	private update(sourceModel: ITextModel, replacePreviewModel: ITextModel, fileMatch: FileMatch, override: boolean = false): void {
		if (!sourceModel.isDisposed() && !replacePreviewModel.isDisposed()) {
			this.replaceService.updateReplacePreview(fileMatch, override);
		}
	}
}

export class ReplaceService implements IReplaceService {

	public _serviceBrand: any;

	constructor(
		@ITextFileService private textFileService: ITextFileService,
		@IEditorService private editorService: IEditorService,
		@ITextModelService private textModelResolverService: ITextModelService,
		@IBulkEditService private bulkEditorService: IBulkEditService
	) { }

	public replace(match: Match): Promise<any>;
	public replace(files: FileMatch[], progress?: IProgressRunner): Promise<any>;
	public replace(match: FileMatchOrMatch, progress?: IProgressRunner, resource?: URI): Promise<any>;
	public replace(arg: any, progress: IProgressRunner | null = null, resource: URI | null = null): Promise<any> {

		const edits: ResourceTextEdit[] = this.createEdits(arg, resource);
		return this.bulkEditorService.apply({ edits }, { progress }).then(() => this.textFileService.saveAll(edits.map(e => e.resource)));

	}

	public openReplacePreview(element: FileMatchOrMatch, preserveFocus?: boolean, sideBySide?: boolean, pinned?: boolean): Thenable<any> {
		const fileMatch = element instanceof Match ? element.parent() : element;

		return this.editorService.openEditor({
			leftResource: fileMatch.resource(),
			rightResource: toReplaceResource(fileMatch.resource()),
			label: nls.localize('fileReplaceChanges', "{0} ↔ {1} (Replace Preview)", fileMatch.name(), fileMatch.name()),
			options: {
				preserveFocus,
				pinned,
				revealIfVisible: true
			}
		}).then(editor => {
			const disposable = fileMatch.onDispose(() => {
				if (editor && editor.input) {
					editor.input.dispose();
				}
				disposable.dispose();
			});
			this.updateReplacePreview(fileMatch).then(() => {
				let editorControl = editor.getControl();
				if (element instanceof Match) {
					editorControl.revealLineInCenter(element.range().startLineNumber, ScrollType.Immediate);
				}
			});
		}, errors.onUnexpectedError);
	}

	public updateReplacePreview(fileMatch: FileMatch, override: boolean = false): Promise<void> {
		const replacePreviewUri = toReplaceResource(fileMatch.resource());
		return Promise.all([this.textModelResolverService.createModelReference(fileMatch.resource()), this.textModelResolverService.createModelReference(replacePreviewUri)])
			.then(([sourceModelRef, replaceModelRef]) => {
				const sourceModel = sourceModelRef.object.textEditorModel;
				const replaceModel = replaceModelRef.object.textEditorModel;
				let returnValue = Promise.resolve(null);
				// If model is disposed do not update
				if (sourceModel && replaceModel) {
					if (override) {
						replaceModel.setValue(sourceModel.getValue());
					} else {
						replaceModel.undo();
					}
					this.applyEditsToPreview(fileMatch, replaceModel);
				}
				return returnValue.then(() => {
					sourceModelRef.dispose();
					replaceModelRef.dispose();
				});
			});
	}

	private applyEditsToPreview(fileMatch: FileMatch, replaceModel: ITextModel): void {
		const resourceEdits = this.createEdits(fileMatch, replaceModel.uri);
		const modelEdits: IIdentifiedSingleEditOperation[] = [];
		for (const resourceEdit of resourceEdits) {
			for (const edit of resourceEdit.edits) {
				const range = Range.lift(edit.range);
				modelEdits.push(EditOperation.replaceMove(range, edit.text));
			}
		}
		replaceModel.pushEditOperations([], mergeSort(modelEdits, (a, b) => Range.compareRangesUsingStarts(a.range, b.range)), () => []);
	}

	private createEdits(arg: FileMatchOrMatch | FileMatch[], resource: URI | null = null): ResourceTextEdit[] {
		const edits: ResourceTextEdit[] = [];

		if (arg instanceof Match) {
			let match = <Match>arg;
			edits.push(this.createEdit(match, match.replaceString, resource));
		}

		if (arg instanceof FileMatch) {
			arg = [arg];
		}

		if (arg instanceof Array) {
			arg.forEach(element => {
				let fileMatch = <FileMatch>element;
				if (fileMatch.count() > 0) {
					edits.push(...fileMatch.matches().map(match => this.createEdit(match, match.replaceString, resource)));
				}
			});
		}

		return edits;
	}

	private createEdit(match: Match, text: string, resource: URI | null = null): ResourceTextEdit {
		let fileMatch: FileMatch = match.parent();
		let resourceEdit: ResourceTextEdit = {
			resource: resource !== null ? resource : fileMatch.resource(),
			edits: [{
				range: match.range(),
				text: text
			}]
		};
		return resourceEdit;
	}
}
