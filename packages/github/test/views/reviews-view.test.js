import React from 'react';
import {shallow} from 'enzyme';
import path from 'path';

import {Command} from '../../lib/atom/commands';
import ReviewsView from '../../lib/views/reviews-view';
import EnableableOperation from '../../lib/models/enableable-operation';
import {aggregatedReviewsBuilder} from '../builder/graphql/aggregated-reviews-builder';
import {multiFilePatchBuilder} from '../builder/patch';
import {checkoutStates} from '../../lib/controllers/pr-checkout-controller';
import * as reporterProxy from '../../lib/reporter-proxy';
import {GHOST_USER} from '../../lib/helpers';

describe('ReviewsView', function() {
  let atomEnv;

  beforeEach(function() {
    atomEnv = global.buildAtomEnvironment();
  });

  afterEach(function() {
    atomEnv.destroy();
  });

  function buildApp(override = {}) {
    const props = {
      relay: {environment: {}},
      repository: {},
      pullRequest: {},
      summaries: [],
      commentThreads: [],
      commentTranslations: null,
      multiFilePatch: multiFilePatchBuilder().build().multiFilePatch,
      contextLines: 4,
      checkoutOp: new EnableableOperation(() => {}).disable(checkoutStates.CURRENT),
      summarySectionOpen: true,
      commentSectionOpen: true,
      threadIDsOpen: new Set(),
      highlightedThreadIDs: new Set(),

      number: 100,
      repo: 'github',
      owner: 'atom',
      workdir: __dirname,

      workspace: atomEnv.workspace,
      config: atomEnv.config,
      commands: atomEnv.commands,
      tooltips: atomEnv.tooltips,

      openFile: () => {},
      openDiff: () => {},
      openPR: () => {},
      moreContext: () => {},
      lessContext: () => {},
      openIssueish: () => {},
      showSummaries: () => {},
      hideSummaries: () => {},
      showComments: () => {},
      hideComments: () => {},
      showThreadID: () => {},
      hideThreadID: () => {},
      resolveThread: () => {},
      unresolveThread: () => {},
      addSingleComment: () => {},
      reportRelayError: () => {},
      refetch: () => {},
      ...override,
    };

    return <ReviewsView {...props} />;
  }

  it('registers atom commands', async function() {
    const moreContext = sinon.stub();
    const lessContext = sinon.stub();
    const wrapper = shallow(buildApp({moreContext, lessContext}));
    assert.lengthOf(wrapper.find(Command), 3);

    assert.isFalse(moreContext.called);
    await wrapper.find(Command).at(0).prop('callback')();
    assert.isTrue(moreContext.called);

    assert.isFalse(lessContext.called);
    await wrapper.find(Command).at(1).prop('callback')();
    assert.isTrue(lessContext.called);
  });

  it('renders empty state if there is no review', function() {
    sinon.stub(reporterProxy, 'addEvent');
    const wrapper = shallow(buildApp());
    assert.lengthOf(wrapper.find('.github-Reviews-section.summaries'), 0);
    assert.lengthOf(wrapper.find('.github-Reviews-section.comments'), 0);
    assert.lengthOf(wrapper.find('.github-Reviews-emptyState'), 1);

    wrapper.find('.github-Reviews-emptyCallToActionButton a').simulate('click');
    assert.isTrue(reporterProxy.addEvent.calledWith(
      'start-pr-review',
      {package: 'github', component: 'ReviewsView'},
    ));
  });

  it('renders summary and comment sections', function() {
    const {summaries, commentThreads} = aggregatedReviewsBuilder()
      .addReviewSummary(r => r.id(0))
      .addReviewThread(t => t.addComment())
      .addReviewThread(t => t.addComment())
      .build();

    const wrapper = shallow(buildApp({summaries, commentThreads}));

    assert.lengthOf(wrapper.find('.github-Reviews-section.summaries'), 1);
    assert.lengthOf(wrapper.find('.github-Reviews-section.comments'), 1);
    assert.lengthOf(wrapper.find('.github-ReviewSummary'), 1);
    assert.lengthOf(wrapper.find('details.github-Review'), 2);
  });

  it('displays ghost user information in review summary if author is null', function() {
    const {summaries, commentThreads} = aggregatedReviewsBuilder()
      .addReviewSummary(r => r.id(0))
      .addReviewThread(t => t.addComment().addComment())
      .build();

    const wrapper = shallow(buildApp({summaries, commentThreads}));

    const showActionMenu = () => {};
    const summary = wrapper.find('.github-ReviewSummary').find('ActionableReviewView').renderProp('render')(showActionMenu);

    // summary
    assert.strictEqual(summary.find('.github-ReviewSummary-username').text(), GHOST_USER.login);
    assert.strictEqual(summary.find('.github-ReviewSummary-username').prop('href'), GHOST_USER.url);
    assert.strictEqual(summary.find('.github-ReviewSummary-avatar').prop('src'), GHOST_USER.avatarUrl);
    assert.strictEqual(summary.find('.github-ReviewSummary-avatar').prop('alt'), GHOST_USER.login);
  });

  it('displays an author association badge for review summaries', function() {
    const {summaries, commentThreads} = aggregatedReviewsBuilder()
      .addReviewSummary(r => r.id(0).authorAssociation('MEMBER'))
      .addReviewSummary(r => r.id(1).authorAssociation('OWNER'))
      .addReviewSummary(r => r.id(2).authorAssociation('COLLABORATOR'))
      .addReviewSummary(r => r.id(3).authorAssociation('CONTRIBUTOR'))
      .addReviewSummary(r => r.id(4).authorAssociation('FIRST_TIME_CONTRIBUTOR'))
      .addReviewSummary(r => r.id(5).authorAssociation('FIRST_TIMER'))
      .addReviewSummary(r => r.id(6).authorAssociation('NONE'))
      .build();

    const showActionMenu = () => {};
    const wrapper = shallow(buildApp({summaries, commentThreads}));
    assert.lengthOf(wrapper.find('.github-ReviewSummary'), 7);
    const reviews = wrapper.find('.github-ReviewSummary').map(review =>
      review.find('ActionableReviewView').renderProp('render')(showActionMenu),
    );

    assert.strictEqual(reviews[0].find('.github-Review-authorAssociationBadge').text(), 'Member');
    assert.strictEqual(reviews[1].find('.github-Review-authorAssociationBadge').text(), 'Owner');
    assert.strictEqual(reviews[2].find('.github-Review-authorAssociationBadge').text(), 'Collaborator');
    assert.strictEqual(reviews[3].find('.github-Review-authorAssociationBadge').text(), 'Contributor');
    assert.strictEqual(reviews[4].find('.github-Review-authorAssociationBadge').text(), 'First-time contributor');
    assert.strictEqual(reviews[5].find('.github-Review-authorAssociationBadge').text(), 'First-timer');
    assert.isFalse(reviews[6].exists('.github-Review-authorAssociationBadge'));
  });

  it('calls openIssueish when clicking on an issueish link in a review summary', function() {
    const openIssueish = sinon.spy();

    const {summaries} = aggregatedReviewsBuilder()
      .addReviewSummary(r => {
        r.bodyHTML('hey look a link <a href="https://github.com/aaa/bbb/pulls/123">#123</a>').id(0);
      })
      .build();

    const wrapper = shallow(buildApp({openIssueish, summaries}));
    const showActionMenu = () => {};
    const review = wrapper.find('ActionableReviewView').renderProp('render')(showActionMenu);

    review.find('GithubDotcomMarkdown').prop('switchToIssueish')('aaa', 'bbb', 123);
    assert.isTrue(openIssueish.calledWith('aaa', 'bbb', 123));

    review.find('GithubDotcomMarkdown').prop('openIssueishLinkInNewTab')({
      target: {dataset: {url: 'https://github.com/ccc/ddd/issues/654'}},
    });
    assert.isTrue(openIssueish.calledWith('ccc', 'ddd', 654));
  });

  describe('refresh', function() {
    it('calls refetch when refresh button is clicked', function() {
      const refetch = sinon.stub().returns({dispose() {}});
      const wrapper = shallow(buildApp({refetch}));
      assert.isFalse(refetch.called);

      wrapper.find('.icon-repo-sync').simulate('click');
      assert.isTrue(refetch.called);
      assert.isTrue(wrapper.find('.icon-repo-sync').hasClass('refreshing'));

      // Trigger the completion callback
      refetch.lastCall.args[0]();
      assert.isFalse(wrapper.find('.icon-repo-sync').hasClass('refreshing'));
    });

    it('does not call refetch if already fetching', function() {
      const refetch = sinon.stub().returns({dispose() {}});
      const wrapper = shallow(buildApp({refetch}));
      assert.isFalse(refetch.called);

      wrapper.instance().state.isRefreshing = true;
      wrapper.find('.icon-repo-sync').simulate('click');
      assert.isFalse(refetch.called);
    });

    it('cancels a refetch in progress on unmount', function() {
      const refetchInProgress = {dispose: sinon.spy()};
      const refetch = sinon.stub().returns(refetchInProgress);

      const wrapper = shallow(buildApp({refetch}));
      assert.isFalse(refetch.called);

      wrapper.find('.icon-repo-sync').simulate('click');
      wrapper.unmount();

      assert.isTrue(refetchInProgress.dispose.called);
    });
  });

  describe('checkout button', function() {
    it('passes checkoutOp prop through to CheckoutButon', function() {
      const wrapper = shallow(buildApp());
      const checkoutOpProp = (wrapper.find('CheckoutButton').prop('checkoutOp'));
      assert.deepEqual(checkoutOpProp.disablement, {reason: {name: 'current'}, message: 'disabled'});
    });
  });

  describe('comment threads', function() {
    const {summaries, commentThreads} = aggregatedReviewsBuilder()
      .addReviewSummary(r => r.id(0))
      .addReviewThread(t => {
        t.thread(t0 => t0.id('abcd'));
        t.addComment(c =>
          c.id(0).path('dir/file0').position(10).bodyHTML('i have a bad windows file path.').author(a => a.login('user0').avatarUrl('user0.jpg')),
        );
        t.addComment(c =>
          c.id(1).path('file0').position(10).bodyHTML('i disagree.').author(a => a.login('user1').avatarUrl('user1.jpg')).isMinimized(true),
        );
      }).addReviewThread(t => {
        t.addComment(c =>
          c.id(2).path('file1').position(20).bodyHTML('thanks for all the fish').author(a => a.login('dolphin').avatarUrl('pic-of-dolphin')),
        );
        t.addComment(c =>
          c.id(3).path('file1').position(20).bodyHTML('shhhh').state('PENDING'),
        );
      }).addReviewThread(t => {
        t.thread(t0 => t0.isResolved(true));
        t.addComment();
        return t;
      })
      .build();

    let wrapper, openIssueish, resolveThread, unresolveThread, addSingleComment;

    beforeEach(function() {
      openIssueish = sinon.spy();
      resolveThread = sinon.spy();
      unresolveThread = sinon.spy();
      addSingleComment = sinon.stub().returns(new Promise((resolve, reject) => {}));

      const commentTranslations = new Map();
      commentThreads.forEach(thread => {
        const rootComment = thread.comments[0];
        const diffToFilePosition = new Map();
        diffToFilePosition.set(rootComment.position, rootComment.position);
        commentTranslations.set(path.normalize(rootComment.path), {diffToFilePosition});
      });

      wrapper = shallow(buildApp({openIssueish, summaries, commentThreads, resolveThread, unresolveThread, addSingleComment, commentTranslations}));
    });

    it('renders threads with comments', function() {
      const threads = wrapper.find('details.github-Review');
      assert.lengthOf(threads, 3);
      assert.lengthOf(threads.at(0).find('ReviewCommentView'), 2);
      assert.lengthOf(threads.at(1).find('ReviewCommentView'), 2);
      assert.lengthOf(threads.at(2).find('ReviewCommentView'), 1);
    });

    it('groups comments by their resolved status', function() {
      const unresolvedThreads = wrapper.find('.github-Reviews-section.comments').find('.github-Review');
      const resolvedThreads = wrapper.find('.github-Reviews-section.resolved-comments').find('.github-Review');
      assert.lengthOf(resolvedThreads, 1);
      assert.lengthOf(unresolvedThreads, 3);
    });

    describe('indication that a comment has been edited', function() {
      it('indicates that a review summary comment has been edited', function() {
        const summary = wrapper.find('.github-ReviewSummary').at(0);

        assert.isFalse(summary.exists('.github-Review-edited'));

        const commentUrl = 'https://github.com/atom/github/pull/1995#discussion_r272475592';
        const updatedProps = aggregatedReviewsBuilder()
          .addReviewSummary(r => r.id(0).lastEditedAt('2018-12-27T17:51:17Z').url(commentUrl))
          .build();

        wrapper.setProps({...updatedProps});
        const showActionMenu = () => {};

        const updatedSummary = wrapper.find('.github-ReviewSummary').at(0).find('ActionableReviewView').renderProp('render')(showActionMenu);
        assert.isTrue(updatedSummary.exists('.github-Review-edited'));
        const editedWrapper = updatedSummary.find('a.github-Review-edited');
        assert.strictEqual(editedWrapper.text(), 'edited');
        assert.strictEqual(editedWrapper.prop('href'), commentUrl);
      });

    });

    describe('each thread', function() {
      it('displays correct data', function() {
        const thread = wrapper.find('details.github-Review').at(0);
        assert.strictEqual(thread.find('.github-Review-path').text(), 'dir');
        assert.strictEqual(thread.find('.github-Review-file').text(), `${path.sep}file0`);

        assert.strictEqual(thread.find('.github-Review-lineNr').text(), '10');
      });

      it('displays a resolve button for unresolved threads', function() {
        const thread = wrapper.find('details.github-Review').at(0);
        const button = thread.find('.github-Review-resolveButton');
        assert.strictEqual(button.text(), 'Resolve conversation');

        assert.isFalse(resolveThread.called);
        button.simulate('click');
        assert.isTrue(resolveThread.called);
      });

      it('displays an unresolve button for resolved threads', function() {
        const thread = wrapper.find('details.github-Review').at(2);

        const button = thread.find('.github-Review-resolveButton');
        assert.strictEqual(button.text(), 'Unresolve conversation');

        assert.isFalse(unresolveThread.called);
        button.simulate('click');
        assert.isTrue(unresolveThread.called);
      });

      it('omits the / when there is no directory', function() {
        const thread = wrapper.find('details.github-Review').at(1);
        assert.isFalse(thread.exists('.github-Review-path'));
        assert.strictEqual(thread.find('.github-Review-file').text(), 'file1');
      });

      it('renders a PatchPreviewView per comment thread', function() {
        assert.isTrue(wrapper.find('details.github-Review').everyWhere(thread => thread.find('PatchPreviewView').length === 1));
        assert.include(wrapper.find('PatchPreviewView').at(0).props(), {
          fileName: path.join('dir/file0'),
          diffRow: 10,
          maxRowCount: 4,
        });
      });

      describe('navigation buttons', function() {
        it('a pair of "Open Diff" and "Jump To File" buttons per thread', function() {
          assert.isTrue(wrapper.find('details.github-Review').everyWhere(thread =>
            thread.find('.github-Review-navButton.icon-code').length === 1 &&
            thread.find('.github-Review-navButton.icon-diff').length === 1,
          ));
        });

        describe('when PR is checked out', function() {
          let openFile, openDiff;

          beforeEach(function() {
            openFile = sinon.spy();
            openDiff = sinon.spy();
            wrapper = shallow(buildApp({openFile, openDiff, summaries, commentThreads}));
          });

          it('calls openDiff with correct params when "Open Diff" is clicked', function() {
            wrapper.find('details.github-Review').at(0).find('.icon-diff').simulate('click', {currentTarget: {dataset: {path: 'dir/file0', line: 10}}});
            assert(openDiff.calledWith('dir/file0', 10));
          });

          it('calls openFile with correct params when when "Jump To File" is clicked', function() {
            wrapper.find('details.github-Review').at(0).find('.icon-code').simulate('click', {
              currentTarget: {dataset: {path: 'dir/file0', line: 10}},
            });
            assert.isTrue(openFile.calledWith('dir/file0', 10));
          });
        });

        describe('when PR is not checked out', function() {
          let openFile, openDiff;

          beforeEach(function() {
            openFile = sinon.spy();
            openDiff = sinon.spy();
            const checkoutOp = new EnableableOperation(() => {});
            wrapper = shallow(buildApp({openFile, openDiff, checkoutOp, summaries, commentThreads}));
          });

          it('"Jump To File" button is disabled', function() {
            assert.isTrue(wrapper.find('button.icon-code').everyWhere(button => button.prop('disabled') === true));
          });

          it('does not calls openFile when when "Jump To File" is clicked', function() {
            wrapper.find('details.github-Review').at(0).find('.icon-code').simulate('click', {currentTarget: {dataset: {path: 'dir/file0', line: 10}}});
            assert.isFalse(openFile.called);
          });

          it('"Open Diff" still works', function() {
            wrapper.find('details.github-Review').at(0).find('.icon-diff').simulate('click', {currentTarget: {dataset: {path: 'dir/file0', line: 10}}});
            assert(openDiff.calledWith('dir/file0', 10));
          });
        });
      });
    });

    it('each comment displays reply button', function() {
      const submitSpy = sinon.spy(wrapper.instance(), 'submitReply');
      const buttons = wrapper.find('.github-Review-replyButton');
      assert.lengthOf(buttons, 3);
      const button = buttons.at(0);
      assert.strictEqual(button.text(), 'Comment');
      button.simulate('click');
      const submitArgs = submitSpy.lastCall.args;
      assert.strictEqual(submitArgs[1].id, 'abcd');
      assert.strictEqual(submitArgs[2].bodyHTML, 'i disagree.');


      const addSingleCommentArgs = addSingleComment.lastCall.args;
      assert.strictEqual(addSingleCommentArgs[1], 'abcd');
      assert.strictEqual(addSingleCommentArgs[2], 1);
    });

    it('registers a github:submit-comment command that submits the focused reply comment', async function() {
      addSingleComment.resolves();
      const command = wrapper.find('Command[command="github:submit-comment"]');

      const evt = {
        currentTarget: {
          dataset: {threadId: 'abcd'},
        },
      };

      const miniEditor = {
        getText: () => 'content',
        setText: () => {},
      };
      wrapper.instance().replyHolders.get('abcd').setter(miniEditor);

      await command.prop('callback')(evt);

      assert.isTrue(addSingleComment.calledWith(
        'content', 'abcd', 1, 'file0', 10, {didSubmitComment: sinon.match.func, didFailComment: sinon.match.func},
      ));
    });

    it('renders progress bar', function() {
      assert.isTrue(wrapper.find('.github-Reviews-progress').exists());
      assert.strictEqual(wrapper.find('.github-Reviews-count').text(), 'Resolved 1 of 3');
      assert.include(wrapper.find('progress.github-Reviews-progessBar').props(), {value: 1, max: 3});
    });
  });
});
