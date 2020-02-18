import React from 'react';
import {shallow} from 'enzyme';

import CommitPreviewController from '../../lib/controllers/commit-preview-controller';
import MultiFilePatch from '../../lib/models/patch/multi-file-patch';
import {cloneRepository, buildRepository} from '../helpers';

describe('CommitPreviewController', function() {
  let atomEnv, repository;

  beforeEach(async function() {
    atomEnv = global.buildAtomEnvironment();
    repository = await buildRepository(await cloneRepository('three-files'));
  });

  afterEach(function() {
    atomEnv.destroy();
  });

  function buildApp(override = {}) {
    const props = {
      repository,
      stagingStatus: 'unstaged',
      multiFilePatch: MultiFilePatch.createNull(),

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

    return <CommitPreviewController {...props} />;
  }

  it('passes unrecognized props to a MultiFilePatchController', function() {
    const extra = Symbol('extra');
    const wrapper = shallow(buildApp({extra}));

    assert.strictEqual(wrapper.find('MultiFilePatchController').prop('extra'), extra);
  });

  it('calls surfaceToCommitPreviewButton', function() {
    const surfaceToCommitPreviewButton = sinon.spy();
    const wrapper = shallow(buildApp({surfaceToCommitPreviewButton}));
    wrapper.find('MultiFilePatchController').prop('surface')();

    assert.isTrue(surfaceToCommitPreviewButton.called);
  });
});
