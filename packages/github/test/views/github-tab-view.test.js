import React from 'react';
import {shallow} from 'enzyme';
import temp from 'temp';

import Repository from '../../lib/models/repository';
import Remote, {nullRemote} from '../../lib/models/remote';
import RemoteSet from '../../lib/models/remote-set';
import Branch, {nullBranch} from '../../lib/models/branch';
import BranchSet from '../../lib/models/branch-set';
import GitHubTabView from '../../lib/views/github-tab-view';
import {InMemoryStrategy} from '../../lib/shared/keytar-strategy';
import GithubLoginModel from '../../lib/models/github-login-model';
import RefHolder from '../../lib/models/ref-holder';
import Refresher from '../../lib/models/refresher';

import {buildRepository, cloneRepository} from '../helpers';

describe('GitHubTabView', function() {
  let atomEnv;

  beforeEach(function() {
    atomEnv = global.buildAtomEnvironment();
  });

  afterEach(function() {
    atomEnv.destroy();
  });

  function buildApp(props) {
    const repo = props.repository || Repository.absent();

    return (
      <GitHubTabView
        refresher={new Refresher()}
        rootHolder={new RefHolder()}

        loginModel={new GithubLoginModel(InMemoryStrategy)}

        workspace={atomEnv.workspace}
        workingDirectory={repo.getWorkingDirectoryPath()}
        getCurrentWorkDirs={() => []}
        changeWorkingDirectory={() => {}}
        contextLocked={false}
        setContextLock={() => {}}
        repository={repo}

        remotes={new RemoteSet()}
        currentRemote={nullRemote}
        manyRemotesAvailable={false}
        isLoading={false}
        branches={new BranchSet()}
        currentBranch={nullBranch}
        pushInProgress={false}

        handleWorkDirSelect={() => {}}
        handlePushBranch={() => {}}
        handleRemoteSelect={() => {}}
        onDidChangeWorkDirs={() => {}}
        openCreateDialog={() => {}}
        openBoundPublishDialog={() => {}}
        openCloneDialog={() => {}}
        openGitTab={() => {}}

        {...props}
      />
    );
  }

  it('renders a LoadingView if data is still loading', function() {
    const wrapper = shallow(buildApp({isLoading: true}));
    assert.isTrue(wrapper.find('LoadingView').exists());
  });

  it('renders a no-local view when no local repository is found', function() {
    const wrapper = shallow(buildApp({
      repository: Repository.absent(),
    }));
    assert.isTrue(wrapper.exists('GitHubBlankNoLocal'));
  });

  it('renders a uninitialized view when a local repository is not initialized', async function() {
    const workdir = temp.mkdirSync();
    const repository = await buildRepository(workdir);

    const wrapper = shallow(buildApp({repository}));
    assert.isTrue(wrapper.exists('GitHubBlankUninitialized'));
  });

  it('renders a no-remote view when the local repository has no remotes', async function() {
    const repository = await buildRepository(await cloneRepository());

    const wrapper = shallow(buildApp({repository, currentRemote: nullRemote, manyRemotesAvailable: false}));
    assert.isTrue(wrapper.exists('GitHubBlankNoRemote'));
  });

  it('renders a RemoteContainer if a remote has been chosen', async function() {
    const repository = await buildRepository(await cloneRepository());
    const currentRemote = new Remote('aaa', 'git@github.com:aaa/bbb.git');
    const currentBranch = new Branch('bbb');
    const handlePushBranch = sinon.spy();
    const wrapper = shallow(buildApp({repository, currentRemote, currentBranch, handlePushBranch}));

    const container = wrapper.find('RemoteContainer');
    assert.isTrue(container.exists());
    assert.strictEqual(container.prop('remote'), currentRemote);
    container.prop('onPushBranch')();
    assert.isTrue(handlePushBranch.calledWith(currentBranch, currentRemote));
  });

  it('renders a RemoteSelectorView when many remote choices are available', async function() {
    const repository = await buildRepository(await cloneRepository());
    const remotes = new RemoteSet();
    const handleRemoteSelect = sinon.spy();
    const wrapper = shallow(buildApp({
      repository,
      remotes,
      currentRemote: nullRemote,
      manyRemotesAvailable: true,
      handleRemoteSelect,
    }));

    const selector = wrapper.find('RemoteSelectorView');
    assert.isTrue(selector.exists());
    assert.strictEqual(selector.prop('remotes'), remotes);
    selector.prop('selectRemote')();
    assert.isTrue(handleRemoteSelect.called);
  });

  it('calls changeWorkingDirectory when a project is selected', function() {
    const currentRemote = new Remote('aaa', 'git@github.com:aaa/bbb.git');
    const changeWorkingDirectory = sinon.spy();
    const wrapper = shallow(buildApp({currentRemote, changeWorkingDirectory}));
    wrapper.find('GithubTabHeaderContainer').prop('changeWorkingDirectory')('some-path');
    assert.isTrue(changeWorkingDirectory.calledWith('some-path'));
  });
});
