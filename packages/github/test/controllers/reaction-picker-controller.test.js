import React from 'react';
import {shallow} from 'enzyme';

import ReactionPickerController from '../../lib/controllers/reaction-picker-controller';
import ReactionPickerView from '../../lib/views/reaction-picker-view';
import RefHolder from '../../lib/models/ref-holder';

describe('ReactionPickerController', function() {
  let atomEnv;

  beforeEach(function() {
    atomEnv = global.buildAtomEnvironment();
  });

  afterEach(function() {
    atomEnv.destroy();
  });

  function buildApp(override = {}) {
    const props = {
      addReaction: () => Promise.resolve(),
      removeReaction: () => Promise.resolve(),
      tooltipHolder: new RefHolder(),
      ...override,
    };

    return <ReactionPickerController {...props} />;
  }

  it('renders a ReactionPickerView and passes props', function() {
    const extra = Symbol('extra');
    const wrapper = shallow(buildApp({extra}));

    assert.strictEqual(wrapper.find(ReactionPickerView).prop('extra'), extra);
  });

  it('adds a reaction, then closes the tooltip', async function() {
    const addReaction = sinon.stub().resolves();

    const mockTooltip = {dispose: sinon.spy()};
    const tooltipHolder = new RefHolder();
    tooltipHolder.setter(mockTooltip);

    const wrapper = shallow(buildApp({addReaction, tooltipHolder}));

    await wrapper.find(ReactionPickerView).prop('addReactionAndClose')('THUMBS_UP');

    assert.isTrue(addReaction.calledWith('THUMBS_UP'));
    assert.isTrue(mockTooltip.dispose.called);
  });

  it('removes a reaction, then closes the tooltip', async function() {
    const removeReaction = sinon.stub().resolves();

    const mockTooltip = {dispose: sinon.spy()};
    const tooltipHolder = new RefHolder();
    tooltipHolder.setter(mockTooltip);

    const wrapper = shallow(buildApp({removeReaction, tooltipHolder}));

    await wrapper.find(ReactionPickerView).prop('removeReactionAndClose')('THUMBS_DOWN');

    assert.isTrue(removeReaction.calledWith('THUMBS_DOWN'));
    assert.isTrue(mockTooltip.dispose.called);
  });
});
