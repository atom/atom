import React from 'react';
import {Emitter} from 'event-kit';
import {graphql, createRefetchContainer} from 'react-relay';
import PropTypes from 'prop-types';

import {PAGE_SIZE} from '../helpers';
import ReviewSummariesAccumulator from './accumulators/review-summaries-accumulator';
import ReviewThreadsAccumulator from './accumulators/review-threads-accumulator';

export class BareAggregatedReviewsContainer extends React.Component {
  static propTypes = {
    // Relay response
    relay: PropTypes.shape({
      refetch: PropTypes.func.isRequired,
    }),

    // Relay results.
    pullRequest: PropTypes.shape({
      id: PropTypes.string.isRequired,
    }).isRequired,

    // Render prop. Called with {errors, summaries, commentThreads, loading}.
    children: PropTypes.func.isRequired,

    // only fetch summaries when we specify a summariesRenderer
    summariesRenderer: PropTypes.func,

    // Report errors during refetch
    reportRelayError: PropTypes.func.isRequired,
  }

  constructor(props) {
    super(props);
    this.emitter = new Emitter();
  }

  render() {
    return (
      <ReviewSummariesAccumulator
        onDidRefetch={this.onDidRefetch}
        pullRequest={this.props.pullRequest}>
        {({error: summaryError, summaries, loading: summariesLoading}) => {
          return (
            <ReviewThreadsAccumulator
              onDidRefetch={this.onDidRefetch}
              pullRequest={this.props.pullRequest}>
              {payload => {
                const result = {
                  errors: [],
                  refetch: this.refetch,
                  summaries,
                  commentThreads: payload.commentThreads,
                  loading: payload.loading || summariesLoading,
                };

                if (summaryError) {
                  result.errors.push(summaryError);
                }
                result.errors.push(...payload.errors);

                return this.props.children(result);
              }}
            </ReviewThreadsAccumulator>
          );
        }}
      </ReviewSummariesAccumulator>
    );
  }


  refetch = callback => this.props.relay.refetch(
    {
      prId: this.props.pullRequest.id,
      reviewCount: PAGE_SIZE,
      reviewCursor: null,
      threadCount: PAGE_SIZE,
      threadCursor: null,
      commentCount: PAGE_SIZE,
      commentCursor: null,
    },
    null,
    err => {
      if (err) {
        this.props.reportRelayError('Unable to refresh reviews', err);
      } else {
        this.emitter.emit('did-refetch');
      }
      callback();
    },
    {force: true},
  );

  onDidRefetch = callback => this.emitter.on('did-refetch', callback);
}

export default createRefetchContainer(BareAggregatedReviewsContainer, {
  pullRequest: graphql`
    fragment aggregatedReviewsContainer_pullRequest on PullRequest
    @argumentDefinitions(
      reviewCount: {type: "Int!"}
      reviewCursor: {type: "String"}
      threadCount: {type: "Int!"}
      threadCursor: {type: "String"}
      commentCount: {type: "Int!"}
      commentCursor: {type: "String"}
    ) {
      id
      ...reviewSummariesAccumulator_pullRequest @arguments(
        reviewCount: $reviewCount
        reviewCursor: $reviewCursor
      )
      ...reviewThreadsAccumulator_pullRequest @arguments(
        threadCount: $threadCount
        threadCursor: $threadCursor
        commentCount: $commentCount
        commentCursor: $commentCursor
      )
    }
  `,
}, graphql`
  query aggregatedReviewsContainerRefetchQuery
  (
    $prId: ID!
    $reviewCount: Int!
    $reviewCursor: String
    $threadCount: Int!
    $threadCursor: String
    $commentCount: Int!
    $commentCursor: String
  ) {
    pullRequest: node(id: $prId) {
      ...prCheckoutController_pullRequest
      ...aggregatedReviewsContainer_pullRequest @arguments(
        reviewCount: $reviewCount
        reviewCursor: $reviewCursor
        threadCount: $threadCount
        threadCursor: $threadCursor
        commentCount: $commentCount
        commentCursor: $commentCursor
      )
    }
  }
`);
