import React from 'react';
import {shallow} from 'enzyme';

import {BareEmojiReactionsView} from '../../lib/views/emoji-reactions-view';
import ReactionPickerController from '../../lib/controllers/reaction-picker-controller';
import {issueBuilder} from '../builder/graphql/issue';

import reactableQuery from '../../lib/views/__generated__/emojiReactionsView_reactable.graphql';

describe('EmojiReactionsView', function() {
  let atomEnv;

  beforeEach(function() {
    atomEnv = global.buildAtomEnvironment();
  });

  afterEach(function() {
    atomEnv.destroy();
  });

  function buildApp(override = {}) {
    return (
      <BareEmojiReactionsView
        reactable={issueBuilder(reactableQuery).build()}
        addReaction={() => {}}
        removeReaction={() => {}}
        tooltips={atomEnv.tooltips}
        {...override}
      />
    );
  }

  it('renders reaction groups', function() {
    const reactable = issueBuilder(reactableQuery)
      .addReactionGroup(group => group.content('THUMBS_UP').users(u => u.totalCount(10)))
      .addReactionGroup(group => group.content('THUMBS_DOWN').users(u => u.totalCount(5)))
      .addReactionGroup(group => group.content('ROCKET').users(u => u.totalCount(42)))
      .addReactionGroup(group => group.content('EYES').users(u => u.totalCount(13)))
      .addReactionGroup(group => group.content('LAUGH').users(u => u.totalCount(0)))
      .build();

    const wrapper = shallow(buildApp({reactable}));

    const groups = wrapper.find('.github-EmojiReactions-group');
    assert.lengthOf(groups.findWhere(n => /👍/u.test(n.text()) && /\b10\b/.test(n.text())), 1);
    assert.lengthOf(groups.findWhere(n => /👎/u.test(n.text()) && /\b5\b/.test(n.text())), 1);
    assert.lengthOf(groups.findWhere(n => /🚀/u.test(n.text()) && /\b42\b/.test(n.text())), 1);
    assert.lengthOf(groups.findWhere(n => /👀/u.test(n.text()) && /\b13\b/.test(n.text())), 1);
    assert.isFalse(groups.someWhere(n => /😆/u.test(n.text())));
  });

  it('gracefully skips unknown emoji', function() {
    const reactable = issueBuilder(reactableQuery)
      .addReactionGroup(group => group.content('AVOCADO').users(u => u.totalCount(11)))
      .build();

    const wrapper = shallow(buildApp({reactable}));
    assert.notMatch(wrapper.text(), /\b11\b/);
  });

  it("shows which reactions you've personally given", function() {
    const reactable = issueBuilder(reactableQuery)
      .addReactionGroup(group => group.content('ROCKET').users(u => u.totalCount(5)).viewerHasReacted(true))
      .addReactionGroup(group => group.content('EYES').users(u => u.totalCount(7)).viewerHasReacted(false))
      .build();

    const wrapper = shallow(buildApp({reactable}));

    assert.isTrue(wrapper.find('.github-EmojiReactions-group.rocket').hasClass('selected'));
    assert.isFalse(wrapper.find('.github-EmojiReactions-group.eyes').hasClass('selected'));
  });

  it('adds a reaction to an existing emoji on click', function() {
    const addReaction = sinon.spy();

    const reactable = issueBuilder(reactableQuery)
      .addReactionGroup(group => group.content('THUMBS_UP').users(u => u.totalCount(2)).viewerHasReacted(false))
      .build();

    const wrapper = shallow(buildApp({addReaction, reactable}));

    wrapper.find('.github-EmojiReactions-group.thumbs_up').simulate('click');
    assert.isTrue(addReaction.calledWith('THUMBS_UP'));
  });

  it('removes a reaction from an existing emoji on click', function() {
    const removeReaction = sinon.spy();

    const reactable = issueBuilder(reactableQuery)
      .addReactionGroup(group => group.content('THUMBS_DOWN').users(u => u.totalCount(3)).viewerHasReacted(true))
      .build();

    const wrapper = shallow(buildApp({removeReaction, reactable}));

    wrapper.find('.github-EmojiReactions-group.thumbs_down').simulate('click');
    assert.isTrue(removeReaction.calledWith('THUMBS_DOWN'));
  });

  it('disables the reaction toggle buttons if the viewer cannot react', function() {
    const reactable = issueBuilder(reactableQuery)
      .viewerCanReact(false)
      .addReactionGroup(group => group.content('THUMBS_UP').users(u => u.totalCount(2)))
      .build();

    const wrapper = shallow(buildApp({reactable}));

    assert.isTrue(wrapper.find('.github-EmojiReactions-group.thumbs_up').prop('disabled'));
  });

  it('displays an "add emoji" control if at least one reaction group is empty', function() {
    const reactable = issueBuilder(reactableQuery)
      .addReactionGroup(group => group.content('THUMBS_UP').users(u => u.totalCount(2)))
      .addReactionGroup(group => group.content('THUMBS_DOWN').users(u => u.totalCount(0)))
      .build();

    const wrapper = shallow(buildApp({reactable}));
    assert.isTrue(wrapper.exists('.github-EmojiReactions-add'));
    assert.isTrue(wrapper.find(ReactionPickerController).exists());
  });

  it('displays an "add emoji" control when no reaction groups are present', function() {
    // This happens when the Reactable is optimistically rendered.
    const reactable = issueBuilder(reactableQuery).build();

    const wrapper = shallow(buildApp({reactable}));
    assert.isTrue(wrapper.exists('.github-EmojiReactions-add'));
    assert.isTrue(wrapper.find(ReactionPickerController).exists());
  });

  it('does not display the "add emoji" control if all reaction groups are nonempty', function() {
    const reactable = issueBuilder(reactableQuery)
      .addReactionGroup(group => group.content('THUMBS_UP').users(u => u.totalCount(1)))
      .addReactionGroup(group => group.content('THUMBS_DOWN').users(u => u.totalCount(1)))
      .addReactionGroup(group => group.content('ROCKET').users(u => u.totalCount(1)))
      .addReactionGroup(group => group.content('EYES').users(u => u.totalCount(1)))
      .build();

    const wrapper = shallow(buildApp({reactable}));
    assert.isFalse(wrapper.exists('.github-EmojiReactions-add'));
    assert.isFalse(wrapper.find(ReactionPickerController).exists());
  });

  it('disables the "add emoji" control if the viewer cannot react', function() {
    const reactable = issueBuilder(reactableQuery)
      .viewerCanReact(false)
      .addReactionGroup(group => group.content('THUMBS_UP').users(u => u.totalCount(1)))
      .addReactionGroup(group => group.content('THUMBS_DOWN').users(u => u.totalCount(0)))
      .build();

    const wrapper = shallow(buildApp({reactable}));
    assert.isTrue(wrapper.find('.github-EmojiReactions-add').prop('disabled'));
  });
});
