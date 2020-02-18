import React from 'react';
import PropTypes from 'prop-types';
import {graphql, createPaginationContainer} from 'react-relay';

import {PAGE_SIZE, PAGINATION_WAIT_TIME_MS} from '../../helpers';
import {RelayConnectionPropType} from '../../prop-types';
import Accumulator from './accumulator';
import ReviewCommentsAccumulator from './review-comments-accumulator';

export class BareReviewThreadsAccumulator extends React.Component {
  static propTypes = {
    // Relay props
    relay: PropTypes.shape({
      hasMore: PropTypes.func.isRequired,
      loadMore: PropTypes.func.isRequired,
      isLoading: PropTypes.func.isRequired,
    }).isRequired,
    pullRequest: PropTypes.shape({
      reviewThreads: RelayConnectionPropType(
        PropTypes.object,
      ),
    }),

    // Render prop. Called with (array of errors, array of threads, map of comments per thread, loading)
    children: PropTypes.func.isRequired,

    // Called right after refetch happens
    onDidRefetch: PropTypes.func.isRequired,
  }

  render() {
    const resultBatch = this.props.pullRequest.reviewThreads.edges.map(edge => edge.node);
    return (
      <Accumulator
        relay={this.props.relay}
        resultBatch={resultBatch}
        onDidRefetch={this.props.onDidRefetch}
        pageSize={PAGE_SIZE}
        waitTimeMs={PAGINATION_WAIT_TIME_MS}>
        {this.renderReviewThreads}
      </Accumulator>
    );
  }

  renderReviewThreads = (err, threads, loading) => {
    if (err) {
      return this.props.children({
        errors: [err],
        commentThreads: [],
        loading,
      });
    }

    return this.renderReviewThread({errors: [], commentsByThread: new Map(), loading}, threads);
  }

  renderReviewThread = (payload, threads) => {
    if (threads.length === 0) {
      const commentThreads = [];
      payload.commentsByThread.forEach((comments, thread) => {
        commentThreads.push({thread, comments});
      });
      return this.props.children({
        commentThreads,
        errors: payload.errors,
        loading: payload.loading,
      });
    }

    const [thread] = threads;
    return (
      <ReviewCommentsAccumulator
        onDidRefetch={this.props.onDidRefetch}
        reviewThread={thread}>
        {({error, comments, loading: threadLoading}) => {
          if (error) {
            payload.errors.push(error);
          }
          payload.commentsByThread.set(thread, comments);
          payload.loading = payload.loading || threadLoading;
          return this.renderReviewThread(payload, threads.slice(1));
        }}
      </ReviewCommentsAccumulator>
    );
  }
}

export default createPaginationContainer(BareReviewThreadsAccumulator, {
  pullRequest: graphql`
    fragment reviewThreadsAccumulator_pullRequest on PullRequest
    @argumentDefinitions(
      threadCount: {type: "Int!"}
      threadCursor: {type: "String"}
      commentCount: {type: "Int!"}
      commentCursor: {type: "String"}
    ) {
      url
      reviewThreads(
        first: $threadCount
        after: $threadCursor
      ) @connection(key: "ReviewThreadsAccumulator_reviewThreads") {
        pageInfo {
          hasNextPage
          endCursor
        }

        edges {
          cursor
          node {
            id
            isResolved
            resolvedBy {
              login
            }
            viewerCanResolve
            viewerCanUnresolve

            ...reviewCommentsAccumulator_reviewThread @arguments(
              commentCount: $commentCount
              commentCursor: $commentCursor
            )
          }
        }
      }
    }
  `,
}, {
  direction: 'forward',
  /* istanbul ignore next */
  getConnectionFromProps(props) {
    return props.pullRequest.reviewThreads;
  },
  /* istanbul ignore next */
  getFragmentVariables(prevVars, totalCount) {
    return {...prevVars, totalCount};
  },
  /* istanbul ignore next */
  getVariables(props, {count, cursor}, fragmentVariables) {
    return {
      url: props.pullRequest.url,
      threadCount: count,
      threadCursor: cursor,
      commentCount: fragmentVariables.commentCount,
    };
  },
  query: graphql`
    query reviewThreadsAccumulatorQuery(
      $url: URI!
      $threadCount: Int!
      $threadCursor: String
      $commentCount: Int!
    ) {
      resource(url: $url) {
        ... on PullRequest {
          ...reviewThreadsAccumulator_pullRequest @arguments(
            threadCount: $threadCount
            threadCursor: $threadCursor
            commentCount: $commentCount
          )
        }
      }
    }
  `,
});
