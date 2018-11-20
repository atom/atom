/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import * as assert from 'assert';
import { MainThreadDocumentsAndEditors } from 'vs/workbench/api/electron-browser/mainThreadDocumentsAndEditors';
import { SingleProxyRPCProtocol } from './testRPCProtocol';
import { TestConfigurationService } from 'vs/platform/configuration/test/common/testConfigurationService';
import { ModelServiceImpl } from 'vs/editor/common/services/modelServiceImpl';
import { TestCodeEditorService } from 'vs/editor/test/browser/editorTestServices';
import { ITextFileService } from 'vs/workbench/services/textfile/common/textfiles';
import { ExtHostDocumentsAndEditorsShape, IDocumentsAndEditorsDelta } from 'vs/workbench/api/node/extHost.protocol';
import { createTestCodeEditor, TestCodeEditor } from 'vs/editor/test/browser/testCodeEditor';
import { mock } from 'vs/workbench/test/electron-browser/api/mock';
import { TestEditorService, TestEditorGroupsService, TestTextResourcePropertiesService } from 'vs/workbench/test/workbenchTestServices';
import { Event } from 'vs/base/common/event';
import { ITextModel } from 'vs/editor/common/model';
import { ServiceCollection } from 'vs/platform/instantiation/common/serviceCollection';
import { ICodeEditorService } from 'vs/editor/browser/services/codeEditorService';
import { IFileService } from 'vs/platform/files/common/files';
import { IPanelService } from 'vs/workbench/services/panel/common/panelService';

suite('MainThreadDocumentsAndEditors', () => {

	let modelService: ModelServiceImpl;
	let codeEditorService: TestCodeEditorService;
	let textFileService: ITextFileService;
	let deltas: IDocumentsAndEditorsDelta[] = [];
	const hugeModelString = new Array(2 + (50 * 1024 * 1024)).join('-');

	function myCreateTestCodeEditor(model: ITextModel): TestCodeEditor {
		return createTestCodeEditor({
			model: model,
			serviceCollection: new ServiceCollection(
				[ICodeEditorService, codeEditorService]
			)
		});
	}

	setup(() => {
		deltas.length = 0;
		const configService = new TestConfigurationService();
		configService.setUserConfiguration('editor', { 'detectIndentation': false });
		modelService = new ModelServiceImpl(null, configService, new TestTextResourcePropertiesService(configService));
		codeEditorService = new TestCodeEditorService();
		textFileService = new class extends mock<ITextFileService>() {
			isDirty() { return false; }
			models = <any>{
				onModelSaved: Event.None,
				onModelReverted: Event.None,
				onModelDirty: Event.None,
			};
		};
		const workbenchEditorService = new TestEditorService();
		const editorGroupService = new TestEditorGroupsService();

		const fileService = new class extends mock<IFileService>() {
			onAfterOperation = Event.None;
		};

		/* tslint:disable */
		new MainThreadDocumentsAndEditors(
			SingleProxyRPCProtocol(new class extends mock<ExtHostDocumentsAndEditorsShape>() {
				$acceptDocumentsAndEditorsDelta(delta: IDocumentsAndEditorsDelta) { deltas.push(delta); }
			}),
			modelService,
			textFileService,
			workbenchEditorService,
			codeEditorService,
			null,
			fileService,
			null,
			null,
			editorGroupService,
			null,
			new class extends mock<IPanelService>() implements IPanelService {
				_serviceBrand: any;
				onDidPanelOpen = Event.None;
				onDidPanelClose = Event.None;
				getActivePanel() {
					return null;
				}
			}
		);
		/* tslint:enable */
	});


	test('Model#add', () => {
		deltas.length = 0;

		modelService.createModel('farboo', null, null);

		assert.equal(deltas.length, 1);
		const [delta] = deltas;

		assert.equal(delta.addedDocuments.length, 1);
		assert.equal(delta.removedDocuments, undefined);
		assert.equal(delta.addedEditors, undefined);
		assert.equal(delta.removedEditors, undefined);
		assert.equal(delta.newActiveEditor, null);
	});

	test('ignore huge model', function () {
		this.timeout(1000 * 60); // increase timeout for this one test

		const model = modelService.createModel(hugeModelString, null, null);
		assert.ok(model.isTooLargeForSyncing());

		assert.equal(deltas.length, 1);
		const [delta] = deltas;
		assert.equal(delta.newActiveEditor, null);
		assert.equal(delta.addedDocuments, undefined);
		assert.equal(delta.removedDocuments, undefined);
		assert.equal(delta.addedEditors, undefined);
		assert.equal(delta.removedEditors, undefined);
	});

	test('ignore simple widget model', function () {
		this.timeout(1000 * 60); // increase timeout for this one test

		const model = modelService.createModel('test', null, null, true);
		assert.ok(model.isForSimpleWidget);

		assert.equal(deltas.length, 1);
		const [delta] = deltas;
		assert.equal(delta.newActiveEditor, null);
		assert.equal(delta.addedDocuments, undefined);
		assert.equal(delta.removedDocuments, undefined);
		assert.equal(delta.addedEditors, undefined);
		assert.equal(delta.removedEditors, undefined);
	});

	test('ignore huge model from editor', function () {
		this.timeout(1000 * 60); // increase timeout for this one test

		const model = modelService.createModel(hugeModelString, null, null);
		const editor = myCreateTestCodeEditor(model);

		assert.equal(deltas.length, 1);
		deltas.length = 0;
		assert.equal(deltas.length, 0);

		editor.dispose();
	});

	test('ignore editor w/o model', () => {
		const editor = myCreateTestCodeEditor(null);
		assert.equal(deltas.length, 1);
		const [delta] = deltas;
		assert.equal(delta.newActiveEditor, null);
		assert.equal(delta.addedDocuments, undefined);
		assert.equal(delta.removedDocuments, undefined);
		assert.equal(delta.addedEditors, undefined);
		assert.equal(delta.removedEditors, undefined);

		editor.dispose();
	});

	test('editor with model', () => {
		deltas.length = 0;

		const model = modelService.createModel('farboo', null, null);
		const editor = myCreateTestCodeEditor(model);

		assert.equal(deltas.length, 2);
		const [first, second] = deltas;
		assert.equal(first.addedDocuments.length, 1);
		assert.equal(first.newActiveEditor, null);
		assert.equal(first.removedDocuments, undefined);
		assert.equal(first.addedEditors, undefined);
		assert.equal(first.removedEditors, undefined);

		assert.equal(second.addedEditors.length, 1);
		assert.equal(second.addedDocuments, undefined);
		assert.equal(second.removedDocuments, undefined);
		assert.equal(second.removedEditors, undefined);
		assert.equal(second.newActiveEditor, undefined);

		editor.dispose();
	});

	test('editor with dispos-ed/-ing model', () => {
		modelService.createModel('foobar', null, null);
		const model = modelService.createModel('farboo', null, null);
		const editor = myCreateTestCodeEditor(model);

		// ignore things until now
		deltas.length = 0;

		modelService.destroyModel(model.uri);
		assert.equal(deltas.length, 1);
		const [first] = deltas;

		assert.equal(first.newActiveEditor, null);
		assert.equal(first.removedEditors.length, 1);
		assert.equal(first.removedDocuments.length, 1);
		assert.equal(first.addedDocuments, undefined);
		assert.equal(first.addedEditors, undefined);

		editor.dispose();
	});
});
