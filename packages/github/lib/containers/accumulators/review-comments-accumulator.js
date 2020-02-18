import React from 'react';
import PropTypes from 'prop-types';
import {graphql, createPaginationContainer} from 'react-relay';

import {PAGE_SIZE, PAGINATION_WAIT_TIME_MS} from '../../helpers';
import {RelayConnectionPropType} from '../../prop-types';
import Accumulator from './accumulator';

export class BareReviewCommentsAccumulator extends React.Component {
  static propTypes = {
    // Relay props
    relay: PropTypes.shape({
      hasMore: PropTypes.func.isRequired,
      loadMore: PropTypes.func.isRequired,
      isLoading: PropTypes.func.isRequired,
    }).isRequired,
    reviewThread: PropTypes.shape({
      comments: RelayConnectionPropType(
        PropTypes.object,
      ),
    }),

    // Render prop. Called with (error or null, array of all review comments, loading)
    children: PropTypes.func,

    // Called right after refetch happens
    onDidRefetch: PropTypes.func.isRequired,
  }

  render() {
    const resultBatch = this.props.reviewThread.comments.edges.map(edge => edge.node);

    return (
      <Accumulator
        relay={this.props.relay}
        resultBatch={resultBatch}
        onDidRefetch={this.props.onDidRefetch}
        pageSize={PAGE_SIZE}
        waitTimeMs={PAGINATION_WAIT_TIME_MS}>
        {(error, comments, loading) => this.props.children({error, comments, loading})}
      </Accumulator>
    );
  }
}

export default createPaginationContainer(BareReviewCommentsAccumulator, {
  reviewThread: graphql`
    fragment reviewCommentsAccumulator_reviewThread on PullRequestReviewThread
    @argumentDefinitions(
      commentCount: {type: "Int!"}
      commentCursor: {type: "String"},
    ) {
      id
      comments(
        first: $commentCount
        after: $commentCursor
      ) @connection(key: "ReviewCommentsAccumulator_comments") {
        pageInfo {
          hasNextPage
          endCursor
        }

        edges {
          cursor
          node {
            id
            author {
              avatarUrl
              login
              url
            }
            bodyHTML
            body
            isMinimized
            state
            viewerCanReact
            viewerCanUpdate
            path
            position
            createdAt
            lastEditedAt
            url
            authorAssociation
            ...emojiReactionsController_reactable
          }
        }
      }
    }
  `,
}, {
  direction: 'forward',
  /* istanbul ignore next */
  getConnectionFromProps(props) {
    return props.reviewThread.comments;
  },
  /* istanbul ignore next */
  getFragmentVariables(prevVars, totalCount) {
    return {...prevVars, totalCount};
  },
  /* istanbul ignore next */
  getVariables(props, {count, cursor}) {
    return {
      id: props.reviewThread.id,
      commentCount: count,
      commentCursor: cursor,
    };
  },
  query: graphql`
    query reviewCommentsAccumulatorQuery(
      $id: ID!
      $commentCount: Int!
      $commentCursor: String
    ) {
      node(id: $id) {
        ... on PullRequestReviewThread {
          ...reviewCommentsAccumulator_reviewThread @arguments(
            commentCount: $commentCount
            commentCursor: $commentCursor
          )
        }
      }
    }
  `,
});
