import React from 'react';
import {shallow} from 'enzyme';

import FilePatchMetaView from '../../lib/views/file-patch-meta-view';
import CommitDetailItem from '../../lib/items/commit-detail-item';

describe('FilePatchMetaView', function() {
  let atomEnv;

  beforeEach(function() {
    atomEnv = global.buildAtomEnvironment();
  });

  afterEach(function() {
    atomEnv.destroy();
  });

  function buildApp(overrideProps = {}, children = <div />) {
    return (
      <FilePatchMetaView
        title=""
        actionIcon="icon-move-up"
        actionText="action"

        action={() => {}}

        {...overrideProps}>
        {children}
      </FilePatchMetaView>
    );
  }

  it('renders the title', function() {
    const wrapper = shallow(buildApp({title: 'Yes'}));
    assert.strictEqual(wrapper.find('.github-FilePatchView-metaTitle').text(), 'Yes');
  });

  it('renders a control button with the correct text and callback', function() {
    const action = sinon.stub();
    const wrapper = shallow(buildApp({action, actionText: 'do the thing', actionIcon: 'icon-move-down'}));

    const button = wrapper.find('button.icon-move-down');

    assert.strictEqual(button.text(), 'do the thing');

    button.simulate('click');
    assert.isTrue(action.called);
  });

  it('renders child elements as details', function() {
    const wrapper = shallow(buildApp({}, <div className="child" />));
    assert.isTrue(wrapper.find('.github-FilePatchView-metaDetails .child').exists());
  });

  it('omits controls when rendered in a CommitDetailItem', function() {
    const wrapper = shallow(buildApp({itemType: CommitDetailItem}));
    assert.isTrue(wrapper.find('.github-FilePatchView-metaDetails').exists());
    assert.isFalse(wrapper.find('.github-FilePatchView-metaControls').exists());
  });
});
