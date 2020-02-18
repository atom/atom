import React from 'react';
import {mount} from 'enzyme';

import PaneItem from '../../lib/atom/pane-item';
import GitTabItem from '../../lib/items/git-tab-item';
import {cloneRepository, buildRepository} from '../helpers';
import {gitTabItemProps} from '../fixtures/props/git-tab-props';

describe('GitTabItem', function() {
  let atomEnv, repository;

  beforeEach(async function() {
    atomEnv = global.buildAtomEnvironment();

    const workdirPath = await cloneRepository();
    repository = await buildRepository(workdirPath);
  });

  afterEach(function() {
    atomEnv.destroy();
  });

  function buildApp(overrideProps = {}) {
    const props = gitTabItemProps(atomEnv, repository, overrideProps);

    return (
      <PaneItem workspace={props.workspace} uriPattern={GitTabItem.uriPattern}>
        {({itemHolder}) => (
          <GitTabItem
            ref={itemHolder.setter}
            {...props}
          />
        )}
      </PaneItem>
    );
  }

  it('forwards all props to the GitTabContainer', async function() {
    const extraProp = Symbol('extra');
    const wrapper = mount(buildApp({extraProp}));
    await atomEnv.workspace.open(GitTabItem.buildURI());

    assert.strictEqual(wrapper.update().find('GitTabContainer').prop('extraProp'), extraProp);
  });

  it('renders within the dock with the component as its owner', async function() {
    mount(buildApp());

    await atomEnv.workspace.open(GitTabItem.buildURI());

    const paneItem = atomEnv.workspace.getRightDock().getPaneItems()
      .find(item => item.getURI() === 'atom-github://dock-item/git');
    assert.strictEqual(paneItem.getTitle(), 'Git');
  });

  it('forwards imperative focus manipulation methods to its controller', async function() {
    const wrapper = mount(buildApp());
    await atomEnv.workspace.open(GitTabItem.buildURI());
    await assert.async.isTrue(wrapper.update().find('GitTabController').exists());

    const focusMethods = [
      'focusAndSelectStagingItem',
      'focusAndSelectCommitPreviewButton',
      'focusAndSelectRecentCommit',
    ];

    const spies = focusMethods.reduce((map, focusMethod) => {
      map[focusMethod] = sinon.stub(wrapper.find('GitTabController').instance(), focusMethod);
      return map;
    }, {});

    for (const method of focusMethods) {
      wrapper.find('GitTabItem').instance()[method]();
      assert.isTrue(spies[method].called);
    }
  });
});
