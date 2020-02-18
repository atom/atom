import React from 'react';
import {shallow} from 'enzyme';

import ReviewCommentView from '../../lib/views/review-comment-view';
import ActionableReviewView from '../../lib/views/actionable-review-view';
import EmojiReactionsController from '../../lib/controllers/emoji-reactions-controller';
import {GHOST_USER} from '../../lib/helpers';

describe('ReviewCommentView', function() {
  let atomEnv;

  beforeEach(function() {
    atomEnv = global.buildAtomEnvironment();
  });

  afterEach(function() {
    atomEnv.destroy();
  });

  function buildApp(override = {}) {
    const props = {
      comment: {},
      isPosting: false,
      confirm: () => {},
      tooltips: atomEnv.tooltips,
      commands: atomEnv.commands,
      renderEditedLink: () => <div />,
      renderAuthorAssociation: () => <div />,
      openIssueish: () => {},
      openIssueishLinkInNewTab: () => {},
      updateComment: () => {},
      reportRelayError: () => {},
      ...override,
    };

    return <ReviewCommentView {...props} />;
  }

  it('passes most props through to an ActionableReviewView', function() {
    const comment = {id: 'comment0'};
    const confirm = () => {};
    const updateComment = () => {};

    const wrapper = shallow(buildApp({
      comment,
      isPosting: true,
      confirm,
      updateComment,
    }));

    const arv = wrapper.find(ActionableReviewView);
    assert.strictEqual(arv.prop('originalContent'), comment);
    assert.isTrue(arv.prop('isPosting'));
    assert.strictEqual(arv.prop('confirm'), confirm);
    assert.strictEqual(arv.prop('contentUpdater'), updateComment);
  });

  describe('review comment data for non-edit mode', function() {
    it('renders a placeholder message for minimized comments', function() {
      const comment = {
        id: 'comment0',
        isMinimized: true,
      };
      const showActionsMenu = sinon.spy();

      const wrapper = shallow(buildApp({comment}))
        .find(ActionableReviewView)
        .renderProp('render')(showActionsMenu);

      assert.isTrue(wrapper.exists('.github-Review-comment--hidden'));
    });

    it('renders review comment data for non-edit mode', function() {
      const comment = {
        id: 'comment0',
        isMinimized: false,
        state: 'SUBMITTED',
        author: {
          login: 'me',
          url: 'https://github.com/me',
          avatarUrl: 'https://avatars.r.us/1234',
        },
        createdAt: '2019-01-01T10:00:00Z',
        bodyHTML: '<p>hi</p>',
      };
      const showActionsMenu = sinon.spy();

      const wrapper = shallow(buildApp({
        comment,
        renderEditedLink: c => {
          assert.strictEqual(c, comment);
          return <div className="renderEditedLink" />;
        },
        renderAuthorAssociation: c => {
          assert.strictEqual(c, comment);
          return <div className="renderAuthorAssociation" />;
        },
      }))
        .find(ActionableReviewView)
        .renderProp('render')(showActionsMenu);

      assert.isTrue(wrapper.exists('.github-Review-comment'));
      assert.isFalse(wrapper.exists('.github-Review-comment--pending'));
      assert.strictEqual(wrapper.find('.github-Review-avatar').prop('src'), comment.author.avatarUrl);
      assert.strictEqual(wrapper.find('.github-Review-username').prop('href'), comment.author.url);
      assert.strictEqual(wrapper.find('.github-Review-username').text(), comment.author.login);
      assert.strictEqual(wrapper.find('Timeago').prop('time'), comment.createdAt);
      assert.isTrue(wrapper.exists('.renderEditedLink'));
      assert.isTrue(wrapper.exists('.renderAuthorAssociation'));

      wrapper.find('Octicon[icon="ellipses"]').simulate('click');
      assert.isTrue(showActionsMenu.calledWith(sinon.match.any, comment, comment.author));

      assert.strictEqual(wrapper.find('GithubDotcomMarkdown').prop('html'), comment.bodyHTML);
      assert.strictEqual(wrapper.find(EmojiReactionsController).prop('reactable'), comment);
    });

    it('uses a ghost user for comments with no author', function() {
      const comment = {
        id: 'comment0',
        isMinimized: false,
        state: 'SUBMITTED',
        createdAt: '2019-01-01T10:00:00Z',
        bodyHTML: '<p>hi</p>',
      };
      const showActionsMenu = sinon.spy();

      const wrapper = shallow(buildApp({comment}))
        .find(ActionableReviewView)
        .renderProp('render')(showActionsMenu);

      assert.isTrue(wrapper.exists('.github-Review-comment'));
      assert.strictEqual(wrapper.find('.github-Review-avatar').prop('src'), GHOST_USER.avatarUrl);
      assert.strictEqual(wrapper.find('.github-Review-username').prop('href'), GHOST_USER.url);
      assert.strictEqual(wrapper.find('.github-Review-username').text(), GHOST_USER.login);

      wrapper.find('Octicon[icon="ellipses"]').simulate('click');
      assert.isTrue(showActionsMenu.calledWith(sinon.match.any, comment, GHOST_USER));
    });

    it('includes a badge to mark pending comments', function() {
      const comment = {
        id: 'comment0',
        isMinimized: false,
        state: 'PENDING',
        author: {
          login: 'me',
          url: 'https://github.com/me',
          avatarUrl: 'https://avatars.r.us/1234',
        },
        createdAt: '2019-01-01T10:00:00Z',
        bodyHTML: '<p>hi</p>',
      };

      const wrapper = shallow(buildApp({comment}))
        .find(ActionableReviewView)
        .renderProp('render')(() => {});

      assert.isTrue(wrapper.exists('.github-Review-comment--pending'));
      assert.isTrue(wrapper.exists('.github-Review-pendingBadge'));
    });
  });
});
