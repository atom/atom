import path from 'path';
import fs from 'fs-extra';
import React from 'react';
import {shallow} from 'enzyme';

import MultiFilePatchController from '../../lib/controllers/multi-file-patch-controller';
import MultiFilePatch from '../../lib/models/patch/multi-file-patch';
import * as reporterProxy from '../../lib/reporter-proxy';
import {multiFilePatchBuilder} from '../builder/patch';
import {cloneRepository, buildRepository} from '../helpers';
import CommitPreviewItem from '../../lib/items/commit-preview-item';

describe('MultiFilePatchController', function() {
  let atomEnv, repository, multiFilePatch, filePatch;

  beforeEach(async function() {
    atomEnv = global.buildAtomEnvironment();

    const workdirPath = await cloneRepository();
    repository = await buildRepository(workdirPath);

    // a.txt: unstaged changes
    const filePath = 'a.txt';
    await fs.writeFile(path.join(workdirPath, filePath), '00\n01\n02\n03\n04\n05\n06');

    multiFilePatch = await repository.getFilePatchForPath(filePath);
    [filePatch] = multiFilePatch.getFilePatches();
  });

  afterEach(function() {
    atomEnv.destroy();
  });

  function buildApp(overrideProps = {}) {
    const props = {
      repository,
      stagingStatus: 'unstaged',
      multiFilePatch,
      hasUndoHistory: false,
      workspace: atomEnv.workspace,
      commands: atomEnv.commands,
      keymaps: atomEnv.keymaps,
      tooltips: atomEnv.tooltips,
      config: atomEnv.config,
      destroy: () => {},
      discardLines: () => {},
      undoLastDiscard: () => {},
      surface: () => {},
      itemType: CommitPreviewItem,
      ...overrideProps,
    };

    return <MultiFilePatchController {...props} />;
  }

  it('passes extra props to the FilePatchView', function() {
    const extra = Symbol('extra');
    const wrapper = shallow(buildApp({extra}));

    assert.strictEqual(wrapper.find('MultiFilePatchView').prop('extra'), extra);
  });

  it('calls undoLastDiscard through with set arguments', function() {
    const undoLastDiscard = sinon.spy();
    const wrapper = shallow(buildApp({undoLastDiscard, stagingStatus: 'staged'}));

    wrapper.find('MultiFilePatchView').prop('undoLastDiscard')(filePatch);

    assert.isTrue(undoLastDiscard.calledWith(filePatch.getPath(), repository));
  });

  describe('diveIntoMirrorPatch()', function() {
    it('destroys the current pane and opens the staged changes', async function() {
      const destroy = sinon.spy();
      sinon.stub(atomEnv.workspace, 'open').resolves();
      const wrapper = shallow(buildApp({stagingStatus: 'unstaged', destroy}));

      await wrapper.find('MultiFilePatchView').prop('diveIntoMirrorPatch')(filePatch);

      assert.isTrue(destroy.called);
      assert.isTrue(atomEnv.workspace.open.calledWith(
        `atom-github://file-patch/${filePatch.getPath()}` +
        `?workdir=${encodeURIComponent(repository.getWorkingDirectoryPath())}&stagingStatus=staged`,
      ));
    });

    it('destroys the current pane and opens the unstaged changes', async function() {
      const destroy = sinon.spy();
      sinon.stub(atomEnv.workspace, 'open').resolves();
      const wrapper = shallow(buildApp({stagingStatus: 'staged', destroy}));


      await wrapper.find('MultiFilePatchView').prop('diveIntoMirrorPatch')(filePatch);

      assert.isTrue(destroy.called);
      assert.isTrue(atomEnv.workspace.open.calledWith(
        `atom-github://file-patch/${filePatch.getPath()}` +
        `?workdir=${encodeURIComponent(repository.getWorkingDirectoryPath())}&stagingStatus=unstaged`,
      ));
    });
  });

  describe('openFile()', function() {
    it('opens an editor on the current file', async function() {
      const wrapper = shallow(buildApp({stagingStatus: 'unstaged'}));
      const editor = await wrapper.find('MultiFilePatchView').prop('openFile')(filePatch, []);

      assert.strictEqual(editor.getPath(), path.join(repository.getWorkingDirectoryPath(), filePatch.getPath()));
    });

    it('sets the cursor to a single position', async function() {
      const wrapper = shallow(buildApp({relPath: 'a.txt', stagingStatus: 'unstaged'}));
      const editor = await wrapper.find('MultiFilePatchView').prop('openFile')(filePatch, [[1, 1]]);

      assert.deepEqual(editor.getCursorBufferPositions().map(p => p.serialize()), [[1, 1]]);
    });

    it('adds cursors at a set of positions', async function() {
      const wrapper = shallow(buildApp({stagingStatus: 'unstaged'}));
      const editor = await wrapper.find('MultiFilePatchView').prop('openFile')(filePatch, [[1, 1], [3, 1], [5, 0]]);

      assert.deepEqual(editor.getCursorBufferPositions().map(p => p.serialize()), [[1, 1], [3, 1], [5, 0]]);
    });
  });

  describe('toggleFile()', function() {
    it('stages the current file if unstaged', async function() {
      sinon.spy(repository, 'stageFiles');
      const wrapper = shallow(buildApp({stagingStatus: 'unstaged'}));

      await wrapper.find('MultiFilePatchView').prop('toggleFile')(filePatch);

      assert.isTrue(repository.stageFiles.calledWith([filePatch.getPath()]));
    });

    it('unstages the current file if staged', async function() {
      sinon.spy(repository, 'unstageFiles');
      const wrapper = shallow(buildApp({stagingStatus: 'staged'}));

      await wrapper.find('MultiFilePatchView').prop('toggleFile')(filePatch);

      assert.isTrue(repository.unstageFiles.calledWith([filePatch.getPath()]));
    });

    it('is a no-op if a staging operation is already in progress', async function() {
      sinon.stub(repository, 'stageFiles').resolves('staged');
      sinon.stub(repository, 'unstageFiles').resolves('unstaged');

      const wrapper = shallow(buildApp({stagingStatus: 'unstaged'}));
      assert.strictEqual(await wrapper.find('MultiFilePatchView').prop('toggleFile')(filePatch), 'staged');

      // No-op
      assert.isNull(await wrapper.find('MultiFilePatchView').prop('toggleFile')(filePatch));

      // Simulate an identical patch arriving too soon
      wrapper.setProps({multiFilePatch: multiFilePatch.clone()});

      // Still a no-op
      assert.isNull(await wrapper.find('MultiFilePatchView').prop('toggleFile')(filePatch));

      // Simulate updated patch arrival
      const promise = wrapper.instance().patchChangePromise;
      wrapper.setProps({multiFilePatch: MultiFilePatch.createNull()});
      await promise;

      // Performs an operation again
      assert.strictEqual(await wrapper.find('MultiFilePatchView').prop('toggleFile')(filePatch), 'staged');
    });
  });

  describe('selected row and selection mode tracking', function() {
    it('captures the selected row set', function() {
      const wrapper = shallow(buildApp());
      assert.sameMembers(Array.from(wrapper.find('MultiFilePatchView').prop('selectedRows')), []);
      assert.strictEqual(wrapper.find('MultiFilePatchView').prop('selectionMode'), 'hunk');
      assert.isFalse(wrapper.find('MultiFilePatchView').prop('hasMultipleFileSelections'));

      wrapper.find('MultiFilePatchView').prop('selectedRowsChanged')(new Set([1, 2]), 'line', true);
      assert.sameMembers(Array.from(wrapper.find('MultiFilePatchView').prop('selectedRows')), [1, 2]);
      assert.strictEqual(wrapper.find('MultiFilePatchView').prop('selectionMode'), 'line');
      assert.isTrue(wrapper.find('MultiFilePatchView').prop('hasMultipleFileSelections'));
    });

    it('does not re-render if the row set, selection mode, and file spanning are unchanged', function() {
      const wrapper = shallow(buildApp());
      assert.sameMembers(Array.from(wrapper.find('MultiFilePatchView').prop('selectedRows')), []);
      assert.strictEqual(wrapper.find('MultiFilePatchView').prop('selectionMode'), 'hunk');
      assert.isFalse(wrapper.find('MultiFilePatchView').prop('hasMultipleFileSelections'));

      sinon.spy(wrapper.instance(), 'render');

      // All changed
      wrapper.find('MultiFilePatchView').prop('selectedRowsChanged')(new Set([1, 2]), 'line', true);

      assert.isTrue(wrapper.instance().render.called);
      assert.sameMembers(Array.from(wrapper.find('MultiFilePatchView').prop('selectedRows')), [1, 2]);
      assert.strictEqual(wrapper.find('MultiFilePatchView').prop('selectionMode'), 'line');
      assert.isTrue(wrapper.find('MultiFilePatchView').prop('hasMultipleFileSelections'));

      // Nothing changed
      wrapper.instance().render.resetHistory();
      wrapper.find('MultiFilePatchView').prop('selectedRowsChanged')(new Set([2, 1]), 'line', true);

      assert.sameMembers(Array.from(wrapper.find('MultiFilePatchView').prop('selectedRows')), [1, 2]);
      assert.strictEqual(wrapper.find('MultiFilePatchView').prop('selectionMode'), 'line');
      assert.isTrue(wrapper.find('MultiFilePatchView').prop('hasMultipleFileSelections'));
      assert.isFalse(wrapper.instance().render.called);

      // Selection mode changed
      wrapper.instance().render.resetHistory();
      wrapper.find('MultiFilePatchView').prop('selectedRowsChanged')(new Set([1, 2]), 'hunk', true);

      assert.sameMembers(Array.from(wrapper.find('MultiFilePatchView').prop('selectedRows')), [1, 2]);
      assert.strictEqual(wrapper.find('MultiFilePatchView').prop('selectionMode'), 'hunk');
      assert.isTrue(wrapper.find('MultiFilePatchView').prop('hasMultipleFileSelections'));
      assert.isTrue(wrapper.instance().render.called);

      // Selection file spanning changed
      wrapper.instance().render.resetHistory();
      wrapper.find('MultiFilePatchView').prop('selectedRowsChanged')(new Set([1, 2]), 'hunk', false);

      assert.sameMembers(Array.from(wrapper.find('MultiFilePatchView').prop('selectedRows')), [1, 2]);
      assert.strictEqual(wrapper.find('MultiFilePatchView').prop('selectionMode'), 'hunk');
      assert.isFalse(wrapper.find('MultiFilePatchView').prop('hasMultipleFileSelections'));
      assert.isTrue(wrapper.instance().render.called);
    });

    describe('discardRows()', function() {
      it('records an event', async function() {
        const wrapper = shallow(buildApp());
        sinon.stub(reporterProxy, 'addEvent');
        await wrapper.find('MultiFilePatchView').prop('discardRows')(new Set([1, 2]), 'hunk');
        assert.isTrue(reporterProxy.addEvent.calledWith('discard-unstaged-changes', {
          package: 'github',
          component: 'MultiFilePatchController',
          lineCount: 2,
          eventSource: undefined,
        }));
      });

      it('is a no-op when multiple patches are present', async function() {
        const {multiFilePatch: mfp} = multiFilePatchBuilder()
          .addFilePatch()
          .addFilePatch()
          .build();
        const discardLines = sinon.spy();
        const wrapper = shallow(buildApp({discardLines, multiFilePatch: mfp}));
        sinon.stub(reporterProxy, 'addEvent');
        await wrapper.find('MultiFilePatchView').prop('discardRows')(new Set([1, 2]));
        assert.isFalse(reporterProxy.addEvent.called);
        assert.isFalse(discardLines.called);
      });
    });

    describe('undoLastDiscard()', function() {
      it('records an event', function() {
        const wrapper = shallow(buildApp());
        sinon.stub(reporterProxy, 'addEvent');
        wrapper.find('MultiFilePatchView').prop('undoLastDiscard')(filePatch);
        assert.isTrue(reporterProxy.addEvent.calledWith('undo-last-discard', {
          package: 'github',
          component: 'MultiFilePatchController',
          eventSource: undefined,
        }));
      });
    });
  });

  describe('toggleRows()', function() {
    it('is a no-op with no selected rows', async function() {
      const wrapper = shallow(buildApp());

      sinon.spy(repository, 'applyPatchToIndex');

      await wrapper.find('MultiFilePatchView').prop('toggleRows')();
      assert.isFalse(repository.applyPatchToIndex.called);
    });

    it('applies a stage patch to the index', async function() {
      const wrapper = shallow(buildApp());
      wrapper.find('MultiFilePatchView').prop('selectedRowsChanged')(new Set([1]), 'hunk', false);

      sinon.spy(multiFilePatch, 'getStagePatchForLines');
      sinon.spy(repository, 'applyPatchToIndex');

      await wrapper.find('MultiFilePatchView').prop('toggleRows')();

      assert.sameMembers(Array.from(multiFilePatch.getStagePatchForLines.lastCall.args[0]), [1]);
      assert.isTrue(repository.applyPatchToIndex.calledWith(multiFilePatch.getStagePatchForLines.returnValues[0]));
    });

    it('toggles a different row set if provided', async function() {
      const wrapper = shallow(buildApp());
      wrapper.find('MultiFilePatchView').prop('selectedRowsChanged')(new Set([1]), 'line', false);

      sinon.spy(multiFilePatch, 'getStagePatchForLines');
      sinon.spy(repository, 'applyPatchToIndex');

      await wrapper.find('MultiFilePatchView').prop('toggleRows')(new Set([2]), 'hunk');

      assert.sameMembers(Array.from(multiFilePatch.getStagePatchForLines.lastCall.args[0]), [2]);
      assert.isTrue(repository.applyPatchToIndex.calledWith(multiFilePatch.getStagePatchForLines.returnValues[0]));

      assert.sameMembers(Array.from(wrapper.find('MultiFilePatchView').prop('selectedRows')), [2]);
      assert.strictEqual(wrapper.find('MultiFilePatchView').prop('selectionMode'), 'hunk');
    });

    it('applies an unstage patch to the index', async function() {
      await repository.stageFiles(['a.txt']);
      const otherPatch = await repository.getFilePatchForPath('a.txt', {staged: true});
      const wrapper = shallow(buildApp({multiFilePatch: otherPatch, stagingStatus: 'staged'}));
      wrapper.find('MultiFilePatchView').prop('selectedRowsChanged')(new Set([2]), 'hunk', false);

      sinon.spy(otherPatch, 'getUnstagePatchForLines');
      sinon.spy(repository, 'applyPatchToIndex');

      await wrapper.find('MultiFilePatchView').prop('toggleRows')(new Set([2]), 'hunk');

      assert.sameMembers(Array.from(otherPatch.getUnstagePatchForLines.lastCall.args[0]), [2]);
      assert.isTrue(repository.applyPatchToIndex.calledWith(otherPatch.getUnstagePatchForLines.returnValues[0]));
    });
  });

  if (process.platform !== 'win32') {
    describe('toggleModeChange()', function() {
      it("it stages an unstaged file's new mode", async function() {
        const p = path.join(repository.getWorkingDirectoryPath(), 'a.txt');
        await fs.chmod(p, 0o755);
        repository.refresh();
        const newMultiFilePatch = await repository.getFilePatchForPath('a.txt', {staged: false});

        const wrapper = shallow(buildApp({filePatch: newMultiFilePatch, stagingStatus: 'unstaged'}));
        const [newFilePatch] = newMultiFilePatch.getFilePatches();

        sinon.spy(repository, 'stageFileModeChange');
        await wrapper.find('MultiFilePatchView').prop('toggleModeChange')(newFilePatch);

        assert.isTrue(repository.stageFileModeChange.calledWith('a.txt', '100755'));
      });

      it("it stages a staged file's old mode", async function() {
        const p = path.join(repository.getWorkingDirectoryPath(), 'a.txt');
        await fs.chmod(p, 0o755);
        await repository.stageFiles(['a.txt']);
        repository.refresh();
        const newMultiFilePatch = await repository.getFilePatchForPath('a.txt', {staged: true});
        const [newFilePatch] = newMultiFilePatch.getFilePatches();

        const wrapper = shallow(buildApp({filePatch: newMultiFilePatch, stagingStatus: 'staged'}));

        sinon.spy(repository, 'stageFileModeChange');
        await wrapper.find('MultiFilePatchView').prop('toggleModeChange')(newFilePatch);

        assert.isTrue(repository.stageFileModeChange.calledWith('a.txt', '100644'));
      });
    });

    describe('toggleSymlinkChange', function() {
      it('handles an addition and typechange with a special repository method', async function() {
        if (process.env.ATOM_GITHUB_SKIP_SYMLINKS) {
          this.skip();
          return;
        }

        const p = path.join(repository.getWorkingDirectoryPath(), 'waslink.txt');
        const dest = path.join(repository.getWorkingDirectoryPath(), 'destination');
        await fs.writeFile(dest, 'asdf\n', 'utf8');
        await fs.symlink(dest, p);

        await repository.stageFiles(['waslink.txt', 'destination']);
        await repository.commit('zero');

        await fs.unlink(p);
        await fs.writeFile(p, 'fdsa\n', 'utf8');

        repository.refresh();
        const symlinkMultiPatch = await repository.getFilePatchForPath('waslink.txt', {staged: false});
        const wrapper = shallow(buildApp({filePatch: symlinkMultiPatch, relPath: 'waslink.txt', stagingStatus: 'unstaged'}));
        const [symlinkPatch] = symlinkMultiPatch.getFilePatches();

        sinon.spy(repository, 'stageFileSymlinkChange');

        await wrapper.find('MultiFilePatchView').prop('toggleSymlinkChange')(symlinkPatch);

        assert.isTrue(repository.stageFileSymlinkChange.calledWith('waslink.txt'));
      });

      it('stages non-addition typechanges normally', async function() {
        if (process.env.ATOM_GITHUB_SKIP_SYMLINKS) {
          this.skip();
          return;
        }

        const p = path.join(repository.getWorkingDirectoryPath(), 'waslink.txt');
        const dest = path.join(repository.getWorkingDirectoryPath(), 'destination');
        await fs.writeFile(dest, 'asdf\n', 'utf8');
        await fs.symlink(dest, p);

        await repository.stageFiles(['waslink.txt', 'destination']);
        await repository.commit('zero');

        await fs.unlink(p);

        repository.refresh();
        const symlinkMultiPatch = await repository.getFilePatchForPath('waslink.txt', {staged: false});
        const wrapper = shallow(buildApp({filePatch: symlinkMultiPatch, relPath: 'waslink.txt', stagingStatus: 'unstaged'}));

        sinon.spy(repository, 'stageFiles');

        const [symlinkPatch] = symlinkMultiPatch.getFilePatches();
        await wrapper.find('MultiFilePatchView').prop('toggleSymlinkChange')(symlinkPatch);

        assert.isTrue(repository.stageFiles.calledWith(['waslink.txt']));
      });

      it('handles a deletion and typechange with a special repository method', async function() {
        const p = path.join(repository.getWorkingDirectoryPath(), 'waslink.txt');
        const dest = path.join(repository.getWorkingDirectoryPath(), 'destination');
        await fs.writeFile(dest, 'asdf\n', 'utf8');
        await fs.writeFile(p, 'fdsa\n', 'utf8');

        await repository.stageFiles(['waslink.txt', 'destination']);
        await repository.commit('zero');

        await fs.unlink(p);
        await fs.symlink(dest, p);
        await repository.stageFiles(['waslink.txt']);

        repository.refresh();
        const symlinkMultiPatch = await repository.getFilePatchForPath('waslink.txt', {staged: true});
        const wrapper = shallow(buildApp({filePatch: symlinkMultiPatch, relPath: 'waslink.txt', stagingStatus: 'staged'}));

        sinon.spy(repository, 'stageFileSymlinkChange');

        const [symlinkPatch] = symlinkMultiPatch.getFilePatches();
        await wrapper.find('MultiFilePatchView').prop('toggleSymlinkChange')(symlinkPatch);

        assert.isTrue(repository.stageFileSymlinkChange.calledWith('waslink.txt'));
      });

      it('unstages non-deletion typechanges normally', async function() {
        const p = path.join(repository.getWorkingDirectoryPath(), 'waslink.txt');
        const dest = path.join(repository.getWorkingDirectoryPath(), 'destination');
        await fs.writeFile(dest, 'asdf\n', 'utf8');
        await fs.symlink(dest, p);

        await repository.stageFiles(['waslink.txt', 'destination']);
        await repository.commit('zero');

        await fs.unlink(p);

        await repository.stageFiles(['waslink.txt']);

        repository.refresh();
        const symlinkMultiPatch = await repository.getFilePatchForPath('waslink.txt', {staged: true});
        const wrapper = shallow(buildApp({multiFilePatch: symlinkMultiPatch, relPath: 'waslink.txt', stagingStatus: 'staged'}));

        sinon.spy(repository, 'unstageFiles');

        const [symlinkPatch] = symlinkMultiPatch.getFilePatches();
        await wrapper.find('MultiFilePatchView').prop('toggleSymlinkChange')(symlinkPatch);

        assert.isTrue(repository.unstageFiles.calledWith(['waslink.txt']));
      });
    });
  }

  it('calls discardLines with selected rows', async function() {
    const discardLines = sinon.spy();
    const wrapper = shallow(buildApp({discardLines}));
    wrapper.find('MultiFilePatchView').prop('selectedRowsChanged')(new Set([1, 2]), 'hunk', false);

    await wrapper.find('MultiFilePatchView').prop('discardRows')();

    const lastArgs = discardLines.lastCall.args;
    assert.strictEqual(lastArgs[0], multiFilePatch);
    assert.sameMembers(Array.from(lastArgs[1]), [1, 2]);
    assert.strictEqual(lastArgs[2], repository);
  });

  it('calls discardLines with explicitly provided rows', async function() {
    const discardLines = sinon.spy();
    const wrapper = shallow(buildApp({discardLines}));
    wrapper.find('MultiFilePatchView').prop('selectedRowsChanged')(new Set([1, 2]), 'hunk', false);

    await wrapper.find('MultiFilePatchView').prop('discardRows')(new Set([4, 5]), 'hunk');

    const lastArgs = discardLines.lastCall.args;
    assert.strictEqual(lastArgs[0], multiFilePatch);
    assert.sameMembers(Array.from(lastArgs[1]), [4, 5]);
    assert.strictEqual(lastArgs[2], repository);

    assert.sameMembers(Array.from(wrapper.find('MultiFilePatchView').prop('selectedRows')), [4, 5]);
    assert.strictEqual(wrapper.find('MultiFilePatchView').prop('selectionMode'), 'hunk');
  });
});
