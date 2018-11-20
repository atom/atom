/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import * as assert from 'assert';
import { TPromise } from 'vs/base/common/winjs.base';
import { IInstantiationService } from 'vs/platform/instantiation/common/instantiation';
import { EncodingMode } from 'vs/workbench/common/editor';
import { TextFileEditorModel, SaveSequentializer } from 'vs/workbench/services/textfile/common/textFileEditorModel';
import { ITextFileService, ModelState, StateChange } from 'vs/workbench/services/textfile/common/textfiles';
import { workbenchInstantiationService, TestTextFileService, createFileInput, TestFileService } from 'vs/workbench/test/workbenchTestServices';
import { toResource } from 'vs/base/test/common/utils';
import { TextFileEditorModelManager } from 'vs/workbench/services/textfile/common/textFileEditorModelManager';
import { FileOperationResult, FileOperationError, IFileService, snapshotToString } from 'vs/platform/files/common/files';
import { IModelService } from 'vs/editor/common/services/modelService';
import { timeout as thenableTimeout } from 'vs/base/common/async';

function timeout(n: number) {
	return TPromise.wrap(thenableTimeout(n));
}

class ServiceAccessor {
	constructor(@ITextFileService public textFileService: TestTextFileService, @IModelService public modelService: IModelService, @IFileService public fileService: TestFileService) {
	}
}

function getLastModifiedTime(model: TextFileEditorModel): number {
	const stat = model.getStat();

	return stat ? stat.mtime : -1;
}

suite('Files - TextFileEditorModel', () => {

	let instantiationService: IInstantiationService;
	let accessor: ServiceAccessor;
	let content: string;

	setup(() => {
		instantiationService = workbenchInstantiationService();
		accessor = instantiationService.createInstance(ServiceAccessor);
		content = accessor.fileService.getContent();
	});

	teardown(() => {
		(<TextFileEditorModelManager>accessor.textFileService.models).clear();
		TextFileEditorModel.setSaveParticipant(null); // reset any set participant
		accessor.fileService.setContent(content);
	});

	test('Save', function () {
		const model: TextFileEditorModel = instantiationService.createInstance(TextFileEditorModel, toResource.call(this, '/path/index_async.txt'), 'utf8');

		return model.load().then(() => {
			model.textEditorModel.setValue('bar');
			assert.ok(getLastModifiedTime(model) <= Date.now());

			return model.save().then(() => {
				assert.ok(model.getLastSaveAttemptTime() <= Date.now());
				assert.ok(!model.isDirty());

				model.dispose();
				assert.ok(!accessor.modelService.getModel(model.getResource()));
			});
		});
	});

	test('setEncoding - encode', function () {
		const model: TextFileEditorModel = instantiationService.createInstance(TextFileEditorModel, toResource.call(this, '/path/index_async.txt'), 'utf8');

		model.setEncoding('utf8', EncodingMode.Encode); // no-op
		assert.equal(getLastModifiedTime(model), -1);

		model.setEncoding('utf16', EncodingMode.Encode);

		assert.ok(getLastModifiedTime(model) <= Date.now()); // indicates model was saved due to encoding change

		model.dispose();
	});

	test('setEncoding - decode', function () {
		const model: TextFileEditorModel = instantiationService.createInstance(TextFileEditorModel, toResource.call(this, '/path/index_async.txt'), 'utf8');

		model.setEncoding('utf16', EncodingMode.Decode);

		assert.ok(model.isResolved()); // model got loaded due to decoding

		model.dispose();
	});

	test('disposes when underlying model is destroyed', function () {
		const model: TextFileEditorModel = instantiationService.createInstance(TextFileEditorModel, toResource.call(this, '/path/index_async.txt'), 'utf8');

		return model.load().then(() => {
			model.textEditorModel.dispose();

			assert.ok(model.isDisposed());
		});
	});

	test('Load does not trigger save', function () {
		const model = instantiationService.createInstance(TextFileEditorModel, toResource.call(this, '/path/index.txt'), 'utf8');
		assert.ok(model.hasState(ModelState.SAVED));

		model.onDidStateChange(e => {
			assert.ok(e !== StateChange.DIRTY && e !== StateChange.SAVED);
		});

		return model.load().then(() => {
			assert.ok(model.isResolved());

			model.dispose();

			assert.ok(!accessor.modelService.getModel(model.getResource()));
		});
	});

	test('Load returns dirty model as long as model is dirty', function () {
		const model = instantiationService.createInstance(TextFileEditorModel, toResource.call(this, '/path/index_async.txt'), 'utf8');

		return model.load().then(() => {
			model.textEditorModel.setValue('foo');

			assert.ok(model.isDirty());
			assert.ok(model.hasState(ModelState.DIRTY));
			return model.load().then(() => {
				assert.ok(model.isDirty());

				model.dispose();
			});
		});
	});

	test('Revert', function () {
		let eventCounter = 0;

		const model = instantiationService.createInstance(TextFileEditorModel, toResource.call(this, '/path/index_async.txt'), 'utf8');

		model.onDidStateChange(e => {
			if (e === StateChange.REVERTED) {
				eventCounter++;
			}
		});

		return model.load().then(() => {
			model.textEditorModel.setValue('foo');

			assert.ok(model.isDirty());

			return model.revert().then(() => {
				assert.ok(!model.isDirty());
				assert.equal(model.textEditorModel.getValue(), 'Hello Html');
				assert.equal(eventCounter, 1);

				model.dispose();
			});
		});
	});

	test('Revert (soft)', function () {
		let eventCounter = 0;

		const model = instantiationService.createInstance(TextFileEditorModel, toResource.call(this, '/path/index_async.txt'), 'utf8');

		model.onDidStateChange(e => {
			if (e === StateChange.REVERTED) {
				eventCounter++;
			}
		});

		return model.load().then(() => {
			model.textEditorModel.setValue('foo');

			assert.ok(model.isDirty());

			return model.revert(true /* soft revert */).then(() => {
				assert.ok(!model.isDirty());
				assert.equal(model.textEditorModel.getValue(), 'foo');
				assert.equal(eventCounter, 1);

				model.dispose();
			});
		});
	});

	test('Load and undo turns model dirty', function () {
		const model: TextFileEditorModel = instantiationService.createInstance(TextFileEditorModel, toResource.call(this, '/path/index_async.txt'), 'utf8');
		return model.load().then(() => {
			accessor.fileService.setContent('Hello Change');
			return model.load().then(() => {
				model.textEditorModel.undo();

				assert.ok(model.isDirty());
			});
		});
	});

	test('File not modified error is handled gracefully', function () {
		const model: TextFileEditorModel = instantiationService.createInstance(TextFileEditorModel, toResource.call(this, '/path/index_async.txt'), 'utf8');

		return model.load().then(() => {
			const mtime = getLastModifiedTime(model);
			accessor.textFileService.setResolveTextContentErrorOnce(new FileOperationError('error', FileOperationResult.FILE_NOT_MODIFIED_SINCE));

			return model.load().then((model: TextFileEditorModel) => {
				assert.ok(model);
				assert.equal(getLastModifiedTime(model), mtime);
				model.dispose();
			});
		});
	});

	test('Load error is handled gracefully if model already exists', function () {
		const model: TextFileEditorModel = instantiationService.createInstance(TextFileEditorModel, toResource.call(this, '/path/index_async.txt'), 'utf8');

		return model.load().then(() => {
			accessor.textFileService.setResolveTextContentErrorOnce(new FileOperationError('error', FileOperationResult.FILE_NOT_FOUND));

			return model.load().then((model: TextFileEditorModel) => {
				assert.ok(model);
				model.dispose();
			});
		});
	});

	test('save() and isDirty() - proper with check for mtimes', function () {
		const input1 = createFileInput(instantiationService, toResource.call(this, '/path/index_async2.txt'));
		const input2 = createFileInput(instantiationService, toResource.call(this, '/path/index_async.txt'));

		return input1.resolve().then((model1: TextFileEditorModel) => {
			return input2.resolve().then((model2: TextFileEditorModel) => {
				model1.textEditorModel.setValue('foo');

				const m1Mtime = model1.getStat().mtime;
				const m2Mtime = model2.getStat().mtime;
				assert.ok(m1Mtime > 0);
				assert.ok(m2Mtime > 0);

				assert.ok(accessor.textFileService.isDirty());
				assert.ok(accessor.textFileService.isDirty(toResource.call(this, '/path/index_async2.txt')));
				assert.ok(!accessor.textFileService.isDirty(toResource.call(this, '/path/index_async.txt')));

				model2.textEditorModel.setValue('foo');
				assert.ok(accessor.textFileService.isDirty(toResource.call(this, '/path/index_async.txt')));

				return timeout(10).then(() => {
					accessor.textFileService.saveAll().then(() => {
						assert.ok(!accessor.textFileService.isDirty(toResource.call(this, '/path/index_async.txt')));
						assert.ok(!accessor.textFileService.isDirty(toResource.call(this, '/path/index_async2.txt')));
						assert.ok(model1.getStat().mtime > m1Mtime);
						assert.ok(model2.getStat().mtime > m2Mtime);
						assert.ok(model1.getLastSaveAttemptTime() > m1Mtime);
						assert.ok(model2.getLastSaveAttemptTime() > m2Mtime);

						model1.dispose();
						model2.dispose();
					});
				});
			});
		});
	});

	test('Save Participant', function () {
		let eventCounter = 0;
		const model: TextFileEditorModel = instantiationService.createInstance(TextFileEditorModel, toResource.call(this, '/path/index_async.txt'), 'utf8');

		model.onDidStateChange(e => {
			if (e === StateChange.SAVED) {
				assert.equal(snapshotToString(model.createSnapshot()), 'bar');
				assert.ok(!model.isDirty());
				eventCounter++;
			}
		});

		TextFileEditorModel.setSaveParticipant({
			participate: (model) => {
				assert.ok(model.isDirty());
				model.textEditorModel.setValue('bar');
				assert.ok(model.isDirty());
				eventCounter++;
				return undefined;
			}
		});

		return model.load().then(() => {
			model.textEditorModel.setValue('foo');

			return model.save().then(() => {
				model.dispose();

				assert.equal(eventCounter, 2);
			});
		});
	});

	test('Save Participant, async participant', function () {

		const model: TextFileEditorModel = instantiationService.createInstance(TextFileEditorModel, toResource.call(this, '/path/index_async.txt'), 'utf8');

		TextFileEditorModel.setSaveParticipant({
			participate: (model) => {
				return timeout(10);
			}
		});

		return model.load().then(() => {
			model.textEditorModel.setValue('foo');

			const now = Date.now();
			return model.save().then(() => {
				assert.ok(Date.now() - now >= 10);
				model.dispose();
			});
		});
	});

	test('Save Participant, bad participant', function () {
		const model: TextFileEditorModel = instantiationService.createInstance(TextFileEditorModel, toResource.call(this, '/path/index_async.txt'), 'utf8');

		TextFileEditorModel.setSaveParticipant({
			participate: (model) => {
				return TPromise.wrapError(new Error('boom'));
			}
		});

		return model.load().then(() => {
			model.textEditorModel.setValue('foo');
			return model.save().then(() => {
				model.dispose();
			});
		});
	});

	test('SaveSequentializer - pending basics', function () {
		const sequentializer = new SaveSequentializer();

		assert.ok(!sequentializer.hasPendingSave());
		assert.ok(!sequentializer.hasPendingSave(2323));
		assert.ok(!sequentializer.pendingSave);

		// pending removes itself after done
		sequentializer.setPending(1, TPromise.as(null));
		assert.ok(!sequentializer.hasPendingSave());
		assert.ok(!sequentializer.hasPendingSave(1));
		assert.ok(!sequentializer.pendingSave);

		// pending removes itself after done (use timeout)
		sequentializer.setPending(2, timeout(1));
		assert.ok(sequentializer.hasPendingSave());
		assert.ok(sequentializer.hasPendingSave(2));
		assert.ok(!sequentializer.hasPendingSave(1));
		assert.ok(sequentializer.pendingSave);

		return timeout(2).then(() => {
			assert.ok(!sequentializer.hasPendingSave());
			assert.ok(!sequentializer.hasPendingSave(2));
			assert.ok(!sequentializer.pendingSave);
		});
	});

	test('SaveSequentializer - pending and next (finishes instantly)', function () {
		const sequentializer = new SaveSequentializer();

		let pendingDone = false;
		sequentializer.setPending(1, timeout(1).then(() => { pendingDone = true; return null; }));

		// next finishes instantly
		let nextDone = false;
		const res = sequentializer.setNext(() => TPromise.as(null).then(() => { nextDone = true; return null; }));

		return res.then(() => {
			assert.ok(pendingDone);
			assert.ok(nextDone);
		});
	});

	test('SaveSequentializer - pending and next (finishes after timeout)', function () {
		const sequentializer = new SaveSequentializer();

		let pendingDone = false;
		sequentializer.setPending(1, timeout(1).then(() => { pendingDone = true; return null; }));

		// next finishes after timeout
		let nextDone = false;
		const res = sequentializer.setNext(() => timeout(1).then(() => { nextDone = true; return null; }));

		return res.then(() => {
			assert.ok(pendingDone);
			assert.ok(nextDone);
		});
	});

	test('SaveSequentializer - pending and multiple next (last one wins)', function () {
		const sequentializer = new SaveSequentializer();

		let pendingDone = false;
		sequentializer.setPending(1, timeout(1).then(() => { pendingDone = true; return null; }));

		// next finishes after timeout
		let firstDone = false;
		let firstRes = sequentializer.setNext(() => timeout(2).then(() => { firstDone = true; return null; }));

		let secondDone = false;
		let secondRes = sequentializer.setNext(() => timeout(3).then(() => { secondDone = true; return null; }));

		let thirdDone = false;
		let thirdRes = sequentializer.setNext(() => timeout(4).then(() => { thirdDone = true; return null; }));

		return TPromise.join([firstRes, secondRes, thirdRes]).then(() => {
			assert.ok(pendingDone);
			assert.ok(!firstDone);
			assert.ok(!secondDone);
			assert.ok(thirdDone);
		});
	});
});
