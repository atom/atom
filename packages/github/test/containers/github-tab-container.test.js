import React from 'react';
import {mount, shallow} from 'enzyme';

import {buildRepository, cloneRepository} from '../helpers';
import GitHubTabContainer from '../../lib/containers/github-tab-container';
import GitHubTabController from '../../lib/controllers/github-tab-controller';
import Repository from '../../lib/models/repository';
import {InMemoryStrategy} from '../../lib/shared/keytar-strategy';
import GithubLoginModel from '../../lib/models/github-login-model';
import RefHolder from '../../lib/models/ref-holder';

describe('GitHubTabContainer', function() {
  let atomEnv, repository, defaultRepositoryData;

  beforeEach(async function() {
    atomEnv = global.buildAtomEnvironment();
    repository = await buildRepository(await cloneRepository());

    defaultRepositoryData = {
      workingDirectory: repository.getWorkingDirectoryPath(),
      allRemotes: await repository.getRemotes(),
      branches: await repository.getBranches(),
      selectedRemoteName: 'origin',
      aheadCount: 0,
      pushInProgress: false,
    };
  });

  afterEach(function() {
    atomEnv.destroy();
  });

  function buildApp(props = {}) {
    return (
      <GitHubTabContainer
        workspace={atomEnv.workspace}
        repository={repository}
        loginModel={new GithubLoginModel(InMemoryStrategy)}
        rootHolder={new RefHolder()}

        changeWorkingDirectory={() => {}}
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

  describe('refresher', function() {
    let wrapper, retry;

    function stubRepository(repo) {
      sinon.stub(repo.getOperationStates(), 'isFetchInProgress').returns(false);
      sinon.stub(repo.getOperationStates(), 'isPushInProgress').returns(false);
      sinon.stub(repo.getOperationStates(), 'isPullInProgress').returns(false);
    }

    function simulateOperation(repo, name, middle = () => {}) {
      const accessor = `is${name[0].toUpperCase()}${name.slice(1)}InProgress`;
      const methodStub = repo.getOperationStates()[accessor];
      methodStub.returns(true);
      repo.state.didUpdate();
      middle();
      methodStub.returns(false);
      repo.state.didUpdate();
    }

    beforeEach(function() {
      wrapper = shallow(buildApp());
      const childWrapper = wrapper.find('ObserveModel').renderProp('children')(defaultRepositoryData);

      retry = sinon.spy();
      const refresher = childWrapper.find(GitHubTabController).prop('refresher');
      refresher.setRetryCallback(Symbol('key'), retry);

      stubRepository(repository);
    });

    it('triggers a refresh when the current repository completes a fetch, push, or pull', function() {
      assert.isFalse(retry.called);

      simulateOperation(repository, 'fetch', () => assert.isFalse(retry.called));
      assert.strictEqual(retry.callCount, 1);

      simulateOperation(repository, 'push', () => assert.strictEqual(retry.callCount, 1));
      assert.strictEqual(retry.callCount, 2);

      simulateOperation(repository, 'pull', () => assert.strictEqual(retry.callCount, 2));
      assert.strictEqual(retry.callCount, 3);
    });

    it('un-observes an old repository and observes a new one', async function() {
      const other = await buildRepository(await cloneRepository());
      stubRepository(other);
      wrapper.setProps({repository: other});

      simulateOperation(repository, 'fetch');
      assert.isFalse(retry.called);

      simulateOperation(other, 'fetch');
      assert.isTrue(retry.called);
    });

    it('un-observes the repository when unmounting', function() {
      wrapper.unmount();

      simulateOperation(repository, 'fetch');
      assert.isFalse(retry.called);
    });
  });

  describe('while loading', function() {
    it('passes isLoading to its view', async function() {
      const loadingRepo = new Repository(await cloneRepository());
      assert.isTrue(loadingRepo.isLoading());
      const wrapper = mount(buildApp({repository: loadingRepo}));

      assert.isTrue(wrapper.find('GitHubTabController').prop('isLoading'));
    });
  });

  describe('once loaded', function() {
    it('renders the controller', async function() {
      const workdir = await cloneRepository();
      const presentRepo = new Repository(workdir);
      await presentRepo.getLoadPromise();
      const wrapper = mount(buildApp({repository: presentRepo}));

      await assert.async.isFalse(wrapper.update().find('GitHubTabController').prop('isLoading'));
      assert.strictEqual(wrapper.find('GitHubTabController').prop('workingDirectory'), workdir);
    });
  });
});
