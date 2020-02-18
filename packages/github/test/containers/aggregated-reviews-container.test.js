import React from 'react';
import {shallow} from 'enzyme';

import {BareAggregatedReviewsContainer} from '../../lib/containers/aggregated-reviews-container';
import ReviewSummariesAccumulator from '../../lib/containers/accumulators/review-summaries-accumulator';
import ReviewThreadsAccumulator from '../../lib/containers/accumulators/review-threads-accumulator';
import {pullRequestBuilder, reviewThreadBuilder} from '../builder/graphql/pr';

import pullRequestQuery from '../../lib/containers/__generated__/aggregatedReviewsContainer_pullRequest.graphql.js';
import summariesQuery from '../../lib/containers/accumulators/__generated__/reviewSummariesAccumulator_pullRequest.graphql.js';
import threadsQuery from '../../lib/containers/accumulators/__generated__/reviewThreadsAccumulator_pullRequest.graphql.js';
import commentsQuery from '../../lib/containers/accumulators/__generated__/reviewCommentsAccumulator_reviewThread.graphql.js';

describe('AggregatedReviewsContainer', function() {
  function buildApp(override = {}) {
    const props = {
      pullRequest: pullRequestBuilder(pullRequestQuery).build(),
      relay: {
        refetch: () => {},
      },
      reportRelayError: () => {},
      ...override,
    };

    return <BareAggregatedReviewsContainer {...props} />;
  }

  it('reports errors from review summaries or review threads', function() {
    const children = sinon.stub().returns(<div className="done" />);
    const wrapper = shallow(buildApp({children}));

    const summaryError = new Error('everything is on fire');
    const summariesWrapper = wrapper.find(ReviewSummariesAccumulator).renderProp('children')({
      error: summaryError,
      summaries: [],
      loading: false,
    });

    const threadError0 = new Error('tripped over a power cord');
    const threadError1 = new Error('cosmic rays');
    const threadsWrapper = summariesWrapper.find(ReviewThreadsAccumulator).renderProp('children')({
      errors: [threadError0, threadError1],
      commentThreads: [],
      loading: false,
    });

    assert.isTrue(threadsWrapper.exists('.done'));
    assert.isTrue(children.calledWith({
      errors: [summaryError, threadError0, threadError1],
      refetch: sinon.match.func,
      summaries: [],
      commentThreads: [],
      loading: false,
    }));
  });

  it('collects review summaries', function() {
    const pullRequest0 = pullRequestBuilder(summariesQuery)
      .reviews(conn => {
        conn.addEdge(e => e.node(r => r.id(0)));
        conn.addEdge(e => e.node(r => r.id(1)));
        conn.addEdge(e => e.node(r => r.id(2)));
      })
      .build();
    const batch0 = pullRequest0.reviews.edges.map(e => e.node);

    const children = sinon.stub().returns(<div className="done" />);
    const wrapper = shallow(buildApp({children}));
    const summariesWrapper0 = wrapper.find(ReviewSummariesAccumulator).renderProp('children')({
      error: null,
      summaries: batch0,
      loading: true,
    });
    const threadsWrapper0 = summariesWrapper0.find(ReviewThreadsAccumulator).renderProp('children')({
      errors: [],
      commentThreads: [],
      loading: false,
    });
    assert.isTrue(threadsWrapper0.exists('.done'));
    assert.isTrue(children.calledWith({
      errors: [],
      summaries: batch0,
      refetch: sinon.match.func,
      commentThreads: [],
      loading: true,
    }));

    const pullRequest1 = pullRequestBuilder(summariesQuery)
      .reviews(conn => {
        conn.addEdge(e => e.node(r => r.id(0)));
        conn.addEdge(e => e.node(r => r.id(1)));
        conn.addEdge(e => e.node(r => r.id(2)));
        conn.addEdge(e => e.node(r => r.id(3)));
        conn.addEdge(e => e.node(r => r.id(4)));
      })
      .build();
    const batch1 = pullRequest1.reviews.edges.map(e => e.node);

    const summariesWrapper1 = wrapper.find(ReviewSummariesAccumulator).renderProp('children')({
      error: null,
      summaries: batch1,
      loading: false,
    });
    const threadsWrapper1 = summariesWrapper1.find(ReviewThreadsAccumulator).renderProp('children')({
      errors: [],
      commentThreads: [],
      loading: false,
    });
    assert.isTrue(threadsWrapper1.exists('.done'));
    assert.isTrue(children.calledWith({
      errors: [],
      refetch: sinon.match.func,
      summaries: batch1,
      commentThreads: [],
      loading: false,
    }));
  });

  it('collects and aggregates review threads and comments', function() {
    const pullRequest = pullRequestBuilder(pullRequestQuery).build();

    const threadsPullRequest = pullRequestBuilder(threadsQuery)
      .reviewThreads(conn => {
        conn.addEdge();
        conn.addEdge();
        conn.addEdge();
      })
      .build();

    const thread0 = reviewThreadBuilder(commentsQuery)
      .comments(conn => {
        conn.addEdge(e => e.node(c => c.id(10)));
        conn.addEdge(e => e.node(c => c.id(11)));
      })
      .build();

    const thread1 = reviewThreadBuilder(commentsQuery)
      .comments(conn => {
        conn.addEdge(e => e.node(c => c.id(20)));
      })
      .build();

    const thread2 = reviewThreadBuilder(commentsQuery)
      .comments(conn => {
        conn.addEdge(e => e.node(c => c.id(30)));
        conn.addEdge(e => e.node(c => c.id(31)));
        conn.addEdge(e => e.node(c => c.id(32)));
      })
      .build();

    const threads = threadsPullRequest.reviewThreads.edges.map(e => e.node);
    const commentThreads = [
      {thread: threads[0], comments: thread0.comments.edges.map(e => e.node)},
      {thread: threads[1], comments: thread1.comments.edges.map(e => e.node)},
      {thread: threads[2], comments: thread2.comments.edges.map(e => e.node)},
    ];

    const children = sinon.stub().returns(<div className="done" />);
    const wrapper = shallow(buildApp({pullRequest, children}));

    const summariesWrapper = wrapper.find(ReviewSummariesAccumulator).renderProp('children')({
      error: null,
      summaries: [],
      loading: false,
    });
    const threadsWrapper = summariesWrapper.find(ReviewThreadsAccumulator).renderProp('children')({
      errors: [],
      commentThreads,
      loading: false,
    });
    assert.isTrue(threadsWrapper.exists('.done'));

    assert.isTrue(children.calledWith({
      errors: [],
      refetch: sinon.match.func,
      summaries: [],
      commentThreads,
      loading: false,
    }));
  });

  it('broadcasts a refetch event on refretch', function() {
    const refetchStub = sinon.stub().callsArg(2);

    let refetchFn = null;
    const children = ({refetch}) => {
      refetchFn = refetch;
      return <div className="done" />;
    };

    const wrapper = shallow(buildApp({
      children,
      relay: {refetch: refetchStub},
    }));

    const summariesAccumulator = wrapper.find(ReviewSummariesAccumulator);

    const cb0 = sinon.spy();
    summariesAccumulator.prop('onDidRefetch')(cb0);

    const summariesWrapper = summariesAccumulator.renderProp('children')({
      error: null,
      summaries: [],
      loading: false,
    });

    const threadAccumulator = summariesWrapper.find(ReviewThreadsAccumulator);

    const cb1 = sinon.spy();
    threadAccumulator.prop('onDidRefetch')(cb1);

    const threadWrapper = threadAccumulator.renderProp('children')({
      errors: [],
      commentThreads: [],
      loading: false,
    });

    assert.isTrue(threadWrapper.exists('.done'));
    assert.isNotNull(refetchFn);

    const done = sinon.spy();
    refetchFn(done);

    assert.isTrue(refetchStub.called);
    assert.isTrue(cb0.called);
    assert.isTrue(cb1.called);
  });

  it('reports an error encountered during refetch', function() {
    const e = new Error('kerpow');
    const refetchStub = sinon.stub().callsFake((...args) => args[2](e));
    const reportRelayError = sinon.spy();

    let refetchFn = null;
    const children = ({refetch}) => {
      refetchFn = refetch;
      return <div className="done" />;
    };

    const wrapper = shallow(buildApp({
      children,
      relay: {refetch: refetchStub},
      reportRelayError,
    }));

    const summariesAccumulator = wrapper.find(ReviewSummariesAccumulator);

    const cb0 = sinon.spy();
    summariesAccumulator.prop('onDidRefetch')(cb0);

    const summariesWrapper = summariesAccumulator.renderProp('children')({
      error: null,
      summaries: [],
      loading: false,
    });

    const threadAccumulator = summariesWrapper.find(ReviewThreadsAccumulator);

    const cb1 = sinon.spy();
    threadAccumulator.prop('onDidRefetch')(cb1);

    const threadWrapper = threadAccumulator.renderProp('children')({
      errors: [],
      commentThreads: [],
      loading: false,
    });

    assert.isTrue(threadWrapper.exists('.done'));
    assert.isNotNull(refetchFn);

    const done = sinon.spy();
    refetchFn(done);

    assert.isTrue(refetchStub.called);
    assert.isTrue(reportRelayError.calledWith(sinon.match.string, e));
    assert.isFalse(cb0.called);
    assert.isFalse(cb1.called);
  });
});
