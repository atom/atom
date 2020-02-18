import React from 'react';
import {shallow} from 'enzyme';

import {BareReviewSummariesAccumulator} from '../../../lib/containers/accumulators/review-summaries-accumulator';
import {pullRequestBuilder} from '../../builder/graphql/pr';

import pullRequestQuery from '../../../lib/containers/accumulators/__generated__/reviewSummariesAccumulator_pullRequest.graphql.js';

describe('ReviewSummariesAccumulator', function() {
  function buildApp(opts = {}) {
    const options = {
      buildPullRequest: () => {},
      props: {},
      ...opts,
    };

    const builder = pullRequestBuilder(pullRequestQuery);
    options.buildPullRequest(builder);

    const props = {
      relay: {
        hasMore: () => false,
        loadMore: () => {},
        isLoading: () => false,
      },
      pullRequest: builder.build(),
      onDidRefetch: () => {},
      children: () => <div />,
      ...options.props,
    };

    return <BareReviewSummariesAccumulator {...props} />;
  }

  it('passes pull request reviews as its result batches', function() {
    function buildPullRequest(b) {
      b.reviews(conn => {
        conn.addEdge(e => e.node(r => r.id(0)));
        conn.addEdge(e => e.node(r => r.id(1)));
        conn.addEdge(e => e.node(r => r.id(3)));
      });
    }

    const wrapper = shallow(buildApp({buildPullRequest}));

    assert.deepEqual(
      wrapper.find('Accumulator').prop('resultBatch').map(each => each.id),
      [0, 1, 3],
    );
  });

  it('calls a children render prop with sorted review summaries', function() {
    const children = sinon.stub().returns(<div className="done" />);
    const wrapper = shallow(buildApp({props: {children}}));

    const resultWrapper = wrapper.find('Accumulator').renderProp('children')(
      null,
      [
        {submittedAt: '2019-01-01T10:00:00Z'},
        {submittedAt: '2019-01-05T10:00:00Z'},
        {submittedAt: '2019-01-02T10:00:00Z'},
      ],
      false,
    );

    assert.isTrue(resultWrapper.exists('.done'));
    assert.isTrue(children.calledWith({
      error: null,
      summaries: [
        {submittedAt: '2019-01-01T10:00:00Z'},
        {submittedAt: '2019-01-02T10:00:00Z'},
        {submittedAt: '2019-01-05T10:00:00Z'},
      ],
      loading: false,
    }));
  });
});
