import React from 'react';
import {shallow, mount} from 'enzyme';

import RecentCommitsController from '../../lib/controllers/recent-commits-controller';
import CommitDetailItem from '../../lib/items/commit-detail-item';
import {commitBuilder} from '../builder/commit';
import {cloneRepository, buildRepository, registerGitHubOpener} from '../helpers';
import * as reporterProxy from '../../lib/reporter-proxy';

describe('RecentCommitsController', function() {
  let atomEnv, workdirPath, app;

  beforeEach(async function() {
    workdirPath = await cloneRepository('three-files');
    const repository = await buildRepository(workdirPath);

    atomEnv = global.buildAtomEnvironment();

    app = (
      <RecentCommitsController
        commits={[]}
        isLoading={false}
        undoLastCommit={() => { }}
        workspace={atomEnv.workspace}
        commands={atomEnv.commands}
        repository={repository}
      />
    );
  });

  afterEach(function() {
    atomEnv.destroy();
  });

  it('passes recent commits to the RecentCommitsView', function() {
    const commits = [commitBuilder().build(), commitBuilder().build(), commitBuilder().build()];
    app = React.cloneElement(app, {commits});
    const wrapper = shallow(app);
    assert.deepEqual(wrapper.find('RecentCommitsView').prop('commits'), commits);
  });

  it('passes fetch progress to the RecentCommitsView', function() {
    app = React.cloneElement(app, {isLoading: true});
    const wrapper = shallow(app);
    assert.isTrue(wrapper.find('RecentCommitsView').prop('isLoading'));
  });

  it('passes the clipboard to the RecentCommitsView', function() {
    app = React.cloneElement(app);
    const wrapper = shallow(app);
    assert.deepEqual(wrapper.find('RecentCommitsView').prop('clipboard'), atom.clipboard);
  });

  describe('openCommit({sha, preserveFocus})', function() {
    it('opens a commit detail item', async function() {
      sinon.stub(atomEnv.workspace, 'open').resolves();

      const sha = 'asdf1234';
      const commits = [commitBuilder().sha(sha).build()];
      app = React.cloneElement(app, {commits});

      const wrapper = shallow(app);
      await wrapper.find('RecentCommitsView').prop('openCommit')({sha: 'asdf1234', preserveFocus: false});

      assert.isTrue(atomEnv.workspace.open.calledWith(
        `atom-github://commit-detail?workdir=${encodeURIComponent(workdirPath)}` +
        `&sha=${encodeURIComponent(sha)}`,
      ));
    });

    it('preserves keyboard focus within the RecentCommitsView when requested', async function() {
      const preventFocus = sinon.spy();
      sinon.stub(atomEnv.workspace, 'open').resolves({preventFocus});

      const sha = 'asdf1234';
      const commits = [commitBuilder().sha(sha).build()];
      app = React.cloneElement(app, {commits});

      const wrapper = mount(app);
      const focusSpy = sinon.stub(wrapper.find('RecentCommitsView').instance(), 'setFocus').returns(true);

      await wrapper.find('RecentCommitsView').prop('openCommit')({sha: 'asdf1234', preserveFocus: true});
      assert.isTrue(focusSpy.called);
      assert.isTrue(preventFocus.called);
    });

    it('records an event', async function() {
      sinon.stub(atomEnv.workspace, 'open').resolves({preventFocus() {}});
      sinon.stub(reporterProxy, 'addEvent');

      const sha = 'asdf1234';
      const commits = [commitBuilder().sha(sha).build()];
      app = React.cloneElement(app, {commits});
      const wrapper = shallow(app);

      await wrapper.instance().openCommit({sha: 'asdf1234', preserveFocus: true});
      assert.isTrue(reporterProxy.addEvent.calledWith('open-commit-in-pane', {
        package: 'github',
        from: RecentCommitsController.name,
      }));
    });
  });

  describe('commit navigation', function() {
    let wrapper;

    beforeEach(function() {
      const commits = ['1', '2', '3', '4', '5'].map(s => commitBuilder().sha(s).build());
      app = React.cloneElement(app, {commits});
      wrapper = shallow(app);
    });

    describe('selectNextCommit', function() {
      it('selects the first commit if there is no selection', async function() {
        assert.strictEqual(wrapper.find('RecentCommitsView').prop('selectedCommitSha'), '');
        await wrapper.find('RecentCommitsView').prop('selectNextCommit')();
        assert.strictEqual(wrapper.find('RecentCommitsView').prop('selectedCommitSha'), '1');
      });

      it('selects the next commit in sequence', async function() {
        wrapper.setState({selectedCommitSha: '2'});
        await wrapper.find('RecentCommitsView').prop('selectNextCommit')();
        assert.strictEqual(wrapper.find('RecentCommitsView').prop('selectedCommitSha'), '3');
      });

      it('remains on the last commit', async function() {
        wrapper.setState({selectedCommitSha: '5'});
        await wrapper.find('RecentCommitsView').prop('selectNextCommit')();
        assert.strictEqual(wrapper.find('RecentCommitsView').prop('selectedCommitSha'), '5');
      });
    });

    describe('selectPreviousCommit', function() {
      it('selects the first commit if there is no selection', async function() {
        assert.strictEqual(wrapper.find('RecentCommitsView').prop('selectedCommitSha'), '');
        await wrapper.find('RecentCommitsView').prop('selectPreviousCommit')();
        assert.strictEqual(wrapper.find('RecentCommitsView').prop('selectedCommitSha'), '1');
      });

      it('selects the previous commit in sequence', async function() {
        wrapper.setState({selectedCommitSha: '3'});
        await wrapper.find('RecentCommitsView').prop('selectPreviousCommit')();
        assert.strictEqual(wrapper.find('RecentCommitsView').prop('selectedCommitSha'), '2');
      });

      it('remains on the first commit', async function() {
        wrapper.setState({selectedCommitSha: '1'});
        await wrapper.find('RecentCommitsView').prop('selectPreviousCommit')();
        assert.strictEqual(wrapper.find('RecentCommitsView').prop('selectedCommitSha'), '1');
      });
    });
  });

  describe('focus management', function() {
    it('forwards focus management methods to its view', async function() {
      const wrapper = mount(app);

      const setFocusSpy = sinon.spy(wrapper.find('RecentCommitsView').instance(), 'setFocus');
      const rememberFocusSpy = sinon.spy(wrapper.find('RecentCommitsView').instance(), 'getFocus');
      const advanceFocusSpy = sinon.spy(wrapper.find('RecentCommitsView').instance(), 'advanceFocusFrom');
      const retreatFocusSpy = sinon.spy(wrapper.find('RecentCommitsView').instance(), 'retreatFocusFrom');

      wrapper.instance().setFocus(RecentCommitsController.focus.RECENT_COMMIT);
      assert.isTrue(setFocusSpy.calledWith(RecentCommitsController.focus.RECENT_COMMIT));

      wrapper.instance().getFocus(document.body);
      assert.isTrue(rememberFocusSpy.calledWith(document.body));

      await wrapper.instance().advanceFocusFrom(RecentCommitsController.focus.RECENT_COMMIT);
      assert.isTrue(advanceFocusSpy.calledWith(RecentCommitsController.focus.RECENT_COMMIT));

      await wrapper.instance().retreatFocusFrom(RecentCommitsController.focus.RECENT_COMMIT);
      assert.isTrue(retreatFocusSpy.calledWith(RecentCommitsController.focus.RECENT_COMMIT));
    });

    it('selects the first commit when focus enters the component', async function() {
      const commits = ['0', '1', '2'].map(s => commitBuilder().sha(s).build());
      const wrapper = mount(React.cloneElement(app, {commits, selectedCommitSha: ''}));
      const stateSpy = sinon.spy(wrapper.instance(), 'setSelectedCommitIndex');
      sinon.stub(wrapper.find('RecentCommitsView').instance(), 'setFocus').returns(true);

      assert.isTrue(wrapper.instance().setFocus(RecentCommitsController.focus.RECENT_COMMIT));
      assert.isTrue(stateSpy.called);
      await stateSpy.lastCall.returnValue;
      wrapper.update();

      assert.strictEqual(wrapper.find('RecentCommitsView').prop('selectedCommitSha'), '0');
    });

    it('leaves an existing commit selection alone', function() {
      const commits = ['0', '1', '2'].map(s => commitBuilder().sha(s).build());
      const wrapper = mount(React.cloneElement(app, {commits}));
      wrapper.setState({selectedCommitSha: '2'});
      const stateSpy = sinon.spy(wrapper.instance(), 'setSelectedCommitIndex');
      sinon.stub(wrapper.find('RecentCommitsView').instance(), 'setFocus').returns(true);

      assert.isTrue(wrapper.instance().setFocus(RecentCommitsController.focus.RECENT_COMMIT));
      assert.isFalse(stateSpy.called);

      assert.strictEqual(wrapper.find('RecentCommitsView').prop('selectedCommitSha'), '2');
    });

    it('disregards an unrecognized focus', function() {
      const commits = ['0', '1', '2'].map(s => commitBuilder().sha(s).build());
      const wrapper = mount(React.cloneElement(app, {commits, selectedCommitSha: ''}));
      const stateSpy = sinon.spy(wrapper.instance(), 'setSelectedCommitIndex');
      sinon.stub(wrapper.find('RecentCommitsView').instance(), 'setFocus').returns(false);

      assert.isFalse(wrapper.instance().setFocus(Symbol('unrecognized')));
      assert.isFalse(stateSpy.called);

      assert.strictEqual(wrapper.find('RecentCommitsView').prop('selectedCommitSha'), '');
    });
  });

  describe('workspace tracking', function() {
    beforeEach(function() {
      registerGitHubOpener(atomEnv);
    });

    it('updates the selected sha when its CommitDetailItem is activated', async function() {
      const wrapper = shallow(app);
      await atomEnv.workspace.open(CommitDetailItem.buildURI(workdirPath, 'abcdef'));
      assert.strictEqual(wrapper.find('RecentCommitsView').prop('selectedCommitSha'), 'abcdef');
    });

    it('silently disregards items with no getURI method', async function() {
      const wrapper = shallow(app);
      await atomEnv.workspace.open({item: {}});
      assert.strictEqual(wrapper.find('RecentCommitsView').prop('selectedCommitSha'), '');
    });

    it('silently disregards items that do not match the CommitDetailItem URI pattern', async function() {
      const wrapper = shallow(app);
      await atomEnv.workspace.open(__filename);
      assert.strictEqual(wrapper.find('RecentCommitsView').prop('selectedCommitSha'), '');
    });
  });
});
