import React from 'react';
import {mount} from 'enzyme';
import fs from 'fs-extra';
import path from 'path';

import CommitPreviewContainer from '../../lib/containers/commit-preview-container';
import CommitPreviewItem from '../../lib/items/commit-preview-item';
import {DEFERRED, EXPANDED} from '../../lib/models/patch/patch';
import {cloneRepository, buildRepository} from '../helpers';

describe('CommitPreviewContainer', function() {
  let atomEnv, repository;

  beforeEach(async function() {
    atomEnv = global.buildAtomEnvironment();

    const workdir = await cloneRepository();
    repository = await buildRepository(workdir);
  });

  afterEach(function() {
    atomEnv.destroy();
  });

  function buildApp(override = {}) {

    const props = {
      repository,
      itemType: CommitPreviewItem,

      workspace: atomEnv.workspace,
      commands: atomEnv.commands,
      keymaps: atomEnv.keymaps,
      tooltips: atomEnv.tooltips,
      config: atomEnv.config,

      destroy: () => {},
      discardLines: () => {},
      undoLastDiscard: () => {},
      surfaceToCommitPreviewButton: () => {},

      ...override,
    };

    return <CommitPreviewContainer {...props} />;
  }

  it('renders a loading spinner while the repository is loading', function() {
    const wrapper = mount(buildApp());
    assert.isTrue(wrapper.find('LoadingView').exists());
  });

  it('renders a loading spinner while the file patch is being loaded', async function() {
    await repository.getLoadPromise();
    const patchPromise = repository.getStagedChangesPatch();
    let resolveDelayedPromise = () => {};
    const delayedPromise = new Promise(resolve => {
      resolveDelayedPromise = resolve;
    });
    sinon.stub(repository, 'getStagedChangesPatch').returns(delayedPromise);

    const wrapper = mount(buildApp());

    assert.isTrue(wrapper.find('LoadingView').exists());
    resolveDelayedPromise(patchPromise);
    await assert.async.isFalse(wrapper.update().find('LoadingView').exists());
  });

  it('renders a CommitPreviewController once the file patch is loaded', async function() {
    await repository.getLoadPromise();
    const patch = await repository.getStagedChangesPatch();

    const wrapper = mount(buildApp());
    await assert.async.isTrue(wrapper.update().find('CommitPreviewController').exists());
    assert.strictEqual(wrapper.find('CommitPreviewController').prop('multiFilePatch'), patch);
  });

  it('remembers previously expanded large patches', async function() {
    const wd = repository.getWorkingDirectoryPath();
    await repository.getLoadPromise();

    await fs.writeFile(path.join(wd, 'file-0.txt'), '0\n1\n2\n3\n4\n5\n', {encoding: 'utf8'});
    await fs.writeFile(path.join(wd, 'file-1.txt'), '0\n1\n2\n', {encoding: 'utf8'});
    await repository.stageFiles(['file-0.txt', 'file-1.txt']);

    repository.refresh();

    const wrapper = mount(buildApp({largeDiffThreshold: 3}));
    await assert.async.isTrue(wrapper.update().exists('CommitPreviewController'));

    const before = wrapper.find('CommitPreviewController').prop('multiFilePatch');
    assert.strictEqual(before.getFilePatches()[0].getRenderStatus(), DEFERRED);
    assert.strictEqual(before.getFilePatches()[1].getRenderStatus(), EXPANDED);

    before.expandFilePatch(before.getFilePatches()[0]);
    repository.refresh();

    await assert.async.notStrictEqual(wrapper.update().find('CommitPreviewController').prop('multiFilePatch'), before);
    const after = wrapper.find('CommitPreviewController').prop('multiFilePatch');

    assert.strictEqual(after.getFilePatches()[0].getRenderStatus(), EXPANDED);
    assert.strictEqual(after.getFilePatches()[1].getRenderStatus(), EXPANDED);
  });
});
