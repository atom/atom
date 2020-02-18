import React from 'react';
import {shallow} from 'enzyme';

import BranchMenuView from '../../lib/views/branch-menu-view';
import Branch, {nullBranch} from '../../lib/models/branch';
import BranchSet from '../../lib/models/branch-set';
import {cloneRepository, buildRepository} from '../helpers';

describe('BranchMenuView', function() {
  let atomEnv, repository;

  beforeEach(async function() {
    atomEnv = global.buildAtomEnvironment();

    repository = await buildRepository(await cloneRepository());
  });

  afterEach(function() {
    atomEnv.destroy();
  });

  function buildApp(overrides = {}) {
    const currentBranch = new Branch('master', nullBranch, nullBranch, true);
    const branches = new BranchSet([currentBranch]);

    return (
      <BranchMenuView
        workspace={atomEnv.workspace}
        commandRegistry={atomEnv.commands}
        notificationManager={atomEnv.notifications}
        repository={repository}
        branches={branches}
        currentBranch={currentBranch}
        checkout={() => {}}
        {...overrides}
      />
    );
  }

  it('cancels new branch creation', function() {
    const wrapper = shallow(buildApp());
    wrapper.find('.github-BranchMenuView-button').simulate('click');
    wrapper.find('Command[command="core:cancel"]').prop('callback')();

    assert.isTrue(wrapper.find('.github-BranchMenuView-editor').hasClass('hidden'));
    assert.isFalse(wrapper.find('.github-BranchMenuView-select').hasClass('hidden'));
  });
});
