import React from 'react';
import {shallow} from 'enzyme';

import {BareCommitCommentThreadView} from '../../../lib/views/timeline-items/commit-comment-thread-view';
import CommitCommentView from '../../../lib/views/timeline-items/commit-comment-view';
import {createCommitCommentThread} from '../../fixtures/factories/commit-comment-thread-results';

describe('CommitCommentThreadView', function() {
  function buildApp(opts, overloadProps = {}) {
    const props = {
      item: createCommitCommentThread(opts),
      switchToIssueish: () => {},
      ...overloadProps,
    };

    return <BareCommitCommentThreadView {...props} />;
  }

  it('renders a CommitCommentView for each comment', function() {
    const wrapper = shallow(buildApp({
      commitCommentOpts: [
        {authorLogin: 'user0'},
        {authorLogin: 'user1'},
        {authorLogin: 'user2'},
      ],
    }));

    const commentViews = wrapper.find(CommitCommentView);

    assert.deepEqual(commentViews.map(c => c.prop('item').author.login), ['user0', 'user1', 'user2']);

    assert.isFalse(commentViews.at(0).prop('isReply'));
    assert.isTrue(commentViews.at(1).prop('isReply'));
    assert.isTrue(commentViews.at(2).prop('isReply'));
  });
});
