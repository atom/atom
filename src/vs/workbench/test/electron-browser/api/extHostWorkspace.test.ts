/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import * as assert from 'assert';
import { URI } from 'vs/base/common/uri';
import { basename } from 'path';
import { ExtHostWorkspace } from 'vs/workbench/api/node/extHostWorkspace';
import { TestRPCProtocol } from './testRPCProtocol';
import { normalize } from 'vs/base/common/paths';
import { IWorkspaceFolderData } from 'vs/platform/workspace/common/workspace';
import { IExtensionDescription } from 'vs/workbench/services/extensions/common/extensions';
import { NullLogService } from 'vs/platform/log/common/log';
import { IMainContext } from 'vs/workbench/api/node/extHost.protocol';
import { Counter } from 'vs/base/common/numbers';

suite('ExtHostWorkspace', function () {

	const extensionDescriptor: IExtensionDescription = {
		id: 'nullExtensionDescription',
		name: 'ext',
		publisher: 'vscode',
		enableProposedApi: false,
		engines: undefined,
		extensionLocation: undefined,
		isBuiltin: false,
		isUnderDevelopment: false,
		version: undefined
	};

	function assertAsRelativePath(workspace: ExtHostWorkspace, input: string, expected: string, includeWorkspace?: boolean) {
		const actual = workspace.getRelativePath(input, includeWorkspace);
		if (actual === expected) {
			assert.ok(true);
		} else {
			assert.equal(actual, normalize(expected, true));
		}
	}

	test('asRelativePath', () => {

		const ws = new ExtHostWorkspace(new TestRPCProtocol(), { id: 'foo', folders: [aWorkspaceFolderData(URI.file('/Coding/Applications/NewsWoWBot'), 0)], name: 'Test' }, new NullLogService(), new Counter());

		assertAsRelativePath(ws, '/Coding/Applications/NewsWoWBot/bernd/das/brot', 'bernd/das/brot');
		assertAsRelativePath(ws, '/Apps/DartPubCache/hosted/pub.dartlang.org/convert-2.0.1/lib/src/hex.dart',
			'/Apps/DartPubCache/hosted/pub.dartlang.org/convert-2.0.1/lib/src/hex.dart');

		assertAsRelativePath(ws, '', '');
		assertAsRelativePath(ws, '/foo/bar', '/foo/bar');
		assertAsRelativePath(ws, 'in/out', 'in/out');
	});

	test('asRelativePath, same paths, #11402', function () {
		const root = '/home/aeschli/workspaces/samples/docker';
		const input = '/home/aeschli/workspaces/samples/docker';
		const ws = new ExtHostWorkspace(new TestRPCProtocol(), { id: 'foo', folders: [aWorkspaceFolderData(URI.file(root), 0)], name: 'Test' }, new NullLogService(), new Counter());

		assertAsRelativePath(ws, (input), input);

		const input2 = '/home/aeschli/workspaces/samples/docker/a.file';
		assertAsRelativePath(ws, (input2), 'a.file');
	});

	test('asRelativePath, no workspace', function () {
		const ws = new ExtHostWorkspace(new TestRPCProtocol(), null, new NullLogService(), new Counter());
		assertAsRelativePath(ws, (''), '');
		assertAsRelativePath(ws, ('/foo/bar'), '/foo/bar');
	});

	test('asRelativePath, multiple folders', function () {
		const ws = new ExtHostWorkspace(new TestRPCProtocol(), { id: 'foo', folders: [aWorkspaceFolderData(URI.file('/Coding/One'), 0), aWorkspaceFolderData(URI.file('/Coding/Two'), 1)], name: 'Test' }, new NullLogService(), new Counter());
		assertAsRelativePath(ws, '/Coding/One/file.txt', 'One/file.txt');
		assertAsRelativePath(ws, '/Coding/Two/files/out.txt', 'Two/files/out.txt');
		assertAsRelativePath(ws, '/Coding/Two2/files/out.txt', '/Coding/Two2/files/out.txt');
	});

	test('slightly inconsistent behaviour of asRelativePath and getWorkspaceFolder, #31553', function () {
		const mrws = new ExtHostWorkspace(new TestRPCProtocol(), { id: 'foo', folders: [aWorkspaceFolderData(URI.file('/Coding/One'), 0), aWorkspaceFolderData(URI.file('/Coding/Two'), 1)], name: 'Test' }, new NullLogService(), new Counter());

		assertAsRelativePath(mrws, '/Coding/One/file.txt', 'One/file.txt');
		assertAsRelativePath(mrws, '/Coding/One/file.txt', 'One/file.txt', true);
		assertAsRelativePath(mrws, '/Coding/One/file.txt', 'file.txt', false);
		assertAsRelativePath(mrws, '/Coding/Two/files/out.txt', 'Two/files/out.txt');
		assertAsRelativePath(mrws, '/Coding/Two/files/out.txt', 'Two/files/out.txt', true);
		assertAsRelativePath(mrws, '/Coding/Two/files/out.txt', 'files/out.txt', false);
		assertAsRelativePath(mrws, '/Coding/Two2/files/out.txt', '/Coding/Two2/files/out.txt');
		assertAsRelativePath(mrws, '/Coding/Two2/files/out.txt', '/Coding/Two2/files/out.txt', true);
		assertAsRelativePath(mrws, '/Coding/Two2/files/out.txt', '/Coding/Two2/files/out.txt', false);

		const srws = new ExtHostWorkspace(new TestRPCProtocol(), { id: 'foo', folders: [aWorkspaceFolderData(URI.file('/Coding/One'), 0)], name: 'Test' }, new NullLogService(), new Counter());
		assertAsRelativePath(srws, '/Coding/One/file.txt', 'file.txt');
		assertAsRelativePath(srws, '/Coding/One/file.txt', 'file.txt', false);
		assertAsRelativePath(srws, '/Coding/One/file.txt', 'One/file.txt', true);
		assertAsRelativePath(srws, '/Coding/Two2/files/out.txt', '/Coding/Two2/files/out.txt');
		assertAsRelativePath(srws, '/Coding/Two2/files/out.txt', '/Coding/Two2/files/out.txt', true);
		assertAsRelativePath(srws, '/Coding/Two2/files/out.txt', '/Coding/Two2/files/out.txt', false);
	});

	test('getPath, legacy', function () {
		let ws = new ExtHostWorkspace(new TestRPCProtocol(), { id: 'foo', name: 'Test', folders: [] }, new NullLogService(), new Counter());
		assert.equal(ws.getPath(), undefined);

		ws = new ExtHostWorkspace(new TestRPCProtocol(), null, new NullLogService(), new Counter());
		assert.equal(ws.getPath(), undefined);

		ws = new ExtHostWorkspace(new TestRPCProtocol(), undefined, new NullLogService(), new Counter());
		assert.equal(ws.getPath(), undefined);

		ws = new ExtHostWorkspace(new TestRPCProtocol(), { id: 'foo', name: 'Test', folders: [aWorkspaceFolderData(URI.file('Folder'), 0), aWorkspaceFolderData(URI.file('Another/Folder'), 1)] }, new NullLogService(), new Counter());
		assert.equal(ws.getPath().replace(/\\/g, '/'), '/Folder');

		ws = new ExtHostWorkspace(new TestRPCProtocol(), { id: 'foo', name: 'Test', folders: [aWorkspaceFolderData(URI.file('/Folder'), 0)] }, new NullLogService(), new Counter());
		assert.equal(ws.getPath().replace(/\\/g, '/'), '/Folder');
	});

	test('WorkspaceFolder has name and index', function () {
		const ws = new ExtHostWorkspace(new TestRPCProtocol(), { id: 'foo', folders: [aWorkspaceFolderData(URI.file('/Coding/One'), 0), aWorkspaceFolderData(URI.file('/Coding/Two'), 1)], name: 'Test' }, new NullLogService(), new Counter());

		const [one, two] = ws.getWorkspaceFolders();

		assert.equal(one.name, 'One');
		assert.equal(one.index, 0);
		assert.equal(two.name, 'Two');
		assert.equal(two.index, 1);
	});

	test('getContainingWorkspaceFolder', () => {
		const ws = new ExtHostWorkspace(new TestRPCProtocol(), {
			id: 'foo',
			name: 'Test',
			folders: [
				aWorkspaceFolderData(URI.file('/Coding/One'), 0),
				aWorkspaceFolderData(URI.file('/Coding/Two'), 1),
				aWorkspaceFolderData(URI.file('/Coding/Two/Nested'), 2)
			]
		}, new NullLogService(), new Counter());

		let folder = ws.getWorkspaceFolder(URI.file('/foo/bar'));
		assert.equal(folder, undefined);

		folder = ws.getWorkspaceFolder(URI.file('/Coding/One/file/path.txt'));
		assert.equal(folder.name, 'One');

		folder = ws.getWorkspaceFolder(URI.file('/Coding/Two/file/path.txt'));
		assert.equal(folder.name, 'Two');

		folder = ws.getWorkspaceFolder(URI.file('/Coding/Two/Nest'));
		assert.equal(folder.name, 'Two');

		folder = ws.getWorkspaceFolder(URI.file('/Coding/Two/Nested/file'));
		assert.equal(folder.name, 'Nested');

		folder = ws.getWorkspaceFolder(URI.file('/Coding/Two/Nested/f'));
		assert.equal(folder.name, 'Nested');

		folder = ws.getWorkspaceFolder(URI.file('/Coding/Two/Nested'), true);
		assert.equal(folder.name, 'Two');

		folder = ws.getWorkspaceFolder(URI.file('/Coding/Two/Nested/'), true);
		assert.equal(folder.name, 'Two');

		folder = ws.getWorkspaceFolder(URI.file('/Coding/Two/Nested'));
		assert.equal(folder.name, 'Nested');

		folder = ws.getWorkspaceFolder(URI.file('/Coding/Two/Nested/'));
		assert.equal(folder.name, 'Nested');

		folder = ws.getWorkspaceFolder(URI.file('/Coding/Two'), true);
		assert.equal(folder, undefined);

		folder = ws.getWorkspaceFolder(URI.file('/Coding/Two'), false);
		assert.equal(folder.name, 'Two');
	});

	test('Multiroot change event should have a delta, #29641', function (done) {
		let ws = new ExtHostWorkspace(new TestRPCProtocol(), { id: 'foo', name: 'Test', folders: [] }, new NullLogService(), new Counter());

		let finished = false;
		const finish = (error?: any) => {
			if (!finished) {
				finished = true;
				done(error);
			}
		};

		let sub = ws.onDidChangeWorkspace(e => {
			try {
				assert.deepEqual(e.added, []);
				assert.deepEqual(e.removed, []);
			} catch (error) {
				finish(error);
			}
		});
		ws.$acceptWorkspaceData({ id: 'foo', name: 'Test', folders: [] });
		sub.dispose();

		sub = ws.onDidChangeWorkspace(e => {
			try {
				assert.deepEqual(e.removed, []);
				assert.equal(e.added.length, 1);
				assert.equal(e.added[0].uri.toString(), 'foo:bar');
			} catch (error) {
				finish(error);
			}
		});
		ws.$acceptWorkspaceData({ id: 'foo', name: 'Test', folders: [aWorkspaceFolderData(URI.parse('foo:bar'), 0)] });
		sub.dispose();

		sub = ws.onDidChangeWorkspace(e => {
			try {
				assert.deepEqual(e.removed, []);
				assert.equal(e.added.length, 1);
				assert.equal(e.added[0].uri.toString(), 'foo:bar2');
			} catch (error) {
				finish(error);
			}
		});
		ws.$acceptWorkspaceData({ id: 'foo', name: 'Test', folders: [aWorkspaceFolderData(URI.parse('foo:bar'), 0), aWorkspaceFolderData(URI.parse('foo:bar2'), 1)] });
		sub.dispose();

		sub = ws.onDidChangeWorkspace(e => {
			try {
				assert.equal(e.removed.length, 2);
				assert.equal(e.removed[0].uri.toString(), 'foo:bar');
				assert.equal(e.removed[1].uri.toString(), 'foo:bar2');

				assert.equal(e.added.length, 1);
				assert.equal(e.added[0].uri.toString(), 'foo:bar3');
			} catch (error) {
				finish(error);
			}
		});
		ws.$acceptWorkspaceData({ id: 'foo', name: 'Test', folders: [aWorkspaceFolderData(URI.parse('foo:bar3'), 0)] });
		sub.dispose();
		finish();
	});

	test('Multiroot change keeps existing workspaces live', function () {
		let ws = new ExtHostWorkspace(new TestRPCProtocol(), { id: 'foo', name: 'Test', folders: [aWorkspaceFolderData(URI.parse('foo:bar'), 0)] }, new NullLogService(), new Counter());

		let firstFolder = ws.getWorkspaceFolders()[0];
		ws.$acceptWorkspaceData({ id: 'foo', name: 'Test', folders: [aWorkspaceFolderData(URI.parse('foo:bar2'), 0), aWorkspaceFolderData(URI.parse('foo:bar'), 1, 'renamed')] });

		assert.equal(ws.getWorkspaceFolders()[1], firstFolder);
		assert.equal(firstFolder.index, 1);
		assert.equal(firstFolder.name, 'renamed');

		ws.$acceptWorkspaceData({ id: 'foo', name: 'Test', folders: [aWorkspaceFolderData(URI.parse('foo:bar3'), 0), aWorkspaceFolderData(URI.parse('foo:bar2'), 1), aWorkspaceFolderData(URI.parse('foo:bar'), 2)] });
		assert.equal(ws.getWorkspaceFolders()[2], firstFolder);
		assert.equal(firstFolder.index, 2);

		ws.$acceptWorkspaceData({ id: 'foo', name: 'Test', folders: [aWorkspaceFolderData(URI.parse('foo:bar3'), 0)] });
		ws.$acceptWorkspaceData({ id: 'foo', name: 'Test', folders: [aWorkspaceFolderData(URI.parse('foo:bar3'), 0), aWorkspaceFolderData(URI.parse('foo:bar'), 1)] });

		assert.notEqual(firstFolder, ws.workspace.folders[0]);
	});

	test('updateWorkspaceFolders - invalid arguments', function () {
		let ws = new ExtHostWorkspace(new TestRPCProtocol(), { id: 'foo', name: 'Test', folders: [] }, new NullLogService(), new Counter());

		assert.equal(false, ws.updateWorkspaceFolders(extensionDescriptor, null, null));
		assert.equal(false, ws.updateWorkspaceFolders(extensionDescriptor, 0, 0));
		assert.equal(false, ws.updateWorkspaceFolders(extensionDescriptor, 0, 1));
		assert.equal(false, ws.updateWorkspaceFolders(extensionDescriptor, 1, 0));
		assert.equal(false, ws.updateWorkspaceFolders(extensionDescriptor, -1, 0));
		assert.equal(false, ws.updateWorkspaceFolders(extensionDescriptor, -1, -1));

		ws = new ExtHostWorkspace(new TestRPCProtocol(), { id: 'foo', name: 'Test', folders: [aWorkspaceFolderData(URI.parse('foo:bar'), 0)] }, new NullLogService(), new Counter());

		assert.equal(false, ws.updateWorkspaceFolders(extensionDescriptor, 1, 1));
		assert.equal(false, ws.updateWorkspaceFolders(extensionDescriptor, 0, 2));
		assert.equal(false, ws.updateWorkspaceFolders(extensionDescriptor, 0, 1, asUpdateWorkspaceFolderData(URI.parse('foo:bar'))));
	});

	test('updateWorkspaceFolders - valid arguments', function (done) {
		let finished = false;
		const finish = (error?: any) => {
			if (!finished) {
				finished = true;
				done(error);
			}
		};

		const protocol: IMainContext = {
			getProxy: () => { return undefined; },
			set: undefined,
			assertRegistered: undefined
		};

		const ws = new ExtHostWorkspace(protocol, { id: 'foo', name: 'Test', folders: [] }, new NullLogService(), new Counter());

		//
		// Add one folder
		//

		assert.equal(true, ws.updateWorkspaceFolders(extensionDescriptor, 0, 0, asUpdateWorkspaceFolderData(URI.parse('foo:bar'))));
		assert.equal(1, ws.workspace.folders.length);
		assert.equal(ws.workspace.folders[0].uri.toString(), URI.parse('foo:bar').toString());

		const firstAddedFolder = ws.getWorkspaceFolders()[0];

		let gotEvent = false;
		let sub = ws.onDidChangeWorkspace(e => {
			try {
				assert.deepEqual(e.removed, []);
				assert.equal(e.added.length, 1);
				assert.equal(e.added[0].uri.toString(), 'foo:bar');
				assert.equal(e.added[0], firstAddedFolder); // verify object is still live
				gotEvent = true;
			} catch (error) {
				finish(error);
			}
		});
		ws.$acceptWorkspaceData({ id: 'foo', name: 'Test', folders: [aWorkspaceFolderData(URI.parse('foo:bar'), 0)] }); // simulate acknowledgement from main side
		assert.equal(gotEvent, true);
		sub.dispose();
		assert.equal(ws.getWorkspaceFolders()[0], firstAddedFolder); // verify object is still live

		//
		// Add two more folders
		//

		assert.equal(true, ws.updateWorkspaceFolders(extensionDescriptor, 1, 0, asUpdateWorkspaceFolderData(URI.parse('foo:bar1')), asUpdateWorkspaceFolderData(URI.parse('foo:bar2'))));
		assert.equal(3, ws.workspace.folders.length);
		assert.equal(ws.workspace.folders[0].uri.toString(), URI.parse('foo:bar').toString());
		assert.equal(ws.workspace.folders[1].uri.toString(), URI.parse('foo:bar1').toString());
		assert.equal(ws.workspace.folders[2].uri.toString(), URI.parse('foo:bar2').toString());

		const secondAddedFolder = ws.getWorkspaceFolders()[1];
		const thirdAddedFolder = ws.getWorkspaceFolders()[2];

		gotEvent = false;
		sub = ws.onDidChangeWorkspace(e => {
			try {
				assert.deepEqual(e.removed, []);
				assert.equal(e.added.length, 2);
				assert.equal(e.added[0].uri.toString(), 'foo:bar1');
				assert.equal(e.added[1].uri.toString(), 'foo:bar2');
				assert.equal(e.added[0], secondAddedFolder);
				assert.equal(e.added[1], thirdAddedFolder);
				gotEvent = true;
			} catch (error) {
				finish(error);
			}
		});
		ws.$acceptWorkspaceData({ id: 'foo', name: 'Test', folders: [aWorkspaceFolderData(URI.parse('foo:bar'), 0), aWorkspaceFolderData(URI.parse('foo:bar1'), 1), aWorkspaceFolderData(URI.parse('foo:bar2'), 2)] }); // simulate acknowledgement from main side
		assert.equal(gotEvent, true);
		sub.dispose();
		assert.equal(ws.getWorkspaceFolders()[0], firstAddedFolder); // verify object is still live
		assert.equal(ws.getWorkspaceFolders()[1], secondAddedFolder); // verify object is still live
		assert.equal(ws.getWorkspaceFolders()[2], thirdAddedFolder); // verify object is still live

		//
		// Remove one folder
		//

		assert.equal(true, ws.updateWorkspaceFolders(extensionDescriptor, 2, 1));
		assert.equal(2, ws.workspace.folders.length);
		assert.equal(ws.workspace.folders[0].uri.toString(), URI.parse('foo:bar').toString());
		assert.equal(ws.workspace.folders[1].uri.toString(), URI.parse('foo:bar1').toString());

		gotEvent = false;
		sub = ws.onDidChangeWorkspace(e => {
			try {
				assert.deepEqual(e.added, []);
				assert.equal(e.removed.length, 1);
				assert.equal(e.removed[0], thirdAddedFolder);
				gotEvent = true;
			} catch (error) {
				finish(error);
			}
		});
		ws.$acceptWorkspaceData({ id: 'foo', name: 'Test', folders: [aWorkspaceFolderData(URI.parse('foo:bar'), 0), aWorkspaceFolderData(URI.parse('foo:bar1'), 1)] }); // simulate acknowledgement from main side
		assert.equal(gotEvent, true);
		sub.dispose();
		assert.equal(ws.getWorkspaceFolders()[0], firstAddedFolder); // verify object is still live
		assert.equal(ws.getWorkspaceFolders()[1], secondAddedFolder); // verify object is still live

		//
		// Rename folder
		//

		assert.equal(true, ws.updateWorkspaceFolders(extensionDescriptor, 0, 2, asUpdateWorkspaceFolderData(URI.parse('foo:bar'), 'renamed 1'), asUpdateWorkspaceFolderData(URI.parse('foo:bar1'), 'renamed 2')));
		assert.equal(2, ws.workspace.folders.length);
		assert.equal(ws.workspace.folders[0].uri.toString(), URI.parse('foo:bar').toString());
		assert.equal(ws.workspace.folders[1].uri.toString(), URI.parse('foo:bar1').toString());
		assert.equal(ws.workspace.folders[0].name, 'renamed 1');
		assert.equal(ws.workspace.folders[1].name, 'renamed 2');
		assert.equal(ws.getWorkspaceFolders()[0].name, 'renamed 1');
		assert.equal(ws.getWorkspaceFolders()[1].name, 'renamed 2');

		gotEvent = false;
		sub = ws.onDidChangeWorkspace(e => {
			try {
				assert.deepEqual(e.added, []);
				assert.equal(e.removed.length, []);
				gotEvent = true;
			} catch (error) {
				finish(error);
			}
		});
		ws.$acceptWorkspaceData({ id: 'foo', name: 'Test', folders: [aWorkspaceFolderData(URI.parse('foo:bar'), 0, 'renamed 1'), aWorkspaceFolderData(URI.parse('foo:bar1'), 1, 'renamed 2')] }); // simulate acknowledgement from main side
		assert.equal(gotEvent, true);
		sub.dispose();
		assert.equal(ws.getWorkspaceFolders()[0], firstAddedFolder); // verify object is still live
		assert.equal(ws.getWorkspaceFolders()[1], secondAddedFolder); // verify object is still live
		assert.equal(ws.workspace.folders[0].name, 'renamed 1');
		assert.equal(ws.workspace.folders[1].name, 'renamed 2');
		assert.equal(ws.getWorkspaceFolders()[0].name, 'renamed 1');
		assert.equal(ws.getWorkspaceFolders()[1].name, 'renamed 2');

		//
		// Add and remove folders
		//

		assert.equal(true, ws.updateWorkspaceFolders(extensionDescriptor, 0, 2, asUpdateWorkspaceFolderData(URI.parse('foo:bar3')), asUpdateWorkspaceFolderData(URI.parse('foo:bar4'))));
		assert.equal(2, ws.workspace.folders.length);
		assert.equal(ws.workspace.folders[0].uri.toString(), URI.parse('foo:bar3').toString());
		assert.equal(ws.workspace.folders[1].uri.toString(), URI.parse('foo:bar4').toString());

		const fourthAddedFolder = ws.getWorkspaceFolders()[0];
		const fifthAddedFolder = ws.getWorkspaceFolders()[1];

		gotEvent = false;
		sub = ws.onDidChangeWorkspace(e => {
			try {
				assert.equal(e.added.length, 2);
				assert.equal(e.added[0], fourthAddedFolder);
				assert.equal(e.added[1], fifthAddedFolder);
				assert.equal(e.removed.length, 2);
				assert.equal(e.removed[0], firstAddedFolder);
				assert.equal(e.removed[1], secondAddedFolder);
				gotEvent = true;
			} catch (error) {
				finish(error);
			}
		});
		ws.$acceptWorkspaceData({ id: 'foo', name: 'Test', folders: [aWorkspaceFolderData(URI.parse('foo:bar3'), 0), aWorkspaceFolderData(URI.parse('foo:bar4'), 1)] }); // simulate acknowledgement from main side
		assert.equal(gotEvent, true);
		sub.dispose();
		assert.equal(ws.getWorkspaceFolders()[0], fourthAddedFolder); // verify object is still live
		assert.equal(ws.getWorkspaceFolders()[1], fifthAddedFolder); // verify object is still live

		//
		// Swap folders
		//

		assert.equal(true, ws.updateWorkspaceFolders(extensionDescriptor, 0, 2, asUpdateWorkspaceFolderData(URI.parse('foo:bar4')), asUpdateWorkspaceFolderData(URI.parse('foo:bar3'))));
		assert.equal(2, ws.workspace.folders.length);
		assert.equal(ws.workspace.folders[0].uri.toString(), URI.parse('foo:bar4').toString());
		assert.equal(ws.workspace.folders[1].uri.toString(), URI.parse('foo:bar3').toString());

		assert.equal(ws.getWorkspaceFolders()[0], fifthAddedFolder); // verify object is still live
		assert.equal(ws.getWorkspaceFolders()[1], fourthAddedFolder); // verify object is still live

		gotEvent = false;
		sub = ws.onDidChangeWorkspace(e => {
			try {
				assert.equal(e.added.length, 0);
				assert.equal(e.removed.length, 0);
				gotEvent = true;
			} catch (error) {
				finish(error);
			}
		});
		ws.$acceptWorkspaceData({ id: 'foo', name: 'Test', folders: [aWorkspaceFolderData(URI.parse('foo:bar4'), 0), aWorkspaceFolderData(URI.parse('foo:bar3'), 1)] }); // simulate acknowledgement from main side
		assert.equal(gotEvent, true);
		sub.dispose();
		assert.equal(ws.getWorkspaceFolders()[0], fifthAddedFolder); // verify object is still live
		assert.equal(ws.getWorkspaceFolders()[1], fourthAddedFolder); // verify object is still live
		assert.equal(fifthAddedFolder.index, 0);
		assert.equal(fourthAddedFolder.index, 1);

		//
		// Add one folder after the other without waiting for confirmation (not supported currently)
		//

		assert.equal(true, ws.updateWorkspaceFolders(extensionDescriptor, 2, 0, asUpdateWorkspaceFolderData(URI.parse('foo:bar5'))));

		assert.equal(3, ws.workspace.folders.length);
		assert.equal(ws.workspace.folders[0].uri.toString(), URI.parse('foo:bar4').toString());
		assert.equal(ws.workspace.folders[1].uri.toString(), URI.parse('foo:bar3').toString());
		assert.equal(ws.workspace.folders[2].uri.toString(), URI.parse('foo:bar5').toString());

		const sixthAddedFolder = ws.getWorkspaceFolders()[2];

		gotEvent = false;
		sub = ws.onDidChangeWorkspace(e => {
			try {
				assert.equal(e.added.length, 1);
				assert.equal(e.added[0], sixthAddedFolder);
				gotEvent = true;
			} catch (error) {
				finish(error);
			}
		});
		ws.$acceptWorkspaceData({
			id: 'foo', name: 'Test', folders: [
				aWorkspaceFolderData(URI.parse('foo:bar4'), 0),
				aWorkspaceFolderData(URI.parse('foo:bar3'), 1),
				aWorkspaceFolderData(URI.parse('foo:bar5'), 2)
			]
		}); // simulate acknowledgement from main side
		assert.equal(gotEvent, true);
		sub.dispose();

		assert.equal(ws.getWorkspaceFolders()[0], fifthAddedFolder); // verify object is still live
		assert.equal(ws.getWorkspaceFolders()[1], fourthAddedFolder); // verify object is still live
		assert.equal(ws.getWorkspaceFolders()[2], sixthAddedFolder); // verify object is still live

		finish();
	});

	test('Multiroot change event is immutable', function (done) {
		let finished = false;
		const finish = (error?: any) => {
			if (!finished) {
				finished = true;
				done(error);
			}
		};

		let ws = new ExtHostWorkspace(new TestRPCProtocol(), { id: 'foo', name: 'Test', folders: [] }, new NullLogService(), new Counter());
		let sub = ws.onDidChangeWorkspace(e => {
			try {
				assert.throws(() => {
					(<any>e).added = [];
				});
				// assert.throws(() => {
				// 	(<any>e.added)[0] = null;
				// });
			} catch (error) {
				finish(error);
			}
		});
		ws.$acceptWorkspaceData({ id: 'foo', name: 'Test', folders: [] });
		sub.dispose();
		finish();
	});

	test('`vscode.workspace.getWorkspaceFolder(file)` don\'t return workspace folder when file open from command line. #36221', function () {
		let ws = new ExtHostWorkspace(new TestRPCProtocol(), {
			id: 'foo', name: 'Test', folders: [
				aWorkspaceFolderData(URI.file('c:/Users/marek/Desktop/vsc_test/'), 0)
			]
		}, new NullLogService(), new Counter());

		assert.ok(ws.getWorkspaceFolder(URI.file('c:/Users/marek/Desktop/vsc_test/a.txt')));
		assert.ok(ws.getWorkspaceFolder(URI.file('C:/Users/marek/Desktop/vsc_test/b.txt')));
	});

	function aWorkspaceFolderData(uri: URI, index: number, name: string = ''): IWorkspaceFolderData {
		return {
			uri,
			index,
			name: name || basename(uri.path)
		};
	}

	function asUpdateWorkspaceFolderData(uri: URI, name?: string): { uri: URI, name?: string } {
		return { uri, name };
	}
});
