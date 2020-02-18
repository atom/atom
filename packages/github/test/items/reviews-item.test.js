import React from 'react';
import {mount} from 'enzyme';

import ReviewsItem from '../../lib/items/reviews-item';
import {cloneRepository} from '../helpers';
import PaneItem from '../../lib/atom/pane-item';
import {InMemoryStrategy} from '../../lib/shared/keytar-strategy';
import GithubLoginModel from '../../lib/models/github-login-model';
import WorkdirContextPool from '../../lib/models/workdir-context-pool';

describe('ReviewsItem', function() {
  let atomEnv, repository, pool;

  beforeEach(async function() {
    atomEnv = global.buildAtomEnvironment();
    const workdir = await cloneRepository();

    pool = new WorkdirContextPool({
      workspace: atomEnv.workspace,
    });

    repository = pool.add(workdir).getRepository();
  });

  afterEach(function() {
    atomEnv.destroy();
    pool.clear();
  });

  function buildPaneApp(override = {}) {
    const props = {
      workdirContextPool: pool,
      loginModel: new GithubLoginModel(InMemoryStrategy),

      workspace: atomEnv.workspace,
      config: atomEnv.config,
      commands: atomEnv.commands,
      tooltips: atomEnv.tooltips,
      reportRelayError: () => {},

      ...override,
    };

    return (
      <PaneItem workspace={atomEnv.workspace} uriPattern={ReviewsItem.uriPattern}>
        {({itemHolder, params}) => (
          <ReviewsItem
            ref={itemHolder.setter}
            {...params}
            number={parseInt(params.number, 10)}
            {...props}
          />
        )}
      </PaneItem>
    );
  }

  async function open(wrapper, options = {}) {
    const opts = {
      host: 'github.com',
      owner: 'atom',
      repo: 'github',
      number: 1848,
      workdir: repository.getWorkingDirectoryPath(),
      ...options,
    };

    const uri = ReviewsItem.buildURI(opts);
    const item = await atomEnv.workspace.open(uri);
    wrapper.update();
    return item;
  }

  it('constructs and opens the correct URI', async function() {
    const wrapper = mount(buildPaneApp());
    assert.isFalse(wrapper.exists('ReviewsItem'));
    await open(wrapper);
    assert.isTrue(wrapper.exists('ReviewsItem'));
  });

  it('locates the repository from the context pool', async function() {
    const wrapper = mount(buildPaneApp());
    await open(wrapper);

    assert.strictEqual(wrapper.find('ReviewsContainer').prop('repository'), repository);
  });

  it('uses an absent repository if no workdir is provided', async function() {
    const wrapper = mount(buildPaneApp());
    await open(wrapper, {workdir: null});

    assert.isTrue(wrapper.find('ReviewsContainer').prop('repository').isAbsent());
  });

  it('returns a title containing the pull request number', async function() {
    const wrapper = mount(buildPaneApp());
    const item = await open(wrapper, {number: 1234});

    assert.strictEqual(item.getTitle(), 'Reviews #1234');
  });

  it('may be destroyed once', async function() {
    const wrapper = mount(buildPaneApp());

    const item = await open(wrapper);
    const callback = sinon.spy();
    const sub = item.onDidDestroy(callback);

    assert.strictEqual(callback.callCount, 0);
    item.destroy();
    assert.strictEqual(callback.callCount, 1);

    sub.dispose();
  });

  it('serializes itself as a ReviewsItemStub', async function() {
    const wrapper = mount(buildPaneApp());
    const item = await open(wrapper, {host: 'github.horse', owner: 'atom', repo: 'atom', number: 12, workdir: '/here'});
    assert.deepEqual(item.serialize(), {
      deserializer: 'ReviewsStub',
      uri: 'atom-github://reviews/github.horse/atom/atom/12?workdir=%2Fhere',
    });
  });

  it('jumps to thread', async function() {
    const wrapper = mount(buildPaneApp());
    const item = await open(wrapper);
    assert.isNull(item.state.initThreadID);

    await item.jumpToThread('an-id');
    assert.strictEqual(item.state.initThreadID, 'an-id');

    // Jumping to the same ID toggles initThreadID to null and back, but we can't really test the intermediate
    // state there so OH WELL
    await item.jumpToThread('an-id');
    assert.strictEqual(item.state.initThreadID, 'an-id');
  });
});
