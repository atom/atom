import React from 'react';
import {mount} from 'enzyme';

import CommitDetailContainer from '../../lib/containers/commit-detail-container';
import CommitDetailItem from '../../lib/items/commit-detail-item';
import {cloneRepository, buildRepository} from '../helpers';

const VALID_SHA = '18920c900bfa6e4844853e7e246607a31c3e2e8c';

describe('CommitDetailContainer', function() {
  let atomEnv, repository;

  beforeEach(async function() {
    atomEnv = global.buildAtomEnvironment();

    const workdir = await cloneRepository('multiple-commits');
    repository = await buildRepository(workdir);
  });

  afterEach(function() {
    atomEnv.destroy();
  });

  function buildApp(override = {}) {

    const props = {
      repository,
      sha: VALID_SHA,

      itemType: CommitDetailItem,
      workspace: atomEnv.workspace,
      commands: atomEnv.commands,
      keymaps: atomEnv.keymaps,
      tooltips: atomEnv.tooltips,
      config: atomEnv.config,

      destroy: () => {},
      surfaceCommit: () => {},

      ...override,
    };

    return <CommitDetailContainer {...props} />;
  }

  it('renders a loading spinner while the repository is loading', function() {
    const wrapper = mount(buildApp());
    assert.isTrue(wrapper.find('LoadingView').exists());
  });

  it('renders a loading spinner while the file patch is being loaded', async function() {
    await repository.getLoadPromise();
    const commitPromise = repository.getCommit(VALID_SHA);
    let resolveDelayedPromise = () => {};
    const delayedPromise = new Promise(resolve => {
      resolveDelayedPromise = resolve;
    });
    sinon.stub(repository, 'getCommit').returns(delayedPromise);

    const wrapper = mount(buildApp());

    assert.isTrue(wrapper.find('LoadingView').exists());
    resolveDelayedPromise(commitPromise);
    await assert.async.isFalse(wrapper.update().find('LoadingView').exists());
  });

  it('renders a CommitDetailController once the commit is loaded', async function() {
    await repository.getLoadPromise();
    const commit = await repository.getCommit(VALID_SHA);

    const wrapper = mount(buildApp());
    await assert.async.isTrue(wrapper.update().find('CommitDetailController').exists());
    assert.strictEqual(wrapper.find('CommitDetailController').prop('commit'), commit);
  });

  it('forces update when filepatch changes render status', async function() {
    await repository.getLoadPromise();

    const wrapper = mount(buildApp());
    sinon.spy(wrapper.instance(), 'forceUpdate');
    await assert.async.isTrue(wrapper.update().find('CommitDetailController').exists());

    assert.isFalse(wrapper.instance().forceUpdate.called);
    wrapper.find('.github-FilePatchView-collapseButton').simulate('click');
    assert.isTrue(wrapper.instance().forceUpdate.called);
  });
});
