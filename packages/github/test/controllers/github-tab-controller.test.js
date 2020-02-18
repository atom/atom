import React from 'react';
import {shallow} from 'enzyme';

import GitHubTabController from '../../lib/controllers/github-tab-controller';
import Repository from '../../lib/models/repository';
import BranchSet from '../../lib/models/branch-set';
import Branch, {nullBranch} from '../../lib/models/branch';
import RemoteSet from '../../lib/models/remote-set';
import Remote from '../../lib/models/remote';
import {InMemoryStrategy} from '../../lib/shared/keytar-strategy';
import GithubLoginModel from '../../lib/models/github-login-model';
import RefHolder from '../../lib/models/ref-holder';
import Refresher from '../../lib/models/refresher';

import {buildRepository, cloneRepository} from '../helpers';

describe('GitHubTabController', function() {
  let atomEnv, repository;

  beforeEach(async function() {
    atomEnv = global.buildAtomEnvironment();
    repository = await buildRepository(await cloneRepository());
  });

  afterEach(function() {
    atomEnv.destroy();
  });

  function buildApp(props = {}) {
    const repo = props.repository || repository;

    return (
      <GitHubTabController
        workspace={atomEnv.workspace}
        refresher={new Refresher()}
        loginModel={new GithubLoginModel(InMemoryStrategy)}
        rootHolder={new RefHolder()}

        workingDirectory={repo.getWorkingDirectoryPath()}
        repository={repo}
        allRemotes={new RemoteSet()}
        branches={new BranchSet()}
        pushInProgress={false}
        isLoading={false}
        currentWorkDir={repo.getWorkingDirectoryPath()}

        changeWorkingDirectory={() => {}}
        setContextLock={() => {}}
        contextLocked={false}
        onDidChangeWorkDirs={() => {}}
        getCurrentWorkDirs={() => []}
        openCreateDialog={() => {}}
        openPublishDialog={() => {}}
        openCloneDialog={() => {}}
        openGitTab={() => {}}

        {...props}
      />
    );
  }

  describe('derived view props', function() {
    const dotcom0 = new Remote('yes0', 'git@github.com:aaa/bbb.git');
    const dotcom1 = new Remote('yes1', 'https://github.com/ccc/ddd.git');
    const nonDotcom = new Remote('no0', 'git@sourceforge.net:eee/fff.git');

    it('passes the current branch', function() {
      const currentBranch = new Branch('aaa', nullBranch, nullBranch, true);
      const otherBranch = new Branch('bbb');
      const branches = new BranchSet([currentBranch, otherBranch]);
      const wrapper = shallow(buildApp({branches}));

      assert.strictEqual(wrapper.find('GitHubTabView').prop('currentBranch'), currentBranch);
    });

    it('passes remotes hosted on GitHub', function() {
      const allRemotes = new RemoteSet([dotcom0, dotcom1, nonDotcom]);
      const wrapper = shallow(buildApp({allRemotes}));

      const passed = wrapper.find('GitHubTabView').prop('remotes');
      assert.isTrue(passed.withName('yes0').isPresent());
      assert.isTrue(passed.withName('yes1').isPresent());
      assert.isFalse(passed.withName('no0').isPresent());
    });

    it('detects an explicitly specified current remote', function() {
      const allRemotes = new RemoteSet([dotcom0, dotcom1, nonDotcom]);
      const wrapper = shallow(buildApp({allRemotes, selectedRemoteName: 'yes1'}));
      assert.strictEqual(wrapper.find('GitHubTabView').prop('currentRemote'), dotcom1);
      assert.isFalse(wrapper.find('GitHubTabView').prop('manyRemotesAvailable'));
    });

    it('uses a single GitHub-hosted remote', function() {
      const allRemotes = new RemoteSet([dotcom0, nonDotcom]);
      const wrapper = shallow(buildApp({allRemotes}));
      assert.strictEqual(wrapper.find('GitHubTabView').prop('currentRemote'), dotcom0);
      assert.isFalse(wrapper.find('GitHubTabView').prop('manyRemotesAvailable'));
    });

    it('indicates when multiple remotes are available', function() {
      const allRemotes = new RemoteSet([dotcom0, dotcom1]);
      const wrapper = shallow(buildApp({allRemotes}));
      assert.isFalse(wrapper.find('GitHubTabView').prop('currentRemote').isPresent());
      assert.isTrue(wrapper.find('GitHubTabView').prop('manyRemotesAvailable'));
    });
  });

  describe('actions', function() {
    it('pushes a branch', async function() {
      const absent = Repository.absent();
      sinon.stub(absent, 'push').resolves(true);
      const wrapper = shallow(buildApp({repository: absent}));

      const branch = new Branch('abc');
      const remote = new Remote('def', 'git@github.com:def/ghi.git');
      assert.isTrue(await wrapper.find('GitHubTabView').prop('handlePushBranch')(branch, remote));

      assert.isTrue(absent.push.calledWith('abc', {remote, setUpstream: true}));
    });

    it('chooses a remote', async function() {
      const absent = Repository.absent();
      sinon.stub(absent, 'setConfig').resolves(true);
      const wrapper = shallow(buildApp({repository: absent}));

      const remote = new Remote('aaa', 'git@github.com:aaa/aaa.git');
      const event = {preventDefault: sinon.spy()};
      assert.isTrue(await wrapper.find('GitHubTabView').prop('handleRemoteSelect')(event, remote));

      assert.isTrue(event.preventDefault.called);
      assert.isTrue(absent.setConfig.calledWith('atomGithub.currentRemote', 'aaa'));
    });

    it('opens the publish dialog on the active repository', async function() {
      const someRepo = await buildRepository(await cloneRepository());
      const openPublishDialog = sinon.spy();
      const wrapper = shallow(buildApp({repository: someRepo, openPublishDialog}));

      wrapper.find('GitHubTabView').prop('openBoundPublishDialog')();
      assert.isTrue(openPublishDialog.calledWith(someRepo));
    });
  });
});
