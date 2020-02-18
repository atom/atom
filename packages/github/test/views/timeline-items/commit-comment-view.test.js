import React from 'react';
import {shallow} from 'enzyme';

import {BareCommitCommentView} from '../../../lib/views/timeline-items/commit-comment-view';
import {createCommitComment} from '../../fixtures/factories/commit-comment-thread-results';
import {GHOST_USER} from '../../../lib/helpers';

describe('CommitCommentView', function() {
  function buildApp(opts, overloadProps = {}) {
    const props = {
      item: createCommitComment(opts),
      isReply: false,
      switchToIssueish: () => {},
      ...overloadProps,
    };

    return <BareCommitCommentView {...props} />;
  }

  it('renders comment data', function() {
    const wrapper = shallow(buildApp({
      commitOid: '0000ffff0000ffff',
      authorLogin: 'me',
      authorAvatarUrl: 'https://avatars2.githubusercontent.com/u/1?v=2',
      bodyHTML: '<p>text here</p>',
      createdAt: '2018-06-28T15:04:05Z',
    }));

    assert.isTrue(wrapper.find('Octicon[icon="comment"]').hasClass('pre-timeline-item-icon'));

    const avatarImg = wrapper.find('img.author-avatar');
    assert.strictEqual(avatarImg.prop('src'), 'https://avatars2.githubusercontent.com/u/1?v=2');
    assert.strictEqual(avatarImg.prop('title'), 'me');

    const headerText = wrapper.find('.comment-message-header').text();
    assert.match(headerText, /^me commented/);
    assert.match(headerText, /in 0000fff/);
    assert.strictEqual(wrapper.find('Timeago').prop('time'), '2018-06-28T15:04:05Z');

    assert.strictEqual(wrapper.find('GithubDotcomMarkdown').prop('html'), '<p>text here</p>');
  });

  it('shows ghost user when author is null', function() {
    const wrapper = shallow(buildApp({includeAuthor: false}));

    assert.match(wrapper.find('.comment-message-header').text(), new RegExp(`^${GHOST_USER.login}`));
    assert.strictEqual(wrapper.find('.author-avatar').prop('src'), GHOST_USER.avatarUrl);
    assert.strictEqual(wrapper.find('.author-avatar').prop('alt'), GHOST_USER.login);
  });

  it('renders a reply comment', function() {
    const wrapper = shallow(buildApp({
      authorLogin: 'me',
      createdAt: '2018-06-29T15:04:05Z',
    }, {isReply: true}));

    assert.isFalse(wrapper.find('.pre-timeline-item-icon').exists());

    assert.match(wrapper.find('.comment-message-header').text(), /^me replied/);
    assert.strictEqual(wrapper.find('Timeago').prop('time'), '2018-06-29T15:04:05Z');
  });

  it('renders a path when available', function() {
    const wrapper = shallow(buildApp({
      commentPath: 'aaa/bbb/ccc.txt',
    }));

    assert.match(wrapper.find('.comment-message-header').text(), /on aaa\/bbb\/ccc.txt/);
  });
});
