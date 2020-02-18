import React from 'react';
import {shallow} from 'enzyme';

import {BareReviewThreadsAccumulator} from '../../../lib/containers/accumulators/review-threads-accumulator';
import ReviewCommentsAccumulator from '../../../lib/containers/accumulators/review-comments-accumulator';
import {pullRequestBuilder} from '../../builder/graphql/pr';

import pullRequestQuery from '../../../lib/containers/accumulators/__generated__/reviewThreadsAccumulator_pullRequest.graphql.js';

describe('ReviewThreadsAccumulator', function() {
  function buildApp(opts = {}) {
    const options = {
      pullRequest: pullRequestBuilder(pullRequestQuery).build(),
      props: {},
      ...opts,
    };

    const props = {
      relay: {
        hasMore: () => false,
        loadMore: () => {},
        isLoading: () => false,
      },
      pullRequest: options.pullRequest,
      children: () => <div />,
      onDidRefetch: () => {},
      ...options.props,
    };

    return <BareReviewThreadsAccumulator {...props} />;
  }

  it('passes reviewThreads as its result batch', function() {
    const pullRequest = pullRequestBuilder(pullRequestQuery)
      .reviewThreads(conn => {
        conn.addEdge();
        conn.addEdge();
      })
      .build();

    const wrapper = shallow(buildApp({pullRequest}));

    const actualThreads = wrapper.find('Accumulator').prop('resultBatch');
    const expectedThreads = pullRequest.reviewThreads.edges.map(e => e.node);
    assert.deepEqual(actualThreads, expectedThreads);
  });

  it('handles an error from the thread query results', function() {
    const err = new Error('oh no');

    const children = sinon.stub().returns(<div className="done" />);
    const wrapper = shallow(buildApp({props: {children}}));
    const resultWrapper = wrapper.find('Accumulator').renderProp('children')(err, [], false);

    assert.isTrue(resultWrapper.exists('.done'));
    assert.isTrue(children.calledWith({
      errors: [err],
      commentThreads: [],
      loading: false,
    }));
  });

  it('recursively renders a ReviewCommentsAccumulator for each reviewThread', function() {
    const pullRequest = pullRequestBuilder(pullRequestQuery)
      .reviewThreads(conn => {
        conn.addEdge();
        conn.addEdge();
      })
      .build();
    const reviewThreads = pullRequest.reviewThreads.edges.map(e => e.node);

    const children = sinon.stub().returns(<div className="done" />);
    const wrapper = shallow(buildApp({pullRequest, props: {children}}));

    const args = [null, wrapper.find('Accumulator').prop('resultBatch'), false];
    const threadWrapper = wrapper.find('Accumulator').renderProp('children')(...args);

    const accumulator0 = threadWrapper.find(ReviewCommentsAccumulator);
    assert.strictEqual(accumulator0.prop('reviewThread'), reviewThreads[0]);
    const result0 = {error: null, comments: [1, 2, 3], loading: false};
    const commentsWrapper0 = accumulator0.renderProp('children')(result0);

    const accumulator1 = commentsWrapper0.find(ReviewCommentsAccumulator);
    assert.strictEqual(accumulator1.prop('reviewThread'), reviewThreads[1]);
    const result1 = {error: null, comments: [10, 20, 30], loading: false};
    const commentsWrapper1 = accumulator1.renderProp('children')(result1);

    assert.isTrue(commentsWrapper1.exists('.done'));
    assert.isTrue(children.calledWith({
      errors: [],
      commentThreads: [
        {thread: reviewThreads[0], comments: [1, 2, 3]},
        {thread: reviewThreads[1], comments: [10, 20, 30]},
      ],
      loading: false,
    }));
  });

  it('handles the arrival of additional review thread batches', function() {
    const pr0 = pullRequestBuilder(pullRequestQuery)
      .reviewThreads(conn => {
        conn.addEdge();
        conn.addEdge();
      })
      .build();

    const children = sinon.stub().returns(<div className="done" />);
    const batch0 = pr0.reviewThreads.edges.map(e => e.node);

    const wrapper = shallow(buildApp({pullRequest: pr0, props: {children}}));
    const threadsWrapper0 = wrapper.find('Accumulator').renderProp('children')(null, batch0, true);
    const comments0Wrapper0 = threadsWrapper0.find(ReviewCommentsAccumulator).renderProp('children')({
      error: null,
      comments: [1, 1, 1],
      loading: false,
    });
    comments0Wrapper0.find(ReviewCommentsAccumulator).renderProp('children')({
      error: null,
      comments: [2, 2, 2],
      loading: false,
    });

    assert.isTrue(children.calledWith({
      commentThreads: [
        {thread: batch0[0], comments: [1, 1, 1]},
        {thread: batch0[1], comments: [2, 2, 2]},
      ],
      errors: [],
      loading: true,
    }));
    children.resetHistory();

    const pr1 = pullRequestBuilder(pullRequestQuery)
      .reviewThreads(conn => {
        conn.addEdge();
        conn.addEdge();
        conn.addEdge();
      })
      .build();
    const batch1 = pr1.reviewThreads.edges.map(e => e.node);

    wrapper.setProps({pullRequest: pr1});
    const threadsWrapper1 = wrapper.find('Accumulator').renderProp('children')(null, batch1, false);
    const comments1Wrapper0 = threadsWrapper1.find(ReviewCommentsAccumulator).renderProp('children')({
      error: null,
      comments: [1, 1, 1],
      loading: false,
    });
    const comments1Wrapper1 = comments1Wrapper0.find(ReviewCommentsAccumulator).renderProp('children')({
      error: null,
      comments: [2, 2, 2],
      loading: false,
    });
    comments1Wrapper1.find(ReviewCommentsAccumulator).renderProp('children')({
      error: null,
      comments: [3, 3, 3],
      loading: false,
    });

    assert.isTrue(children.calledWith({
      commentThreads: [
        {thread: batch1[0], comments: [1, 1, 1]},
        {thread: batch1[1], comments: [2, 2, 2]},
        {thread: batch1[2], comments: [3, 3, 3]},
      ],
      errors: [],
      loading: false,
    }));
  });

  it('handles errors from each ReviewCommentsAccumulator', function() {
    const pullRequest = pullRequestBuilder(pullRequestQuery)
      .reviewThreads(conn => {
        conn.addEdge();
        conn.addEdge();
      })
      .build();
    const batch = pullRequest.reviewThreads.edges.map(e => e.node);

    const children = sinon.stub().returns(<div className="done" />);
    const wrapper = shallow(buildApp({pullRequest, props: {children}}));

    const threadsWrapper = wrapper.find('Accumulator').renderProp('children')(null, batch, false);
    const error0 = new Error('oh shit');
    const commentsWrapper0 = threadsWrapper.find(ReviewCommentsAccumulator).renderProp('children')({
      error: error0,
      comments: [],
      loading: false,
    });
    const error1 = new Error('wat');
    const commentsWrapper1 = commentsWrapper0.find(ReviewCommentsAccumulator).renderProp('children')({
      error: error1,
      comments: [],
      loading: false,
    });

    assert.isTrue(commentsWrapper1.exists('.done'));
    assert.isTrue(children.calledWith({
      errors: [error0, error1],
      commentThreads: [
        {thread: batch[0], comments: []},
        {thread: batch[1], comments: []},
      ],
      loading: false,
    }));
  });
});
