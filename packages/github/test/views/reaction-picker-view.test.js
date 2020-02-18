import React from 'react';
import {shallow} from 'enzyme';

import ReactionPickerView from '../../lib/views/reaction-picker-view';
import {reactionTypeToEmoji} from '../../lib/helpers';

describe('ReactionPickerView', function() {
  let atomEnv;

  beforeEach(function() {
    atomEnv = global.buildAtomEnvironment();
  });

  afterEach(function() {
    atomEnv.destroy();
  });

  function buildApp(override = {}) {
    const props = {
      viewerReacted: [],
      addReactionAndClose: () => {},
      removeReactionAndClose: () => {},
      ...override,
    };

    return <ReactionPickerView {...props} />;
  }

  it('renders a button for each known content type', function() {
    const knownTypes = Object.keys(reactionTypeToEmoji);
    assert.include(knownTypes, 'THUMBS_UP');

    const wrapper = shallow(buildApp());

    for (const contentType of knownTypes) {
      assert.isTrue(
        wrapper
          .find('.github-ReactionPicker-reaction')
          .someWhere(w => w.text().includes(reactionTypeToEmoji[contentType])),
        `does not include a button for ${contentType}`,
      );
    }
  });

  it('adds the "selected" class to buttons included in viewerReacted', function() {
    const viewerReacted = ['THUMBS_UP', 'ROCKET'];
    const wrapper = shallow(buildApp({viewerReacted}));

    const reactions = wrapper.find('.github-ReactionPicker-reaction');
    const selectedReactions = reactions.find('.selected').map(w => w.text());
    assert.sameMembers(selectedReactions, [reactionTypeToEmoji.ROCKET, reactionTypeToEmoji.THUMBS_UP]);
  });

  it('calls addReactionAndClose when clicking a reaction button', function() {
    const addReactionAndClose = sinon.spy();
    const wrapper = shallow(buildApp({addReactionAndClose}));

    wrapper
      .find('.github-ReactionPicker-reaction')
      .filterWhere(w => w.text().includes(reactionTypeToEmoji.LAUGH))
      .simulate('click');

    assert.isTrue(addReactionAndClose.calledWith('LAUGH'));
  });

  it('calls removeReactionAndClose when clicking a reaction in viewerReacted', function() {
    const removeReactionAndClose = sinon.spy();
    const wrapper = shallow(buildApp({viewerReacted: ['CONFUSED', 'HEART'], removeReactionAndClose}));

    wrapper
      .find('.github-ReactionPicker-reaction')
      .filterWhere(w => w.text().includes(reactionTypeToEmoji.CONFUSED))
      .simulate('click');

    assert.isTrue(removeReactionAndClose.calledWith('CONFUSED'));
  });
});
