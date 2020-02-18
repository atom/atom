import React from 'react';
import {shallow} from 'enzyme';
import path from 'path';

import {BareReviewsController} from '../../lib/controllers/reviews-controller';
import PullRequestCheckoutController from '../../lib/controllers/pr-checkout-controller';
import ReviewsView from '../../lib/views/reviews-view';
import IssueishDetailItem from '../../lib/items/issueish-detail-item';
import BranchSet from '../../lib/models/branch-set';
import RemoteSet from '../../lib/models/remote-set';
import EnableableOperation from '../../lib/models/enableable-operation';
import WorkdirContextPool from '../../lib/models/workdir-context-pool';
import * as reporterProxy from '../../lib/reporter-proxy';
import {getEndpoint} from '../../lib/models/endpoint';
import {cloneRepository, buildRepository, registerGitHubOpener} from '../helpers';
import {multiFilePatchBuilder} from '../builder/patch';
import {userBuilder} from '../builder/graphql/user';
import {pullRequestBuilder} from '../builder/graphql/pr';
import RelayNetworkLayerManager, {expectRelayQuery} from '../../lib/relay-network-layer-manager';
import {relayResponseBuilder} from '../builder/graphql/query';

import viewerQuery from '../../lib/controllers/__generated__/reviewsController_viewer.graphql';
import pullRequestQuery from '../../lib/controllers/__generated__/reviewsController_pullRequest.graphql';

import addPrReviewMutation from '../../lib/mutations/__generated__/addPrReviewMutation.graphql';
import addPrReviewCommentMutation from '../../lib/mutations/__generated__/addPrReviewCommentMutation.graphql';
import deletePrReviewMutation from '../../lib/mutations/__generated__/deletePrReviewMutation.graphql';
import submitPrReviewMutation from '../../lib/mutations/__generated__/submitPrReviewMutation.graphql';
import resolveThreadMutation from '../../lib/mutations/__generated__/resolveReviewThreadMutation.graphql';
import unresolveThreadMutation from '../../lib/mutations/__generated__/unresolveReviewThreadMutation.graphql';
import updateReviewCommentMutation from '../../lib/mutations/__generated__/updatePrReviewCommentMutation.graphql';
import updatePrReviewMutation from '../../lib/mutations/__generated__/updatePrReviewSummaryMutation.graphql';

describe('ReviewsController', function() {
  let atomEnv, relayEnv, localRepository, noop, clock;

  beforeEach(async function() {
    atomEnv = global.buildAtomEnvironment();
    registerGitHubOpener(atomEnv);

    localRepository = await buildRepository(await cloneRepository());

    noop = new EnableableOperation(() => {});

    relayEnv = RelayNetworkLayerManager.getEnvironmentForHost(getEndpoint('github.com'), '1234');
  });

  afterEach(function() {
    atomEnv.destroy();

    if (clock) {
      clock.restore();
    }
  });

  function buildApp(override = {}) {
    const props = {
      relay: {environment: relayEnv},
      viewer: userBuilder(viewerQuery).build(),
      repository: {},
      pullRequest: pullRequestBuilder(pullRequestQuery).build(),

      workdirContextPool: new WorkdirContextPool(),
      localRepository,
      isAbsent: false,
      isLoading: false,
      isPresent: true,
      isMerging: true,
      isRebasing: true,
      branches: new BranchSet(),
      remotes: new RemoteSet(),
      multiFilePatch: multiFilePatchBuilder().build(),

      endpoint: getEndpoint('github.com'),

      owner: 'atom',
      repo: 'github',
      number: 1995,
      workdir: localRepository.getWorkingDirectoryPath(),

      workspace: atomEnv.workspace,
      config: atomEnv.config,
      commands: atomEnv.commands,
      tooltips: atomEnv.tooltips,
      confirm: () => {},
      reportRelayError: () => {},

      ...override,
    };

    return <BareReviewsController {...props} />;
  }

  it('renders a ReviewsView inside a PullRequestCheckoutController', function() {
    const extra = Symbol('extra');
    const wrapper = shallow(buildApp({extra}));
    const opWrapper = wrapper.find(PullRequestCheckoutController).renderProp('children')(noop);

    assert.strictEqual(opWrapper.find(ReviewsView).prop('extra'), extra);
  });

  it('scrolls to and highlight a specific thread on mount', function() {
    clock = sinon.useFakeTimers();
    const wrapper = shallow(buildApp({initThreadID: 'thread0'}));
    let opWrapper = wrapper.find(PullRequestCheckoutController).renderProp('children')(noop);

    assert.include(opWrapper.find(ReviewsView).prop('threadIDsOpen'), 'thread0');
    assert.include(opWrapper.find(ReviewsView).prop('highlightedThreadIDs'), 'thread0');
    assert.strictEqual(opWrapper.find(ReviewsView).prop('scrollToThreadID'), 'thread0');

    clock.tick(2000);
    opWrapper = wrapper.find(PullRequestCheckoutController).renderProp('children')(noop);
    assert.notInclude(opWrapper.find(ReviewsView).prop('highlightedThreadIDs'), 'thread0');
    assert.isNull(opWrapper.find(ReviewsView).prop('scrollToThreadID'));
  });

  it('scrolls to and highlight a specific thread on update', function() {
    clock = sinon.useFakeTimers();
    const wrapper = shallow(buildApp());
    let opWrapper = wrapper.find(PullRequestCheckoutController).renderProp('children')(noop);

    assert.deepEqual(opWrapper.find(ReviewsView).prop('threadIDsOpen'), new Set([]));
    wrapper.setProps({initThreadID: 'hang-by-a-thread'});
    opWrapper = wrapper.find(PullRequestCheckoutController).renderProp('children')(noop);

    assert.include(opWrapper.find(ReviewsView).prop('threadIDsOpen'), 'hang-by-a-thread');
    assert.include(opWrapper.find(ReviewsView).prop('highlightedThreadIDs'), 'hang-by-a-thread');
    assert.isTrue(opWrapper.find(ReviewsView).prop('commentSectionOpen'));
    assert.strictEqual(opWrapper.find(ReviewsView).prop('scrollToThreadID'), 'hang-by-a-thread');

    clock.tick(2000);
    opWrapper = wrapper.find(PullRequestCheckoutController).renderProp('children')(noop);
    assert.notInclude(opWrapper.find(ReviewsView).prop('highlightedThreadIDs'), 'hang-by-a-thread');
    assert.isNull(opWrapper.find(ReviewsView).prop('scrollToThreadID'));
  });

  it('does not unset a different scrollToThreadID if two highlight actions collide', function() {
    clock = sinon.useFakeTimers();
    const wrapper = shallow(buildApp());
    let opWrapper = wrapper.find(PullRequestCheckoutController).renderProp('children')(noop);

    assert.deepEqual(opWrapper.find(ReviewsView).prop('threadIDsOpen'), new Set([]));
    wrapper.setProps({initThreadID: 'hang-by-a-thread'});
    opWrapper = wrapper.find(PullRequestCheckoutController).renderProp('children')(noop);

    assert.deepEqual(
      Array.from(opWrapper.find(ReviewsView).prop('threadIDsOpen')),
      ['hang-by-a-thread'],
    );
    assert.deepEqual(
      Array.from(opWrapper.find(ReviewsView).prop('highlightedThreadIDs')),
      ['hang-by-a-thread'],
    );
    assert.isTrue(opWrapper.find(ReviewsView).prop('commentSectionOpen'));
    assert.strictEqual(opWrapper.find(ReviewsView).prop('scrollToThreadID'), 'hang-by-a-thread');

    clock.tick(1000);
    wrapper.setProps({initThreadID: 'caught-in-a-web'});
    opWrapper = wrapper.find(PullRequestCheckoutController).renderProp('children')(noop);

    assert.deepEqual(
      Array.from(opWrapper.find(ReviewsView).prop('threadIDsOpen')),
      ['hang-by-a-thread', 'caught-in-a-web'],
    );
    assert.deepEqual(
      Array.from(opWrapper.find(ReviewsView).prop('highlightedThreadIDs')),
      ['hang-by-a-thread', 'caught-in-a-web'],
    );
    assert.isTrue(opWrapper.find(ReviewsView).prop('commentSectionOpen'));
    assert.strictEqual(opWrapper.find(ReviewsView).prop('scrollToThreadID'), 'caught-in-a-web');

    clock.tick(1000);
    opWrapper = wrapper.find(PullRequestCheckoutController).renderProp('children')(noop);
    assert.deepEqual(
      Array.from(opWrapper.find(ReviewsView).prop('highlightedThreadIDs')),
      ['caught-in-a-web'],
    );
    assert.strictEqual(opWrapper.find(ReviewsView).prop('scrollToThreadID'), 'caught-in-a-web');
  });

  describe('openIssueish', function() {
    it('opens an IssueishDetailItem for a different issueish', async function() {
      const wrapper = shallow(buildApp({
        endpoint: getEndpoint('github.enterprise.horse'),
      }));
      const opWrapper = wrapper.find(PullRequestCheckoutController).renderProp('children')(noop);
      await opWrapper.find(ReviewsView).prop('openIssueish')('owner', 'repo', 10);

      assert.include(
        atomEnv.workspace.getPaneItems().map(item => item.getURI()),
        IssueishDetailItem.buildURI({host: 'github.enterprise.horse', owner: 'owner', repo: 'repo', number: 10}),
      );
    });

    it('locates a resident Repository in the context pool if exactly one is available', async function() {
      const workdirContextPool = new WorkdirContextPool();

      const otherDir = await cloneRepository();
      const otherRepo = workdirContextPool.add(otherDir).getRepository();
      await otherRepo.getLoadPromise();
      await otherRepo.addRemote('up', 'git@github.com:owner/repo.git');

      const wrapper = shallow(buildApp({
        endpoint: getEndpoint('github.com'),
        workdirContextPool,
      }));
      const opWrapper = wrapper.find(PullRequestCheckoutController).renderProp('children')(noop);
      await opWrapper.find(ReviewsView).prop('openIssueish')('owner', 'repo', 10);

      assert.include(
        atomEnv.workspace.getPaneItems().map(item => item.getURI()),
        IssueishDetailItem.buildURI({host: 'github.com', owner: 'owner', repo: 'repo', number: 10, workdir: otherDir}),
      );
    });

    it('prefers the current Repository if it matches', async function() {
      const workdirContextPool = new WorkdirContextPool();

      const currentDir = await cloneRepository();
      const currentRepo = workdirContextPool.add(currentDir).getRepository();
      await currentRepo.getLoadPromise();
      await currentRepo.addRemote('up', 'git@github.com:owner/repo.git');

      const otherDir = await cloneRepository();
      const otherRepo = workdirContextPool.add(otherDir).getRepository();
      await otherRepo.getLoadPromise();
      await otherRepo.addRemote('up', 'git@github.com:owner/repo.git');

      const wrapper = shallow(buildApp({
        endpoint: getEndpoint('github.com'),
        workdirContextPool,
        localRepository: currentRepo,
      }));

      const opWrapper = wrapper.find(PullRequestCheckoutController).renderProp('children')(noop);
      await opWrapper.find(ReviewsView).prop('openIssueish')('owner', 'repo', 10);

      assert.include(
        atomEnv.workspace.getPaneItems().map(item => item.getURI()),
        IssueishDetailItem.buildURI({
          host: 'github.com', owner: 'owner', repo: 'repo', number: 10, workdir: currentDir,
        }),
      );
    });
  });

  describe('context lines', function() {
    it('defaults to 4 lines of context', function() {
      const wrapper = shallow(buildApp());
      const opWrapper = wrapper.find(PullRequestCheckoutController).renderProp('children')(noop);

      assert.strictEqual(opWrapper.find(ReviewsView).prop('contextLines'), 4);
    });

    it('increases context lines with moreContext', function() {
      const wrapper = shallow(buildApp());
      const opWrapper0 = wrapper.find(PullRequestCheckoutController).renderProp('children')(noop);

      opWrapper0.find(ReviewsView).prop('moreContext')();

      const opWrapper1 = wrapper.find(PullRequestCheckoutController).renderProp('children')(noop);
      assert.strictEqual(opWrapper1.find(ReviewsView).prop('contextLines'), 5);
    });

    it('decreases context lines with lessContext', function() {
      const wrapper = shallow(buildApp());
      const opWrapper0 = wrapper.find(PullRequestCheckoutController).renderProp('children')(noop);

      opWrapper0.find(ReviewsView).prop('lessContext')();

      const opWrapper1 = wrapper.find(PullRequestCheckoutController).renderProp('children')(noop);
      assert.strictEqual(opWrapper1.find(ReviewsView).prop('contextLines'), 3);
    });

    it('ensures that at least one context line is present', function() {
      const wrapper = shallow(buildApp());
      const opWrapper0 = wrapper.find(PullRequestCheckoutController).renderProp('children')(noop);

      for (let i = 0; i < 3; i++) {
        opWrapper0.find(ReviewsView).prop('lessContext')();
      }

      const opWrapper1 = wrapper.find(PullRequestCheckoutController).renderProp('children')(noop);
      assert.strictEqual(opWrapper1.find(ReviewsView).prop('contextLines'), 1);

      opWrapper1.find(ReviewsView).prop('lessContext')();

      const opWrapper2 = wrapper.find(PullRequestCheckoutController).renderProp('children')(noop);
      assert.strictEqual(opWrapper2.find(ReviewsView).prop('contextLines'), 1);
    });
  });

  describe('adding a single comment', function() {
    it('creates a review, attaches the comment, and submits it', async function() {
      expectRelayQuery({
        name: addPrReviewMutation.operation.name,
        variables: {
          input: {pullRequestId: 'pr0'},
        },
      }, op => {
        return relayResponseBuilder(op)
          .addPullRequestReview(m => {
            m.reviewEdge(e => e.node(r => r.id('review0')));
          })
          .build();
      }).resolve();

      expectRelayQuery({
        name: addPrReviewCommentMutation.operation.name,
        variables: {
          input: {body: 'body', inReplyTo: 'comment1', pullRequestReviewId: 'review0'},
        },
      }, op => {
        return relayResponseBuilder(op)
          .addPullRequestReviewComment(m => {
            m.commentEdge(e => e.node(c => c.id('comment2')));
          })
          .build();
      }).resolve();

      expectRelayQuery({
        name: submitPrReviewMutation.operation.name,
        variables: {
          input: {pullRequestReviewId: 'review0', event: 'COMMENT'},
        },
      }, op => {
        return relayResponseBuilder(op)
          .submitPullRequestReview(m => {
            m.pullRequestReview(r => r.id('review0'));
          })
          .build();
      }).resolve();

      const pullRequest = pullRequestBuilder(pullRequestQuery).id('pr0').build();
      const wrapper = shallow(buildApp({pullRequest}))
        .find(PullRequestCheckoutController)
        .renderProp('children')(noop);

      const didSubmitComment = sinon.spy();
      const didFailComment = sinon.spy();

      await wrapper.find(ReviewsView).prop('addSingleComment')(
        'body', 'thread0', 'comment1', 'file0.txt', 10, {didSubmitComment, didFailComment},
      );

      assert.isTrue(didSubmitComment.called);
      assert.isFalse(didFailComment.called);
    });

    it('creates a notification when the review cannot be created', async function() {
      const reportRelayError = sinon.spy();

      expectRelayQuery({
        name: addPrReviewMutation.operation.name,
        variables: {
          input: {pullRequestId: 'pr0'},
        },
      }, op => {
        return relayResponseBuilder(op)
          .addError('Oh no')
          .build();
      }).resolve();

      const pullRequest = pullRequestBuilder(pullRequestQuery).id('pr0').build();
      const wrapper = shallow(buildApp({pullRequest, reportRelayError}))
        .find(PullRequestCheckoutController)
        .renderProp('children')(noop);

      const didSubmitComment = sinon.spy();
      const didFailComment = sinon.spy();

      await wrapper.find(ReviewsView).prop('addSingleComment')(
        'body', 'thread0', 'comment1', 'file1.txt', 20, {didSubmitComment, didFailComment},
      );

      assert.isTrue(reportRelayError.calledWith('Unable to submit your comment'));
      assert.isFalse(didSubmitComment.called);
      assert.isTrue(didFailComment.called);
    });

    it('creates a notification and deletes the review when the comment cannot be added', async function() {
      const reportRelayError = sinon.spy();

      expectRelayQuery({
        name: addPrReviewMutation.operation.name,
        variables: {
          input: {pullRequestId: 'pr0'},
        },
      }, op => {
        return relayResponseBuilder(op)
          .addPullRequestReview(m => {
            m.reviewEdge(e => e.node(r => r.id('review0')));
          })
          .build();
      }).resolve();

      expectRelayQuery({
        name: addPrReviewCommentMutation.operation.name,
        variables: {
          input: {body: 'body', inReplyTo: 'comment1', pullRequestReviewId: 'review0'},
        },
      }, op => {
        return relayResponseBuilder(op)
          .addError('Kerpow')
          .addError('Wat')
          .build();
      }).resolve();

      expectRelayQuery({
        name: deletePrReviewMutation.operation.name,
        variables: {
          input: {pullRequestReviewId: 'review0'},
        },
      }, op => {
        return relayResponseBuilder(op).build();
      }).resolve();

      const pullRequest = pullRequestBuilder(pullRequestQuery).id('pr0').build();
      const wrapper = shallow(buildApp({pullRequest, reportRelayError}))
        .find(PullRequestCheckoutController)
        .renderProp('children')(noop);

      const didSubmitComment = sinon.spy();
      const didFailComment = sinon.spy();

      await wrapper.find(ReviewsView).prop('addSingleComment')(
        'body', 'thread0', 'comment1', 'file2.txt', 5, {didSubmitComment, didFailComment},
      );

      assert.isTrue(reportRelayError.calledWith('Unable to submit your comment'));
      assert.isTrue(didSubmitComment.called);
      assert.isTrue(didFailComment.called);
    });

    it('includes errors from the review deletion', async function() {
      const reportRelayError = sinon.spy();

      expectRelayQuery({
        name: addPrReviewMutation.operation.name,
        variables: {
          input: {pullRequestId: 'pr0'},
        },
      }, op => {
        return relayResponseBuilder(op)
          .addPullRequestReview(m => {
            m.reviewEdge(e => e.node(r => r.id('review0')));
          })
          .build();
      }).resolve();

      expectRelayQuery({
        name: addPrReviewCommentMutation.operation.name,
        variables: {
          input: {body: 'body', inReplyTo: 'comment1', pullRequestReviewId: 'review0'},
        },
      }, op => {
        return relayResponseBuilder(op)
          .addError('Kerpow')
          .addError('Wat')
          .build();
      }).resolve();

      expectRelayQuery({
        name: deletePrReviewMutation.operation.name,
        variables: {
          input: {pullRequestReviewId: 'review0'},
        },
      }, op => {
        return relayResponseBuilder(op)
          .addError('Bam')
          .build();
      }).resolve();

      const pullRequest = pullRequestBuilder(pullRequestQuery).id('pr0').build();
      const wrapper = shallow(buildApp({pullRequest, reportRelayError}))
        .find(PullRequestCheckoutController)
        .renderProp('children')(noop);

      await wrapper.find(ReviewsView).prop('addSingleComment')(
        'body', 'thread0', 'comment1', 'file1.txt', 10,
      );
    });

    it('creates a notification when the review cannot be submitted', async function() {
      const reportRelayError = sinon.spy();

      expectRelayQuery({
        name: addPrReviewMutation.operation.name,
        variables: {
          input: {pullRequestId: 'pr0'},
        },
      }, op => {
        return relayResponseBuilder(op)
          .addPullRequestReview(m => {
            m.reviewEdge(e => e.node(r => r.id('review0')));
          })
          .build();
      }).resolve();

      expectRelayQuery({
        name: addPrReviewCommentMutation.operation.name,
        variables: {
          input: {body: 'body', inReplyTo: 'comment1', pullRequestReviewId: 'review0'},
        },
      }, op => {
        return relayResponseBuilder(op)
          .addPullRequestReviewComment(m => {
            m.commentEdge(e => e.node(c => c.id('comment2')));
          })
          .build();
      }).resolve();

      expectRelayQuery({
        name: submitPrReviewMutation.operation.name,
        variables: {
          input: {pullRequestReviewId: 'review0', event: 'COMMENT'},
        },
      }, op => {
        return relayResponseBuilder(op)
          .addError('Ouch')
          .build();
      }).resolve();

      const pullRequest = pullRequestBuilder(pullRequestQuery).id('pr0').build();
      const wrapper = shallow(buildApp({pullRequest, reportRelayError}))
        .find(PullRequestCheckoutController)
        .renderProp('children')(noop);

      const didSubmitComment = sinon.spy();
      const didFailComment = sinon.spy();

      await wrapper.find(ReviewsView).prop('addSingleComment')(
        'body', 'thread0', 'comment1', 'file1.txt', 10, {didSubmitComment, didFailComment},
      );

      assert.isTrue(reportRelayError.calledWith('Unable to submit your comment'));
      assert.isTrue(didSubmitComment.called);
      assert.isTrue(didFailComment.called);
    });
  });

  describe('resolving threads', function() {
    it('hides the thread, then fires the mutation', async function() {
      const reportRelayError = sinon.spy();

      expectRelayQuery({
        name: resolveThreadMutation.operation.name,
        variables: {
          input: {threadId: 'thread0'},
        },
      }, op => relayResponseBuilder(op).build()).resolve();

      const wrapper = shallow(buildApp({reportRelayError}))
        .find(PullRequestCheckoutController)
        .renderProp('children')(noop);
      await wrapper.find(ReviewsView).prop('showThreadID')('thread0');

      assert.isTrue(wrapper.find(ReviewsView).prop('threadIDsOpen').has('thread0'));

      await wrapper.find(ReviewsView).prop('resolveThread')({id: 'thread0', viewerCanResolve: true});

      assert.isFalse(wrapper.find(ReviewsView).prop('threadIDsOpen').has('thread0'));
      assert.isFalse(reportRelayError.called);
    });

    it('is a no-op if the viewer cannot resolve the thread', async function() {
      const reportRelayError = sinon.spy();

      const wrapper = shallow(buildApp({reportRelayError}))
        .find(PullRequestCheckoutController)
        .renderProp('children')(noop);
      await wrapper.find(ReviewsView).prop('showThreadID')('thread0');

      await wrapper.find(ReviewsView).prop('resolveThread')({id: 'thread0', viewerCanResolve: false});

      assert.isTrue(wrapper.find(ReviewsView).prop('threadIDsOpen').has('thread0'));
      assert.isFalse(reportRelayError.called);
    });

    it('re-shows the thread and creates a notification when the thread cannot be resolved', async function() {
      const reportRelayError = sinon.spy();

      expectRelayQuery({
        name: resolveThreadMutation.operation.name,
        variables: {
          input: {threadId: 'thread0'},
        },
      }, op => relayResponseBuilder(op).addError('boom').build()).resolve();

      const wrapper = shallow(buildApp({reportRelayError}))
        .find(PullRequestCheckoutController)
        .renderProp('children')(noop);
      await wrapper.find(ReviewsView).prop('showThreadID')('thread0');

      await wrapper.find(ReviewsView).prop('resolveThread')({id: 'thread0', viewerCanResolve: true});

      assert.isTrue(wrapper.find(ReviewsView).prop('threadIDsOpen').has('thread0'));
      assert.isTrue(reportRelayError.calledWith('Unable to resolve the comment thread'));
    });
  });

  describe('unresolving threads', function() {
    it('calls the unresolve mutation', async function() {
      sinon.stub(atomEnv.notifications, 'addError').returns();

      expectRelayQuery({
        name: unresolveThreadMutation.operation.name,
        variables: {
          input: {threadId: 'thread1'},
        },
      }, op => relayResponseBuilder(op).build()).resolve();

      const wrapper = shallow(buildApp())
        .find(PullRequestCheckoutController)
        .renderProp('children')(noop);

      await wrapper.find(ReviewsView).prop('unresolveThread')({id: 'thread1', viewerCanUnresolve: true});

      assert.isFalse(atomEnv.notifications.addError.called);
    });

    it("is a no-op if the viewer can't unresolve the thread", async function() {
      const reportRelayError = sinon.spy();

      const wrapper = shallow(buildApp({reportRelayError}))
        .find(PullRequestCheckoutController)
        .renderProp('children')(noop);

      await wrapper.find(ReviewsView).prop('unresolveThread')({id: 'thread1', viewerCanUnresolve: false});

      assert.isFalse(reportRelayError.called);
    });

    it('creates a notification if the thread cannot be unresolved', async function() {
      const reportRelayError = sinon.spy();

      expectRelayQuery({
        name: unresolveThreadMutation.operation.name,
        variables: {
          input: {threadId: 'thread1'},
        },
      }, op => relayResponseBuilder(op).addError('ow').build()).resolve();

      const wrapper = shallow(buildApp({reportRelayError}))
        .find(PullRequestCheckoutController)
        .renderProp('children')(noop);

      await wrapper.find(ReviewsView).prop('unresolveThread')({id: 'thread1', viewerCanUnresolve: true});

      assert.isTrue(reportRelayError.calledWith('Unable to unresolve the comment thread'));
    });
  });

  describe('editing review comments', function() {
    it('calls the review comment update mutation and increments a metric', async function() {
      const reportRelayError = sinon.spy();
      sinon.stub(reporterProxy, 'addEvent');

      expectRelayQuery({
        name: updateReviewCommentMutation.operation.name,
        variables: {
          input: {pullRequestReviewCommentId: 'comment-0', body: 'new text'},
        },
      }, op => relayResponseBuilder(op).build()).resolve();

      const wrapper = shallow(buildApp({reportRelayError}))
        .find(PullRequestCheckoutController)
        .renderProp('children')(noop);

      await wrapper.find(ReviewsView).prop('updateComment')('comment-0', 'new text');

      assert.isFalse(reportRelayError.called);
      assert.isTrue(reporterProxy.addEvent.calledWith('update-review-comment', {package: 'github'}));
    });

    it('creates a notification and and re-throws the error if the comment cannot be updated', async function() {
      const reportRelayError = sinon.spy();
      sinon.stub(reporterProxy, 'addEvent');

      expectRelayQuery({
        name: updateReviewCommentMutation.operation.name,
        variables: {
          input: {pullRequestReviewCommentId: 'comment-0', body: 'new text'},
        },
      }, op => relayResponseBuilder(op).addError('not right now').build()).resolve();

      const wrapper = shallow(buildApp({reportRelayError}))
        .find(PullRequestCheckoutController)
        .renderProp('children')(noop);

      await assert.isRejected(
        wrapper.find(ReviewsView).prop('updateComment')('comment-0', 'new text'),
      );

      assert.isTrue(reportRelayError.calledWith('Unable to update comment'));
      assert.isFalse(reporterProxy.addEvent.called);
    });
  });

  describe('editing review summaries', function() {
    it('calls the review summary update mutation and increments a metric', async function() {
      const reportRelayError = sinon.spy();
      sinon.stub(reporterProxy, 'addEvent');

      expectRelayQuery({
        name: updatePrReviewMutation.operation.name,
        variables: {
          input: {pullRequestReviewId: 'review-0', body: 'stuff'},
        },
      }, op => relayResponseBuilder(op).build()).resolve();

      const wrapper = shallow(buildApp({reportRelayError}))
        .find(PullRequestCheckoutController)
        .renderProp('children')(noop);

      await wrapper.find(ReviewsView).prop('updateSummary')('review-0', 'stuff');

      assert.isFalse(reportRelayError.called);
      assert.isTrue(reporterProxy.addEvent.calledWith('update-review-summary', {package: 'github'}));
    });

    it('creates a notification and and re-throws the error if the summary cannot be updated', async function() {
      const reportRelayError = sinon.spy();
      sinon.stub(reporterProxy, 'addEvent');

      expectRelayQuery({
        name: updatePrReviewMutation.operation.name,
        variables: {
          input: {pullRequestReviewId: 'review-0', body: 'stuff'},
        },
      }, op => relayResponseBuilder(op).addError('not right now').build()).resolve();

      const wrapper = shallow(buildApp({reportRelayError}))
        .find(PullRequestCheckoutController)
        .renderProp('children')(noop);

      await assert.isRejected(
        wrapper.find(ReviewsView).prop('updateSummary')('review-0', 'stuff'),
      );

      assert.isTrue(reportRelayError.calledWith('Unable to update review summary'));
      assert.isFalse(reporterProxy.addEvent.called);
    });
  });

  describe('action methods', function() {
    let wrapper, openFilesTab, onTabSelected;

    beforeEach(function() {
      openFilesTab = sinon.spy();
      onTabSelected = sinon.spy();
      sinon.stub(atomEnv.workspace, 'open').resolves({openFilesTab, onTabSelected});
      sinon.stub(reporterProxy, 'addEvent');
      wrapper = shallow(buildApp())
        .find(PullRequestCheckoutController)
        .renderProp('children')(noop);
    });

    it('opens file on disk', async function() {
      await wrapper.find(ReviewsView).prop('openFile')('filepath', 420);
      assert.isTrue(atomEnv.workspace.open.calledWith(
        path.join(localRepository.getWorkingDirectoryPath(), 'filepath'), {
          initialLine: 420 - 1,
          initialColumn: 0,
          pending: true,
        },
      ));
      assert.isTrue(reporterProxy.addEvent.calledWith('reviews-dock-open-file', {package: 'github'}));
    });

    it('opens diff in PR detail item', async function() {
      await wrapper.find(ReviewsView).prop('openDiff')('filepath', 420);
      assert.isTrue(atomEnv.workspace.open.calledWith(
        IssueishDetailItem.buildURI({
          host: 'github.com',
          owner: 'atom',
          repo: 'github',
          number: 1995,
          workdir: localRepository.getWorkingDirectoryPath(),
        }), {
          pending: true,
          searchAllPanes: true,
        },
      ));
      assert.isTrue(openFilesTab.calledWith({changedFilePath: 'filepath', changedFilePosition: 420}));
      assert.isTrue(reporterProxy.addEvent.calledWith('reviews-dock-open-diff', {
        package: 'github', component: 'BareReviewsController',
      }));
    });

    it('opens overview of a PR detail item', async function() {
      await wrapper.find(ReviewsView).prop('openPR')();
      assert.isTrue(atomEnv.workspace.open.calledWith(
        IssueishDetailItem.buildURI({
          host: 'github.com',
          owner: 'atom',
          repo: 'github',
          number: 1995,
          workdir: localRepository.getWorkingDirectoryPath(),
        }), {
          pending: true,
          searchAllPanes: true,
        },
      ));
      assert.isTrue(reporterProxy.addEvent.calledWith('reviews-dock-open-pr', {
        package: 'github', component: 'BareReviewsController',
      }));
    });

    it('manages the open/close state of the summary section', async function() {
      assert.isTrue(await wrapper.find(ReviewsView).prop('summarySectionOpen'), true);

      await wrapper.find(ReviewsView).prop('hideSummaries')();
      assert.isTrue(await wrapper.find(ReviewsView).prop('summarySectionOpen'), false);

      await wrapper.find(ReviewsView).prop('showSummaries')();
      assert.isTrue(await wrapper.find(ReviewsView).prop('summarySectionOpen'), true);
    });

    it('manages the open/close state of the comment section', async function() {
      assert.isTrue(await wrapper.find(ReviewsView).prop('commentSectionOpen'), true);

      await wrapper.find(ReviewsView).prop('hideComments')();
      assert.isTrue(await wrapper.find(ReviewsView).prop('commentSectionOpen'), false);

      await wrapper.find(ReviewsView).prop('showComments')();
      assert.isTrue(await wrapper.find(ReviewsView).prop('commentSectionOpen'), true);
    });
  });
});
