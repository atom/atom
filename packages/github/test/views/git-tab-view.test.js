import React from 'react';
import {shallow, mount} from 'enzyme';

import {cloneRepository, buildRepository} from '../helpers';
import GitTabView from '../../lib/views/git-tab-view';
import {gitTabViewProps} from '../fixtures/props/git-tab-props';

describe('GitTabView', function() {
  let atomEnv, repository;

  beforeEach(async function() {
    atomEnv = global.buildAtomEnvironment();
    repository = await buildRepository(await cloneRepository());
  });

  afterEach(function() {
    atomEnv.destroy();
  });

  async function buildApp(overrides = {}) {
    return <GitTabView {...await gitTabViewProps(atomEnv, repository, overrides)} />;
  }

  it('gets the current focus', async function() {
    const wrapper = mount(await buildApp());

    assert.strictEqual(
      wrapper.instance().getFocus(wrapper.find('div.github-StagingView').getDOMNode()),
      GitTabView.focus.STAGING,
    );

    const editorNode = wrapper.find('AtomTextEditor').getDOMNode().querySelector('atom-text-editor');
    assert.strictEqual(
      wrapper.instance().getFocus(editorNode),
      GitTabView.focus.EDITOR,
    );

    assert.isNull(wrapper.instance().getFocus(document.body));
  });

  it('sets a new focus', async function() {
    const wrapper = mount(await buildApp());
    const stagingElement = wrapper.find('div.github-StagingView').getDOMNode();
    const editorElement = wrapper.find('AtomTextEditor').getDOMNode().querySelector('atom-text-editor');

    sinon.spy(stagingElement, 'focus');
    assert.isTrue(wrapper.instance().setFocus(GitTabView.focus.STAGING));
    assert.isTrue(stagingElement.focus.called);

    sinon.spy(editorElement, 'focus');
    assert.isTrue(wrapper.instance().setFocus(GitTabView.focus.EDITOR));
    assert.isTrue(editorElement.focus.called);

    assert.isFalse(wrapper.instance().setFocus(Symbol('nah')));
  });

  it('blurs by focusing the workspace center', async function() {
    const editor = await atomEnv.workspace.open(__filename);
    atomEnv.workspace.getLeftDock().activate();
    assert.notStrictEqual(atomEnv.workspace.getActivePaneItem(), editor);

    const wrapper = shallow(await buildApp());
    wrapper.instance().blur();

    assert.strictEqual(atomEnv.workspace.getActivePaneItem(), editor);
  });

  it('no-ops focus management methods when refs are unavailable', async function() {
    const wrapper = shallow(await buildApp());
    assert.isNull(wrapper.instance().getFocus({}));
    assert.isFalse(wrapper.instance().setFocus(GitTabView.focus.EDITOR));
  });

  describe('advanceFocus', function() {
    let wrapper, instance, event, stagingView;

    beforeEach(async function() {
      wrapper = mount(await buildApp());
      instance = wrapper.instance();

      stagingView = wrapper.prop('refStagingView').get();

      event = {stopPropagation: sinon.spy()};
      sinon.spy(instance, 'setFocus');
    });

    it('activates the next staging view list and stops', async function() {
      sinon.stub(instance, 'getFocus').returns(GitTabView.focus.STAGING);
      sinon.stub(stagingView, 'activateNextList').resolves(true);

      await instance.advanceFocus(event);

      assert.isTrue(stagingView.activateNextList.called);
      assert.isTrue(event.stopPropagation.called);
      assert.isFalse(instance.setFocus.called);
    });

    it('moves focus to the commit preview button from the end of the staging view', async function() {
      sinon.stub(instance, 'getFocus').returns(GitTabView.focus.STAGING);
      sinon.stub(stagingView, 'activateNextList').resolves(false);

      await instance.advanceFocus(event);

      assert.isTrue(instance.setFocus.calledWith(GitTabView.focus.COMMIT_PREVIEW_BUTTON));
      assert.isTrue(event.stopPropagation.called);
    });

    it('advances focus within the commit view', async function() {
      sinon.stub(instance, 'getFocus').returns(GitTabView.focus.COMMIT_PREVIEW_BUTTON);
      sinon.spy(stagingView, 'activateNextList');

      await instance.advanceFocus(event);

      assert.isTrue(instance.setFocus.calledWith(GitTabView.focus.EDITOR));
      assert.isFalse(stagingView.activateNextList.called);
    });

    it('advances focus from the commit view to the recent commits view', async function() {
      sinon.stub(instance, 'getFocus').returns(GitTabView.focus.COMMIT_BUTTON);
      sinon.spy(stagingView, 'activateNextList');

      await instance.advanceFocus(event);

      assert.isTrue(instance.setFocus.calledWith(GitTabView.focus.RECENT_COMMIT));
      assert.isFalse(stagingView.activateNextList.called);
    });

    it('keeps focus in the recent commits view', async function() {
      sinon.stub(instance, 'getFocus').returns(GitTabView.focus.RECENT_COMMIT);
      sinon.spy(stagingView, 'activateNextList');

      await instance.advanceFocus(event);

      assert.isFalse(instance.setFocus.called);
      assert.isFalse(stagingView.activateNextList.called);
    });

    it('does nothing if refs are unavailable', async function() {
      wrapper.instance().refCommitController.setter(null);

      await wrapper.instance().advanceFocus(event);

      assert.isFalse(event.stopPropagation.called);
    });
  });

  describe('retreatFocus', function() {
    let wrapper, instance, event, stagingView;

    beforeEach(async function() {
      wrapper = mount(await buildApp());
      instance = wrapper.instance();
      stagingView = wrapper.prop('refStagingView').get();
      event = {stopPropagation: sinon.spy()};

      sinon.spy(instance, 'setFocus');
    });

    it('focuses the enabled commit button if the recent commit view has focus', async function() {
      const setFocus = sinon.spy(wrapper.find('CommitView').instance(), 'setFocus');

      sinon.stub(instance, 'getFocus').returns(GitTabView.focus.RECENT_COMMIT);
      sinon.stub(wrapper.find('CommitView').instance(), 'commitIsEnabled').returns(true);

      await wrapper.instance().retreatFocus(event);

      assert.isTrue(setFocus.calledWith(GitTabView.focus.COMMIT_BUTTON));
      assert.isTrue(event.stopPropagation.called);
    });

    it('focuses the editor if the recent commit view has focus and the commit button is disabled', async function() {
      const setFocus = sinon.spy(wrapper.find('CommitView').instance(), 'setFocus');

      sinon.stub(instance, 'getFocus').returns(GitTabView.focus.RECENT_COMMIT);

      await wrapper.instance().retreatFocus(event);

      assert.isTrue(setFocus.calledWith(GitTabView.focus.EDITOR));
      assert.isTrue(event.stopPropagation.called);
    });

    it('moves focus internally within the commit view', async function() {
      sinon.stub(instance, 'getFocus').returns(GitTabView.focus.EDITOR);

      await wrapper.instance().retreatFocus(event);

      assert.isTrue(instance.setFocus.calledWith(GitTabView.focus.COMMIT_PREVIEW_BUTTON));
      assert.isTrue(event.stopPropagation.called);
    });

    it('focuses the last staging list if the commit preview button has focus', async function() {
      sinon.stub(instance, 'getFocus').returns(GitTabView.focus.COMMIT_PREVIEW_BUTTON);
      sinon.stub(stagingView, 'activateLastList').resolves(true);

      await wrapper.instance().retreatFocus(event);

      assert.isTrue(stagingView.activateLastList.called);
      assert.isTrue(instance.setFocus.calledWith(GitTabView.focus.STAGING));
      assert.isTrue(event.stopPropagation.called);
    });

    it('activates the previous staging list and stops', async function() {
      sinon.stub(instance, 'getFocus').returns(GitTabView.focus.STAGING);
      sinon.stub(stagingView, 'activatePreviousList').resolves(true);

      await wrapper.instance().retreatFocus(event);

      assert.isTrue(stagingView.activatePreviousList.called);
      assert.isFalse(instance.setFocus.called);
      assert.isTrue(event.stopPropagation.called);
    });

    it('does nothing if refs are unavailable', async function() {
      instance.refCommitController.setter(null);
      wrapper.prop('refStagingView').setter(null);
      instance.refRecentCommitsController.setter(null);

      await wrapper.instance().retreatFocus(event);

      assert.isFalse(event.stopPropagation.called);
    });
  });

  it('selects a staging item', async function() {
    const wrapper = mount(await buildApp({
      unstagedChanges: [{filePath: 'aaa.txt', status: 'modified'}],
    }));

    const stagingView = wrapper.prop('refStagingView').get();
    sinon.spy(stagingView, 'quietlySelectItem');
    sinon.spy(stagingView, 'setFocus');

    await wrapper.instance().quietlySelectItem('aaa.txt', 'unstaged');

    assert.isTrue(stagingView.quietlySelectItem.calledWith('aaa.txt', 'unstaged'));
    assert.isFalse(stagingView.setFocus.calledWith(GitTabView.focus.STAGING));
  });

  it('selects a staging item and focuses itself', async function() {
    const wrapper = mount(await buildApp({
      unstagedChanges: [{filePath: 'aaa.txt', status: 'modified'}],
    }));

    const stagingView = wrapper.prop('refStagingView').get();
    sinon.spy(stagingView, 'quietlySelectItem');
    sinon.spy(stagingView, 'setFocus');

    await wrapper.instance().focusAndSelectStagingItem('aaa.txt', 'unstaged');

    assert.isTrue(stagingView.quietlySelectItem.calledWith('aaa.txt', 'unstaged'));
    assert.isTrue(stagingView.setFocus.calledWith(GitTabView.focus.STAGING));
  });

  it('detects when it has focus', async function() {
    const wrapper = mount(await buildApp());
    const rootElement = wrapper.prop('refRoot').get();
    sinon.stub(rootElement, 'contains');

    rootElement.contains.returns(true);
    assert.isTrue(wrapper.instance().hasFocus());

    rootElement.contains.returns(false);
    assert.isFalse(wrapper.instance().hasFocus());

    rootElement.contains.returns(true);
    wrapper.prop('refRoot').setter(null);
    assert.isFalse(wrapper.instance().hasFocus());
  });

  it('imperatively focuses the commit preview button', async function() {
    const wrapper = mount(await buildApp());

    const setFocus = sinon.spy(wrapper.find('CommitController').instance(), 'setFocus');
    wrapper.instance().focusAndSelectCommitPreviewButton();
    assert.isTrue(setFocus.calledWith(GitTabView.focus.COMMIT_PREVIEW_BUTTON));
  });

  it('imperatively focuses the recent commits view', async function() {
    const wrapper = mount(await buildApp());

    const setFocus = sinon.spy(wrapper.find('RecentCommitsView').instance(), 'setFocus');
    wrapper.instance().focusAndSelectRecentCommit();
    assert.isTrue(setFocus.calledWith(GitTabView.focus.RECENT_COMMIT));
  });

  it('calls changeWorkingDirectory when a project is selected', async function() {
    const changeWorkingDirectory = sinon.spy();
    const wrapper = shallow(await buildApp({changeWorkingDirectory}));
    wrapper.find('GitTabHeaderController').prop('changeWorkingDirectory')('some-path');
    assert.isTrue(changeWorkingDirectory.calledWith('some-path'));
  });
});
