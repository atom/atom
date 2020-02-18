import React from 'react';
import {shallow} from 'enzyme';
import path from 'path';

import * as reporterProxy from '../../lib/reporter-proxy';

import FilePatchHeaderView from '../../lib/views/file-patch-header-view';
import ChangedFileItem from '../../lib/items/changed-file-item';
import CommitPreviewItem from '../../lib/items/commit-preview-item';
import CommitDetailItem from '../../lib/items/commit-detail-item';
import IssueishDetailItem from '../../lib/items/issueish-detail-item';

describe('FilePatchHeaderView', function() {
  const relPath = path.join('dir', 'a.txt');
  let atomEnv;

  beforeEach(function() {
    atomEnv = global.buildAtomEnvironment();
  });

  afterEach(function() {
    atomEnv.destroy();
  });

  function buildApp(overrideProps = {}) {
    return (
      <FilePatchHeaderView
        itemType={CommitPreviewItem}
        relPath={relPath}
        isCollapsed={false}
        stagingStatus="unstaged"
        isPartiallyStaged={false}
        hasHunks={true}
        hasUndoHistory={false}
        hasMultipleFileSelections={false}

        tooltips={atomEnv.tooltips}

        undoLastDiscard={() => {}}
        diveIntoMirrorPatch={() => {}}
        openFile={() => {}}
        toggleFile={() => {}}
        triggerExpand={() => {}}
        triggerCollapse={() => {}}

        {...overrideProps}
      />
    );
  }

  describe('the title', function() {
    it('renders relative file path', function() {
      const wrapper = shallow(buildApp());
      assert.strictEqual(wrapper.find('.github-FilePatchView-title').text(), relPath);
    });

    describe('when `ChangedFileItem`', function() {
      it('renders staging status for an unstaged patch', function() {
        const wrapper = shallow(buildApp({itemType: ChangedFileItem, stagingStatus: 'unstaged'}));
        assert.strictEqual(wrapper.find('.github-FilePatchView-title').text(), `Unstaged Changes for ${relPath}`);
      });

      it('renders staging status for a staged patch', function() {
        const wrapper = shallow(buildApp({itemType: ChangedFileItem, stagingStatus: 'staged'}));
        assert.strictEqual(wrapper.find('.github-FilePatchView-title').text(), `Staged Changes for ${relPath}`);
      });
    });

    it('renders title for a renamed file as oldPath → newPath', function() {
      const oldPath = path.join('dir', 'a.txt');
      const newPath = path.join('dir', 'b.txt');
      const wrapper = shallow(buildApp({relPath: oldPath, newPath}));
      assert.strictEqual(wrapper.find('.github-FilePatchView-title').text(), `${oldPath} → ${newPath}`);
    });
  });

  describe('collapsing and expanding', function() {
    describe('when itemType is ChangedFileItem', function() {
      it('does not render collapse button', function() {
        const wrapper = shallow(buildApp({itemType: ChangedFileItem}));
        assert.lengthOf(wrapper.find('.github-FilePatchView-collapseButton'), 0);
      });
    });
    describe('when itemType is not ChangedFileItem', function() {
      describe('when patch is collapsed', function() {
        it('renders a button with a chevron-right icon', function() {
          const wrapper = shallow(buildApp({isCollapsed: true}));
          assert.lengthOf(wrapper.find('.github-FilePatchView-collapseButton'), 1);
          const iconProps = wrapper.find('.github-FilePatchView-collapseButtonIcon').getElements()[0].props;
          assert.deepEqual(iconProps, {className: 'github-FilePatchView-collapseButtonIcon', icon: 'chevron-right'});
        });
        it('calls this.props.triggerExpand and records event when clicked', function() {
          const triggerExpandStub = sinon.stub();
          const addEventStub = sinon.stub(reporterProxy, 'addEvent');
          const wrapper = shallow(buildApp({isCollapsed: true, triggerExpand: triggerExpandStub}));

          assert.isFalse(triggerExpandStub.called);

          wrapper.find('.github-FilePatchView-collapseButton').simulate('click');

          assert.isTrue(triggerExpandStub.called);
          assert.strictEqual(addEventStub.callCount, 1);
          assert.isTrue(addEventStub.calledWith('expand-file-patch', {package: 'github', component: 'FilePatchHeaderView'}));
        });
      });
      describe('when patch is expanded', function() {
        it('renders a button with a chevron-down icon', function() {
          const wrapper = shallow(buildApp({isCollapsed: false}));
          assert.lengthOf(wrapper.find('.github-FilePatchView-collapseButton'), 1);
          const iconProps = wrapper.find('.github-FilePatchView-collapseButtonIcon').getElements()[0].props;
          assert.deepEqual(iconProps, {className: 'github-FilePatchView-collapseButtonIcon', icon: 'chevron-down'});
        });
        it('calls this.props.triggerCollapse and records event when clicked', function() {
          const triggerCollapseStub = sinon.stub();
          const addEventStub = sinon.stub(reporterProxy, 'addEvent');
          const wrapper = shallow(buildApp({isCollapsed: false, triggerCollapse: triggerCollapseStub}));

          assert.isFalse(triggerCollapseStub.called);
          assert.isFalse(addEventStub.called);

          wrapper.find('.github-FilePatchView-collapseButton').simulate('click');

          assert.isTrue(triggerCollapseStub.called);
          assert.strictEqual(addEventStub.callCount, 1);
          assert.isTrue(addEventStub.calledWith('collapse-file-patch', {package: 'github', component: 'FilePatchHeaderView'}));
        });
      });
    });
  });


  describe('the button group', function() {
    it('includes undo discard if ChangedFileItem, undo history is available, and the patch is unstaged', function() {
      const undoLastDiscard = sinon.stub();
      const wrapper = shallow(buildApp({
        itemType: ChangedFileItem,
        hasUndoHistory: true,
        stagingStatus: 'unstaged',
        undoLastDiscard,
      }));
      assert.isTrue(wrapper.find('button.icon-history').exists());

      wrapper.find('button.icon-history').simulate('click');
      assert.isTrue(undoLastDiscard.called);

      wrapper.setProps({hasUndoHistory: false, stagingStatus: 'unstaged'});
      assert.isFalse(wrapper.find('button.icon-history').exists());

      wrapper.setProps({hasUndoHistory: true, stagingStatus: 'staged'});
      assert.isFalse(wrapper.find('button.icon-history').exists());
    });

    function createPatchToggleTest({overrideProps, stagingStatus, buttonClass, oppositeButtonClass, tooltip}) {
      return function() {
        const diveIntoMirrorPatch = sinon.stub();
        const wrapper = shallow(buildApp({stagingStatus, diveIntoMirrorPatch, ...overrideProps}));

        assert.isTrue(wrapper.find(`button.${buttonClass}`).exists(),
          `${buttonClass} expected, but not found`);
        assert.isFalse(wrapper.find(`button.${oppositeButtonClass}`).exists(),
          `${oppositeButtonClass} not expected, but found`);

        wrapper.find(`button.${buttonClass}`).simulate('click');
        assert.isTrue(diveIntoMirrorPatch.called, `${buttonClass} click did nothing`);
      };
    }

    function createUnstagedPatchToggleTest(overrideProps) {
      return createPatchToggleTest({
        overrideProps,
        stagingStatus: 'unstaged',
        buttonClass: 'icon-tasklist',
        oppositeButtonClass: 'icon-list-unordered',
        tooltip: 'View staged changes',
      });
    }

    function createStagedPatchToggleTest(overrideProps) {
      return createPatchToggleTest({
        overrideProps,
        stagingStatus: 'staged',
        buttonClass: 'icon-list-unordered',
        oppositeButtonClass: 'icon-tasklist',
        tooltip: 'View unstaged changes',
      });
    }

    describe('when the patch is partially staged', function() {
      const props = {isPartiallyStaged: true};

      it('includes a toggle to staged button when unstaged', createUnstagedPatchToggleTest(props));

      it('includes a toggle to unstaged button when staged', createStagedPatchToggleTest(props));
    });

    describe('the jump-to-file button', function() {
      it('calls the jump to file file action prop', function() {
        const openFile = sinon.stub();
        const wrapper = shallow(buildApp({openFile}));

        wrapper.find('button.icon-code').simulate('click');
        assert.isTrue(openFile.called);
      });

      it('is singular when selections exist within a single file patch', function() {
        const wrapper = shallow(buildApp({hasMultipleFileSelections: false}));
        assert.strictEqual(wrapper.find('button.icon-code').text(), 'Jump To File');
      });

      it('is plural when selections exist within multiple file patches', function() {
        const wrapper = shallow(buildApp({hasMultipleFileSelections: true}));
        assert.strictEqual(wrapper.find('button.icon-code').text(), 'Jump To Files');
      });
    });

    function createToggleFileTest({stagingStatus, buttonClass, oppositeButtonClass}) {
      return function() {
        const toggleFile = sinon.stub();
        const wrapper = shallow(buildApp({toggleFile, stagingStatus}));

        assert.isTrue(wrapper.find(`button.${buttonClass}`).exists(),
          `${buttonClass} expected, but not found`);
        assert.isFalse(wrapper.find(`button.${oppositeButtonClass}`).exists(),
          `${oppositeButtonClass} not expected, but found`);

        wrapper.find(`button.${buttonClass}`).simulate('click');
        assert.isTrue(toggleFile.called, `${buttonClass} click did nothing`);
      };
    }

    it('includes a stage file button when unstaged', createToggleFileTest({
      stagingStatus: 'unstaged',
      buttonClass: 'icon-move-down',
      oppositeButtonClass: 'icon-move-up',
    }));

    it('includes an unstage file button when staged', createToggleFileTest({
      stagingStatus: 'staged',
      buttonClass: 'icon-move-up',
      oppositeButtonClass: 'icon-move-down',
    }));

    it('does not render buttons when in a CommitDetailItem', function() {
      const wrapper = shallow(buildApp({itemType: CommitDetailItem}));
      assert.isFalse(wrapper.find('.btn-group').exists());
    });

    it('does not render buttons when in an IssueishDetailItem', function() {
      const wrapper = shallow(buildApp({itemType: IssueishDetailItem}));
      assert.isFalse(wrapper.find('.btn-group').exists());
    });

  });
});
