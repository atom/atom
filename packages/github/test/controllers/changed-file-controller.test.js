import React from 'react';
import {shallow} from 'enzyme';

import ChangedFileController from '../../lib/controllers/changed-file-controller';
import {cloneRepository, buildRepository} from '../helpers';

describe('ChangedFileController', function() {
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
      relPath: 'file.txt',

      workspace: atomEnv.workspace,
      commands: atomEnv.commands,
      keymaps: atomEnv.keymaps,
      tooltips: atomEnv.tooltips,
      config: atomEnv.config,
      multiFilePatch: {
        getFilePatches: () => {},
      },

      destroy: () => {},
      undoLastDiscard: () => {},
      surfaceFileAtPath: () => {},

      ...override,
    };

    return <ChangedFileController {...props} />;
  }

  it('passes unrecognized props to a MultiFilePatchController', function() {
    const extra = Symbol('extra');
    const wrapper = shallow(buildApp({extra}));

    assert.strictEqual(wrapper.find('MultiFilePatchController').prop('extra'), extra);
  });

  it('calls surfaceFileAtPath with fixed arguments', function() {
    const surfaceFileAtPath = sinon.spy();
    const wrapper = shallow(buildApp({
      relPath: 'whatever.js',
      stagingStatus: 'staged',
      surfaceFileAtPath,
    }));
    wrapper.find('MultiFilePatchController').prop('surface')();

    assert.isTrue(surfaceFileAtPath.calledWith('whatever.js', 'staged'));
  });
});
