/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/
import * as assert from 'assert';
import * as extHostTypes from 'vs/workbench/api/node/extHostTypes';
import { MainContext, MainThreadTextEditorsShape, WorkspaceEditDto } from 'vs/workbench/api/node/extHost.protocol';
import { URI } from 'vs/base/common/uri';
import { mock } from 'vs/workbench/test/electron-browser/api/mock';
import { ExtHostDocumentsAndEditors } from 'vs/workbench/api/node/extHostDocumentsAndEditors';
import { SingleProxyRPCProtocol, TestRPCProtocol } from 'vs/workbench/test/electron-browser/api/testRPCProtocol';
import { ExtHostEditors } from 'vs/workbench/api/node/extHostTextEditors';
import { ResourceTextEdit } from 'vs/editor/common/modes';

suite('ExtHostTextEditors.applyWorkspaceEdit', () => {

	const resource = URI.parse('foo:bar');
	let editors: ExtHostEditors;
	let workspaceResourceEdits: WorkspaceEditDto;

	setup(() => {
		workspaceResourceEdits = null;

		let rpcProtocol = new TestRPCProtocol();
		rpcProtocol.set(MainContext.MainThreadTextEditors, new class extends mock<MainThreadTextEditorsShape>() {
			$tryApplyWorkspaceEdit(_workspaceResourceEdits: WorkspaceEditDto): Promise<boolean> {
				workspaceResourceEdits = _workspaceResourceEdits;
				return Promise.resolve(true);
			}
		});
		const documentsAndEditors = new ExtHostDocumentsAndEditors(SingleProxyRPCProtocol(null));
		documentsAndEditors.$acceptDocumentsAndEditorsDelta({
			addedDocuments: [{
				isDirty: false,
				modeId: 'foo',
				uri: resource,
				versionId: 1337,
				lines: ['foo'],
				EOL: '\n',
			}]
		});
		editors = new ExtHostEditors(rpcProtocol, documentsAndEditors);
	});

	test('uses version id if document available', async () => {
		let edit = new extHostTypes.WorkspaceEdit();
		edit.replace(resource, new extHostTypes.Range(0, 0, 0, 0), 'hello');
		await editors.applyWorkspaceEdit(edit);
		assert.equal(workspaceResourceEdits.edits.length, 1);
		assert.equal((<ResourceTextEdit>workspaceResourceEdits.edits[0]).modelVersionId, 1337);
	});

	test('does not use version id if document is not available', async () => {
		let edit = new extHostTypes.WorkspaceEdit();
		edit.replace(URI.parse('foo:bar2'), new extHostTypes.Range(0, 0, 0, 0), 'hello');
		await editors.applyWorkspaceEdit(edit);
		assert.equal(workspaceResourceEdits.edits.length, 1);
		assert.ok(typeof (<ResourceTextEdit>workspaceResourceEdits.edits[0]).modelVersionId === 'undefined');
	});

});
