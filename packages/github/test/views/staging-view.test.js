import path from 'path';
import React from 'react';
import {mount} from 'enzyme';
import StagingView from '../../lib/views/staging-view';
import CommitView from '../../lib/views/commit-view';
import CommitPreviewItem from '../../lib/items/commit-preview-item';
import ResolutionProgress from '../../lib/models/conflicts/resolution-progress';
import * as reporterProxy from '../../lib/reporter-proxy';

import {assertEqualSets} from '../helpers';

describe('StagingView', function() {
  const workingDirectoryPath = '/not/real/';
  let atomEnv, commands, workspace, notificationManager;
  let app;

  beforeEach(function() {
    atomEnv = global.buildAtomEnvironment();
    commands = atomEnv.commands;
    workspace = atomEnv.workspace;
    notificationManager = atomEnv.notifications;

    sinon.stub(workspace, 'open');
    sinon.stub(workspace, 'paneForItem').returns({activateItem: () => { }});

    const noop = () => { };

    app = (
      <StagingView
        unstagedChanges={[]}
        stagedChanges={[]}
        workingDirectoryPath={workingDirectoryPath}
        hasUndoHistory={false}
        commands={commands}
        notificationManager={notificationManager}
        workspace={workspace}
        openFiles={noop}
        attemptFileStageOperation={noop}
        discardWorkDirChangesForPaths={noop}
        undoLastDiscard={noop}
        attemptStageAllOperation={noop}
        resolveAsOurs={noop}
        resolveAsTheirs={noop}
      />
    );
  });

  afterEach(function() {
    atomEnv.destroy();
  });

  describe('staging and unstaging files', function() {
    it('renders staged and unstaged files', function() {
      const filePatches = [
        {filePath: 'a.txt', status: 'modified'},
        {filePath: 'b.txt', status: 'deleted'},
      ];
      const wrapper = mount(React.cloneElement(app, {unstagedChanges: filePatches}));

      assert.deepEqual(
        wrapper.find('.github-UnstagedChanges .github-FilePatchListView-item').map(n => n.text()),
        ['a.txt', 'b.txt'],
      );
    });

    it('renders staged files', function() {
      const filePatches = [
        {filePath: 'a.txt', status: 'modified'},
        {filePath: 'b.txt', status: 'deleted'},
      ];
      const wrapper = mount(React.cloneElement(app, {stagedChanges: filePatches}));

      assert.deepEqual(
        wrapper.find('.github-StagedChanges .github-FilePatchListView-item').map(n => n.text()),
        ['a.txt', 'b.txt'],
      );
    });

    describe('confirmSelectedItems()', function() {
      let filePatches, attemptFileStageOperation;

      beforeEach(function() {
        filePatches = [
          {filePath: 'a.txt', status: 'modified'},
          {filePath: 'b.txt', status: 'deleted'},
        ];

        attemptFileStageOperation = sinon.spy();
      });

      it('calls attemptFileStageOperation with the paths to stage and the staging status', async function() {
        const wrapper = mount(React.cloneElement(app, {
          unstagedChanges: filePatches,
          attemptFileStageOperation,
        }));

        wrapper.find('.github-StagingView-unstaged').find('.github-FilePatchListView-item').at(1)
          .simulate('mousedown', {button: 0});
        await wrapper.instance().mouseup();

        commands.dispatch(wrapper.getDOMNode(), 'core:confirm');

        await assert.async.isTrue(attemptFileStageOperation.calledWith(['b.txt'], 'unstaged'));
      });

      it('calls attemptFileStageOperation with the paths to unstage and the staging status', async function() {
        const wrapper = mount(React.cloneElement(app, {
          stagedChanges: filePatches,
          attemptFileStageOperation,
        }));

        wrapper.find('.github-StagingView-staged').find('.github-FilePatchListView-item').at(1)
          .simulate('mousedown', {button: 0});
        await wrapper.instance().mouseup();

        commands.dispatch(wrapper.getDOMNode(), 'core:confirm');

        await assert.async.isTrue(attemptFileStageOperation.calledWith(['b.txt'], 'staged'));
      });
    });
  });

  describe('merge conflicts list', function() {
    const mergeConflicts = [
      {
        filePath: 'conflicted-path',
        status: {
          file: 'modified',
          ours: 'deleted',
          theirs: 'modified',
        },
      },
    ];

    it('is not visible when no conflicted paths are passed', function() {
      const wrapper = mount(app);
      assert.isFalse(wrapper.find('.github-MergeConflictPaths').exists());
    });

    it('is visible when conflicted paths are passed', function() {
      const wrapper = mount(React.cloneElement(app, {mergeConflicts}));
      assert.isTrue(wrapper.find('.github-MergeConflictPaths').exists());
    });

    it('shows "calculating" while calculating the number of conflicts', function() {
      const resolutionProgress = new ResolutionProgress();

      const wrapper = mount(React.cloneElement(app, {
        mergeConflicts,
        resolutionProgress,
      }));

      assert.lengthOf(wrapper.find('.github-RemainingConflicts'), 1);
      assert.strictEqual(wrapper.find('.github-RemainingConflicts').text(), 'calculating');
    });

    it('shows the number of remaining conflicts', function() {
      const resolutionProgress = new ResolutionProgress();
      resolutionProgress.reportMarkerCount(path.join(workingDirectoryPath, 'conflicted-path'), 10);

      const wrapper = mount(React.cloneElement(app, {
        mergeConflicts,
        resolutionProgress,
      }));

      assert.strictEqual(wrapper.find('.github-RemainingConflicts').text(), '10 conflicts remaining');
    });

    it('shows a checkmark when there are no remaining conflicts', function() {
      const resolutionProgress = new ResolutionProgress();
      resolutionProgress.reportMarkerCount(path.join(workingDirectoryPath, 'conflicted-path'), 0);

      const wrapper = mount(React.cloneElement(app, {
        mergeConflicts,
        resolutionProgress,
      }));

      assert.lengthOf(wrapper.find('.icon-check'), 1);
    });

    it('disables the "stage all" button while there are unresolved conflicts', function() {
      const multiMergeConflicts = [
        {
          filePath: 'conflicted-path-0.txt',
          status: {file: 'modified', ours: 'deleted', theirs: 'modified'},
        },
        {
          filePath: 'conflicted-path-1.txt',
          status: {file: 'modified', ours: 'modified', theirs: 'modified'},
        },
      ];

      const resolutionProgress = new ResolutionProgress();
      resolutionProgress.reportMarkerCount(path.join(workingDirectoryPath, 'conflicted-path-0.txt'), 2);
      resolutionProgress.reportMarkerCount(path.join(workingDirectoryPath, 'conflicted-path-1.txt'), 0);

      const wrapper = mount(React.cloneElement(app, {
        mergeConflicts: multiMergeConflicts,
        resolutionProgress,
      }));

      const conflictButton = wrapper.find('.github-MergeConflictPaths')
        .find('.github-StagingView-headerButton');
      assert.strictEqual(conflictButton.text(), 'Stage All');
      assert.isTrue(conflictButton.prop('disabled'));
    });

    it('enables the "stage all" button when all conflicts are resolved', function() {
      const resolutionProgress = new ResolutionProgress();
      resolutionProgress.reportMarkerCount(path.join(workingDirectoryPath, 'conflicted-path'), 0);

      const wrapper = mount(React.cloneElement(app, {
        mergeConflicts,
        resolutionProgress,
      }));

      const conflictButton = wrapper.find('.github-MergeConflictPaths')
        .find('.github-StagingView-headerButton');
      assert.strictEqual(conflictButton.text(), 'Stage All');
      assert.isFalse(conflictButton.prop('disabled'));
    });
  });

  describe('showFilePatchItem(filePath, stagingStatus, {activate})', function() {
    describe('calls to workspace.open', function() {
      it('passes activation options and focuses the returned item if activate is true', async function() {
        const wrapper = mount(app);

        const changedFileItem = {
          getElement: () => changedFileItem,
          querySelector: () => changedFileItem,
          focus: sinon.spy(),
        };
        workspace.open.returns(changedFileItem);

        await wrapper.instance().showFilePatchItem('file.txt', 'staged', {activate: true});

        assert.equal(workspace.open.callCount, 1);
        assert.deepEqual(workspace.open.args[0], [
          `atom-github://file-patch/file.txt?workdir=${encodeURIComponent(workingDirectoryPath)}&stagingStatus=staged`,
          {pending: true, activatePane: true, pane: undefined, activateItem: true},
        ]);
        assert.isTrue(changedFileItem.focus.called);
      });

      it('makes the item visible if activate is false', async function() {
        const wrapper = mount(app);

        const focus = sinon.spy();
        const changedFileItem = {focus};
        workspace.open.returns(changedFileItem);
        const activateItem = sinon.spy();
        workspace.paneForItem.returns({activateItem});

        await wrapper.instance().showFilePatchItem('file.txt', 'staged', {activate: false});

        assert.equal(workspace.open.callCount, 1);
        assert.deepEqual(workspace.open.args[0], [
          `atom-github://file-patch/file.txt?workdir=${encodeURIComponent(workingDirectoryPath)}&stagingStatus=staged`,
          {pending: true, activatePane: false, pane: undefined, activateItem: false},
        ]);
        assert.isFalse(focus.called);
        assert.equal(activateItem.callCount, 1);
        assert.equal(activateItem.args[0][0], changedFileItem);
      });
    });
  });

  describe('showMergeConflictFileForPath(relativeFilePath, {activate})', function() {
    it('passes activation options and focuses the returned item if activate is true', async function() {
      const wrapper = mount(app);

      sinon.stub(wrapper.instance(), 'fileExists').returns(true);

      await wrapper.instance().showMergeConflictFileForPath('conflict.txt');

      assert.equal(workspace.open.callCount, 1);
      assert.deepEqual(workspace.open.args[0], [
        path.join(workingDirectoryPath, 'conflict.txt'),
        {pending: true, activatePane: false, activateItem: false},
      ]);

      workspace.open.reset();
      await wrapper.instance().showMergeConflictFileForPath('conflict.txt', {activate: true});
      assert.equal(workspace.open.callCount, 1);
      assert.deepEqual(workspace.open.args[0], [
        path.join(workingDirectoryPath, 'conflict.txt'),
        {pending: true, activatePane: true, activateItem: true},
      ]);
    });

    describe('when the file doesn\'t exist', function() {
      it('shows an info notification and does not open the file', async function() {
        sinon.spy(notificationManager, 'addInfo');

        const wrapper = mount(app);
        sinon.stub(wrapper.instance(), 'fileExists').returns(false);

        notificationManager.clear(); // clear out notifications
        await wrapper.instance().showMergeConflictFileForPath('conflict.txt');

        assert.equal(notificationManager.getNotifications().length, 1);
        assert.equal(workspace.open.callCount, 0);
        assert.equal(notificationManager.addInfo.callCount, 1);
        assert.deepEqual(notificationManager.addInfo.args[0], ['File has been deleted.']);
      });
    });
  });

  describe('getPanesWithStalePendingFilePatchItem', function() {
    it('ignores CommitPreviewItems', function() {
      const pane = workspace.getCenter().getPanes()[0];

      const changedFileItem = new CommitPreviewItem({});
      sinon.stub(pane, 'getPendingItem').returns({
        getRealItem: () => changedFileItem,
      });
      const wrapper = mount(app);

      assert.deepEqual(wrapper.instance().getPanesWithStalePendingFilePatchItem(), []);
    });
  });

  describe('when the selection changes due to keyboard navigation', function() {
    let showFilePatchItem, showMergeConflictFileForPath;

    beforeEach(function() {
      showFilePatchItem = sinon.stub(StagingView.prototype, 'showFilePatchItem');
      showMergeConflictFileForPath = sinon.stub(StagingView.prototype, 'showMergeConflictFileForPath');
    });

    afterEach(function() {
      showFilePatchItem.restore();
      showMergeConflictFileForPath.restore();
    });

    describe('when github.keyboardNavigationDelay is 0', function() {
      beforeEach(function() {
        atom.config.set('github.keyboardNavigationDelay', 0);
      });

      it('synchronously calls showFilePatchItem if there is a pending file patch item open', async function() {
        const filePatches = [
          {filePath: 'a.txt', status: 'modified'},
          {filePath: 'b.txt', status: 'deleted'},
        ];

        const wrapper = mount(React.cloneElement(app, {
          unstagedChanges: filePatches,
        }));
        sinon.stub(wrapper.instance(), 'hasFocus').returns(true);

        const getPanesWithStalePendingFilePatchItem = sinon.stub(
          wrapper.instance(),
          'getPanesWithStalePendingFilePatchItem',
        ).returns([]);
        await wrapper.instance().selectNext();
        assert.isFalse(showFilePatchItem.called);

        getPanesWithStalePendingFilePatchItem.returns(['item1', 'item2']);

        await wrapper.instance().selectPrevious();
        assert.isTrue(showFilePatchItem.calledTwice);
        assert.strictEqual(showFilePatchItem.args[0][0], filePatches[0].filePath);
        assert.strictEqual(showFilePatchItem.args[1][0], filePatches[0].filePath);
        showFilePatchItem.reset();

        await wrapper.instance().selectNext();
        assert.isTrue(showFilePatchItem.calledTwice);
        assert.strictEqual(showFilePatchItem.args[0][0], filePatches[1].filePath);
        assert.strictEqual(showFilePatchItem.args[1][0], filePatches[1].filePath);
      });

      it('does not call showMergeConflictFileForPath', async function() {
        // Currently we don't show merge conflict files while using keyboard nav. They can only be viewed via clicking.
        // This behavior is different from the diff views because merge conflict files are regular editors with decorations
        // We might change this in the future to also open pending items
        const mergeConflicts = [
          {
            filePath: 'conflicted-path-1',
            status: {
              file: 'modified',
              ours: 'deleted',
              theirs: 'modified',
            },
          },
          {
            filePath: 'conflicted-path-2',
            status: {
              file: 'modified',
              ours: 'deleted',
              theirs: 'modified',
            },
          },
        ];

        const wrapper = mount(React.cloneElement(app, {
          mergeConflicts,
        }));

        await wrapper.instance().selectNext();
        const selectedItems = wrapper.instance().getSelectedItems().map(item => item.filePath);
        assert.deepEqual(selectedItems, ['conflicted-path-2']);
        assert.isFalse(showMergeConflictFileForPath.called);
      });
    });

    describe('when github.keyboardNavigationDelay is greater than 0', function() {
      beforeEach(function() {
        atom.config.set('github.keyboardNavigationDelay', 50);
      });

      it('asynchronously calls showFilePatchItem if there is a pending file patch item open', async function() {
        const filePatches = [
          {filePath: 'a.txt', status: 'modified'},
          {filePath: 'b.txt', status: 'deleted'},
        ];

        const wrapper = mount(React.cloneElement(app, {
          unstagedChanges: filePatches,
        }));
        sinon.stub(wrapper.instance(), 'hasFocus').returns(true);

        const getPanesWithStalePendingFilePatchItem = sinon.stub(
          wrapper.instance(),
          'getPanesWithStalePendingFilePatchItem',
        ).returns([]);
        await wrapper.instance().selectNext();
        assert.isFalse(showFilePatchItem.called);

        getPanesWithStalePendingFilePatchItem.returns(['item1', 'item2', 'item3']);
        await wrapper.instance().selectPrevious();
        await assert.async.isTrue(showFilePatchItem.calledWith(filePatches[0].filePath));
        assert.isTrue(showFilePatchItem.calledThrice);
        showFilePatchItem.reset();
        await wrapper.instance().selectNext();
        await assert.async.isTrue(showFilePatchItem.calledWith(filePatches[1].filePath));
        assert.isTrue(showFilePatchItem.calledThrice);
      });
    });

    it('autoscrolls to the selected item if it is out of view', async function() {
      const unstagedChanges = [
        {filePath: 'a.txt', status: 'modified'},
        {filePath: 'b.txt', status: 'modified'},
        {filePath: 'c.txt', status: 'modified'},
        {filePath: 'd.txt', status: 'modified'},
        {filePath: 'e.txt', status: 'modified'},
        {filePath: 'f.txt', status: 'modified'},
      ];

      const root = document.createElement('div');
      root.style.top = '75%';
      document.body.appendChild(root);

      const wrapper = mount(React.cloneElement(app, {
        unstagedChanges,
      }), {attachTo: root});

      // Actually loading the style sheet is complicated and prone to timing
      // issues, so this applies some minimal styling to allow the unstaged
      // changes list to scroll.
      const unstagedChangesList = wrapper.find('.github-StagingView-unstaged').getDOMNode();
      unstagedChangesList.style.flex = 'inherit';
      unstagedChangesList.style.overflow = 'scroll';
      unstagedChangesList.style.height = '50px';

      assert.equal(unstagedChangesList.scrollTop, 0);

      await wrapper.instance().selectNext();
      await wrapper.instance().selectNext();
      await wrapper.instance().selectNext();
      await wrapper.instance().selectNext();

      assert.isAbove(unstagedChangesList.scrollTop, 0);

      wrapper.unmount();
      root.remove();
    });
  });

  describe('when the selection changes due to a repo update', function() {
    let showFilePatchItem;

    beforeEach(function() {
      atom.config.set('github.keyboardNavigationDelay', 0);
      showFilePatchItem = sinon.stub(StagingView.prototype, 'showFilePatchItem');
    });

    afterEach(function() {
      showFilePatchItem.restore();
    });

    // such as files being staged/unstaged, discarded or stashed
    it('calls showFilePatchItem if there is a pending file patch item open', function() {
      const filePatches = [
        {filePath: 'a.txt', status: 'modified'},
        {filePath: 'b.txt', status: 'deleted'},
      ];

      const wrapper = mount(React.cloneElement(app, {
        unstagedChanges: filePatches,
      }));
      sinon.stub(wrapper.instance(), 'hasFocus').returns(true);

      let selectedItems = wrapper.instance().getSelectedItems();
      assert.lengthOf(selectedItems, 1);
      assert.strictEqual(selectedItems[0].filePath, 'a.txt');
      sinon.stub(wrapper.instance(), 'getPanesWithStalePendingFilePatchItem').returns(['item1']);
      const newFilePatches = filePatches.slice(1); // remove first item, as though it was staged or discarded

      wrapper.setProps({unstagedChanges: newFilePatches});

      selectedItems = wrapper.instance().getSelectedItems();
      assert.lengthOf(selectedItems, 1);
      assert.strictEqual(selectedItems[0].filePath, 'b.txt');
      assert.isTrue(showFilePatchItem.calledWith('b.txt'));
    });

    it('does not call showFilePatchItem if a new set of file patches are being fetched', function() {
      const wrapper = mount(React.cloneElement(app, {
        unstagedChanges: [{filePath: 'a.txt', status: 'modified'}],
      }));
      sinon.stub(wrapper.instance(), 'hasFocus').returns(true);

      sinon.stub(wrapper.instance(), 'getPanesWithStalePendingFilePatchItem').returns(['item1']);
      wrapper.setProps({unstagedChanges: []}); // when repo is changed, lists are cleared out and data is fetched for new repo
      assert.isFalse(showFilePatchItem.called);

      wrapper.setProps({unstagedChanges: [{filePath: 'b.txt', status: 'deleted'}]}); // data for new repo is loaded
      assert.isFalse(showFilePatchItem.called);

      wrapper.setProps({unstagedChanges: [{filePath: 'c.txt', status: 'added'}]});
      assert.isTrue(showFilePatchItem.called);
    });
  });

  it('updates the selection when there is an `activeFilePatch`', function() {
    const wrapper = mount(React.cloneElement(app, {
      unstagedChanges: [{filePath: 'file.txt', status: 'modified'}],
    }));

    let selectedItems = wrapper.instance().getSelectedItems();
    assert.lengthOf(selectedItems, 1);
    assert.strictEqual(selectedItems[0].filePath, 'file.txt');

    // view.activeFilePatch = {
    //   getFilePath() { return 'b.txt'; },
    //   getStagingStatus() { return 'unstaged'; },
    // };

    wrapper.setProps({
      unstagedChanges: [
        {filePath: 'a.txt', status: 'modified'},
        {filePath: 'b.txt', status: 'deleted'},
      ],
    });
    selectedItems = wrapper.instance().getSelectedItems();
    assert.lengthOf(selectedItems, 1);
  });

  describe('when dragging a mouse across multiple items', function() {
    let showFilePatchItem;

    beforeEach(function() {
      showFilePatchItem = sinon.stub(StagingView.prototype, 'showFilePatchItem');
    });

    afterEach(function() {
      showFilePatchItem.restore();
    });

    // https://github.com/atom/github/issues/352
    it('selects the items', async function() {
      const unstagedChanges = [
        {filePath: 'a.txt', status: 'modified'},
        {filePath: 'b.txt', status: 'modified'},
        {filePath: 'c.txt', status: 'modified'},
      ];

      const wrapper = mount(React.cloneElement(app, {
        unstagedChanges,
      }));

      await wrapper.instance().mousedownOnItem({button: 0, persist: () => { }}, unstagedChanges[0]);
      await wrapper.instance().mousemoveOnItem({}, unstagedChanges[0]);
      await wrapper.instance().mousemoveOnItem({}, unstagedChanges[1]);
      wrapper.instance().mouseup();
      assertEqualSets(wrapper.state('selection').getSelectedItems(), new Set(unstagedChanges.slice(0, 2)));
      assert.equal(showFilePatchItem.callCount, 0);
    });
  });

  describe('when advancing and retreating activation', function() {
    let wrapper, stagedChanges;

    beforeEach(function() {
      const unstagedChanges = [
        {filePath: 'unstaged-1.txt', status: 'modified'},
        {filePath: 'unstaged-2.txt', status: 'modified'},
        {filePath: 'unstaged-3.txt', status: 'modified'},
      ];
      const mergeConflicts = [
        {filePath: 'conflict-1.txt', status: {file: 'modified', ours: 'deleted', theirs: 'modified'}},
        {filePath: 'conflict-2.txt', status: {file: 'modified', ours: 'added', theirs: 'modified'}},
      ];
      stagedChanges = [
        {filePath: 'staged-1.txt', status: 'staged'},
        {filePath: 'staged-2.txt', status: 'staged'},
      ];

      wrapper = mount(React.cloneElement(app, {
        unstagedChanges, stagedChanges, mergeConflicts,
      }));
    });

    const assertSelected = expected => {
      const actual = Array.from(wrapper.update().state('selection').getSelectedItems()).map(item => item.filePath);
      assert.deepEqual(actual, expected);
    };

    it("selects the next list, retaining that list's selection", async function() {
      await wrapper.instance().activateNextList();
      assertSelected(['conflict-1.txt']);

      await wrapper.instance().activateNextList();
      assertSelected(['staged-1.txt']);

      await wrapper.instance().activateNextList();
      assertSelected(['staged-1.txt']);
    });

    it("selects the previous list, retaining that list's selection", async function() {
      wrapper.instance().mousedownOnItem({button: 0, persist: () => { }}, stagedChanges[1]);
      wrapper.instance().mouseup();
      assertSelected(['staged-2.txt']);

      await wrapper.instance().activatePreviousList();
      assertSelected(['conflict-1.txt']);

      await wrapper.instance().activatePreviousList();
      assertSelected(['unstaged-1.txt']);

      await wrapper.instance().activatePreviousList();
      assertSelected(['unstaged-1.txt']);
    });

    it('selects the first item of the final list', async function() {
      assertSelected(['unstaged-1.txt']);

      await wrapper.instance().activateLastList();
      assertSelected(['staged-1.txt']);
    });
  });

  describe('when navigating with core:move-left', function() {
    let wrapper, showFilePatchItem, showMergeConflictFileForPath;

    beforeEach(function() {
      const unstagedChanges = [
        {filePath: 'unstaged-1.txt', status: 'modified'},
        {filePath: 'unstaged-2.txt', status: 'modified'},
      ];
      const mergeConflicts = [
        {filePath: 'conflict-1.txt', status: {file: 'modified', ours: 'modified', theirs: 'modified'}},
        {filePath: 'conflict-2.txt', status: {file: 'modified', ours: 'modified', theirs: 'modified'}},
      ];

      wrapper = mount(React.cloneElement(app, {
        unstagedChanges,
        mergeConflicts,
      }));

      showFilePatchItem = sinon.stub(StagingView.prototype, 'showFilePatchItem');
      showMergeConflictFileForPath = sinon.stub(StagingView.prototype, 'showMergeConflictFileForPath');
    });

    afterEach(function() {
      showFilePatchItem.restore();
      showMergeConflictFileForPath.restore();
    });

    it('invokes a callback only when a single file is selected', async function() {
      await wrapper.instance().selectFirst();

      commands.dispatch(wrapper.getDOMNode(), 'core:move-left');

      assert.isTrue(showFilePatchItem.calledWith('unstaged-1.txt'), 'Callback invoked with unstaged-1.txt');

      showFilePatchItem.reset();

      await wrapper.instance().selectAll();
      const selectedFilePaths = wrapper.instance().getSelectedItems().map(item => item.filePath).sort();
      assert.deepEqual(selectedFilePaths, ['unstaged-1.txt', 'unstaged-2.txt']);

      commands.dispatch(wrapper.getDOMNode(), 'core:move-left');

      assert.equal(showFilePatchItem.callCount, 0);
    });

    it('invokes a callback with a single merge conflict selection', async function() {
      await wrapper.instance().activateNextList();
      await wrapper.instance().selectFirst();

      commands.dispatch(wrapper.getDOMNode(), 'core:move-left');

      assert.isTrue(showMergeConflictFileForPath.calledWith('conflict-1.txt'), 'Callback invoked with conflict-1.txt');

      showMergeConflictFileForPath.reset();
      await wrapper.instance().selectAll();
      const selectedFilePaths = wrapper.instance().getSelectedItems().map(item => item.filePath).sort();
      assert.deepEqual(selectedFilePaths, ['conflict-1.txt', 'conflict-2.txt']);

      commands.dispatch(wrapper.getDOMNode(), 'core:move-left');

      assert.equal(showMergeConflictFileForPath.callCount, 0);
    });
  });

  // https://github.com/atom/github/issues/468
  it('updates selection on mousedown', async function() {
    const unstagedChanges = [
      {filePath: 'a.txt', status: 'modified'},
      {filePath: 'b.txt', status: 'modified'},
      {filePath: 'c.txt', status: 'modified'},
    ];
    const wrapper = mount(React.cloneElement(app, {
      unstagedChanges,
    }));

    await wrapper.instance().mousedownOnItem({button: 0, persist: () => { }}, unstagedChanges[0]);
    wrapper.instance().mouseup();
    assertEqualSets(wrapper.state('selection').getSelectedItems(), new Set([unstagedChanges[0]]));

    await wrapper.instance().mousedownOnItem({button: 0, persist: () => { }}, unstagedChanges[2]);
    assertEqualSets(wrapper.state('selection').getSelectedItems(), new Set([unstagedChanges[2]]));
  });

  if (process.platform !== 'win32') {
    // https://github.com/atom/github/issues/514
    describe('mousedownOnItem', function() {
      it('does not select item or set selection to be in progress if ctrl-key is pressed and not on windows', async function() {
        const unstagedChanges = [
          {filePath: 'a.txt', status: 'modified'},
          {filePath: 'b.txt', status: 'modified'},
          {filePath: 'c.txt', status: 'modified'},
        ];
        const wrapper = mount(React.cloneElement(app, {
          unstagedChanges,
        }));

        sinon.spy(wrapper.state('selection'), 'addOrSubtractSelection');
        sinon.spy(wrapper.state('selection'), 'selectItem');

        await wrapper.instance().mousedownOnItem({button: 0, ctrlKey: true, persist: () => { }}, unstagedChanges[0]);
        assert.isFalse(wrapper.state('selection').addOrSubtractSelection.called);
        assert.isFalse(wrapper.state('selection').selectItem.called);
        assert.isFalse(wrapper.instance().mouseSelectionInProgress);
      });
    });
  }

  describe('focus management', function() {
    let wrapper, instance;

    beforeEach(function() {
      const unstagedChanges = [
        {filePath: 'unstaged-1.txt', status: 'modified'},
        {filePath: 'unstaged-2.txt', status: 'modified'},
        {filePath: 'unstaged-3.txt', status: 'modified'},
      ];
      const mergeConflicts = [
        {filePath: 'conflict-1.txt', status: {file: 'modified', ours: 'deleted', theirs: 'modified'}},
        {filePath: 'conflict-2.txt', status: {file: 'modified', ours: 'added', theirs: 'modified'}},
      ];
      const stagedChanges = [
        {filePath: 'staged-1.txt', status: 'staged'},
        {filePath: 'staged-2.txt', status: 'staged'},
      ];

      wrapper = mount(React.cloneElement(app, {
        unstagedChanges, stagedChanges, mergeConflicts,
      }));
      instance = wrapper.instance();
    });

    it('gets the current focus', function() {
      const rootElement = wrapper.find('.github-StagingView').getDOMNode();

      assert.strictEqual(instance.getFocus(rootElement), StagingView.focus.STAGING);
      assert.isNull(instance.getFocus(document.body));

      instance.refRoot.setter(null);
      assert.isNull(instance.getFocus(rootElement));
    });

    it('sets a new focus', function() {
      const rootElement = wrapper.find('.github-StagingView').getDOMNode();

      sinon.stub(rootElement, 'focus');

      assert.isFalse(instance.setFocus(Symbol('nope')));
      assert.isFalse(rootElement.focus.called);

      assert.isTrue(instance.setFocus(StagingView.focus.STAGING));
      assert.isTrue(rootElement.focus.called);

      instance.refRoot.setter(null);
      rootElement.focus.resetHistory();
      assert.isTrue(instance.setFocus(StagingView.focus.STAGING));
      assert.isFalse(rootElement.focus.called);
    });

    it('keeps focus on this component if a non-last list is focused', async function() {
      sinon.spy(instance, 'activateNextList');
      assert.strictEqual(
        await instance.advanceFocusFrom(StagingView.focus.STAGING),
        StagingView.focus.STAGING,
      );
      assert.isTrue(await instance.activateNextList.lastCall.returnValue);
    });

    it('moves focus to the CommitView if the last list was focused', async function() {
      await instance.activateLastList();
      sinon.spy(instance, 'activateNextList');
      assert.strictEqual(
        await instance.advanceFocusFrom(StagingView.focus.STAGING),
        CommitView.firstFocus,
      );
      assert.isFalse(await instance.activateNextList.lastCall.returnValue);
    });

    it('detects when the component does have focus', function() {
      const rootElement = wrapper.find('.github-StagingView').getDOMNode();
      sinon.stub(rootElement, 'contains');

      rootElement.contains.returns(true);
      assert.isTrue(wrapper.instance().hasFocus());

      rootElement.contains.returns(false);
      assert.isFalse(wrapper.instance().hasFocus());

      rootElement.contains.returns(true);
      wrapper.instance().refRoot.setter(null);
      assert.isFalse(wrapper.instance().hasFocus());
    });
  });

  describe('discardAll()', function() {
    it('records an event', function() {
      const filePatches = [
        {filePath: 'a.txt', status: 'modified'},
        {filePath: 'b.txt', status: 'deleted'},
      ];
      const wrapper = mount(React.cloneElement(app, {unstagedChanges: filePatches}));
      sinon.stub(reporterProxy, 'addEvent');
      wrapper.instance().discardAll();
      assert.isTrue(reporterProxy.addEvent.calledWith('discard-unstaged-changes', {
        package: 'github',
        component: 'StagingView',
        fileCount: 2,
        type: 'all',
        eventSource: undefined,
      }));
    });
  });

  describe('discardChanges()', function() {
    it('records an event', function() {
      const wrapper = mount(app);
      sinon.stub(reporterProxy, 'addEvent');
      sinon.stub(wrapper.instance(), 'getSelectedItemFilePaths').returns(['a.txt', 'b.txt']);
      wrapper.instance().discardChanges();
      assert.isTrue(reporterProxy.addEvent.calledWith('discard-unstaged-changes', {
        package: 'github',
        component: 'StagingView',
        fileCount: 2,
        type: 'selected',
        eventSource: undefined,
      }));
    });
  });

  describe('undoLastDiscard()', function() {
    it('records an event', function() {
      const wrapper = mount(React.cloneElement(app, {hasUndoHistory: true}));
      sinon.stub(reporterProxy, 'addEvent');
      sinon.stub(wrapper.instance(), 'getSelectedItemFilePaths').returns(['a.txt', 'b.txt']);
      wrapper.instance().undoLastDiscard();
      assert.isTrue(reporterProxy.addEvent.calledWith('undo-last-discard', {
        package: 'github',
        component: 'StagingView',
        eventSource: undefined,
      }));
    });
  });
});
