import React from 'react';
import {mount} from 'enzyme';

import GitTabContainer from '../../lib/containers/git-tab-container';
import Repository from '../../lib/models/repository';
import {gitTabContainerProps} from '../fixtures/props/git-tab-props.js';
import {cloneRepository, buildRepository} from '../helpers';

describe('GitTabContainer', function() {
  let atomEnv;

  beforeEach(function() {
    atomEnv = global.buildAtomEnvironment();
  });

  afterEach(function() {
    atomEnv.destroy();
  });

  describe('while the repository is loading', function() {
    let wrapper;

    beforeEach(async function() {
      const workdirPath = await cloneRepository();
      const loadingRepository = new Repository(workdirPath);
      const props = gitTabContainerProps(atomEnv, loadingRepository);

      wrapper = mount(<GitTabContainer {...props} />);
    });

    it('passes default repository props', function() {
      assert.isFalse(wrapper.find('GitTabController').prop('lastCommit').isPresent());
      assert.lengthOf(wrapper.find('GitTabController').prop('recentCommits'), 0);
    });

    it('sets fetchInProgress to true', function() {
      assert.isTrue(wrapper.find('GitTabController').prop('fetchInProgress'));
    });
  });

  describe('when the repository attributes arrive', function() {
    let loadedRepository;

    beforeEach(async function() {
      const workdirPath = await cloneRepository();
      loadedRepository = await buildRepository(workdirPath);
    });

    it('passes them as props', async function() {
      const props = gitTabContainerProps(atomEnv, loadedRepository);
      const wrapper = mount(<GitTabContainer {...props} />);
      await assert.async.isFalse(wrapper.update().find('GitTabController').prop('fetchInProgress'));

      const controller = wrapper.find('GitTabController');

      assert.strictEqual(controller.prop('lastCommit'), await loadedRepository.getLastCommit());
      assert.deepEqual(controller.prop('recentCommits'), await loadedRepository.getRecentCommits({max: 10}));
      assert.strictEqual(controller.prop('isMerging'), await loadedRepository.isMerging());
      assert.strictEqual(controller.prop('isRebasing'), await loadedRepository.isRebasing());
    });

    it('passes other props through', async function() {
      const extraProp = Symbol('extra');
      const props = gitTabContainerProps(atomEnv, loadedRepository, {extraProp});
      const wrapper = mount(<GitTabContainer {...props} />);
      await assert.async.isFalse(wrapper.update().find('GitTabController').prop('fetchInProgress'));

      const controller = wrapper.find('GitTabController');

      assert.strictEqual(controller.prop('extraProp'), extraProp);
    });
  });
});
