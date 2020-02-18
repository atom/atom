/* istanbul ignore file */

import {commitMutation, graphql} from 'react-relay';
import {ConnectionHandler} from 'relay-runtime';

import {renderMarkdown} from '../helpers';

const mutation = graphql`
  mutation addPrReviewMutation($input: AddPullRequestReviewInput!) {
    addPullRequestReview(input: $input) {
      reviewEdge {
        node {
          id
          body
          bodyHTML
          state
          submittedAt
          viewerCanReact
          viewerCanUpdate
          author {
            login
            avatarUrl
          }
          ...emojiReactionsController_reactable
        }
      }
    }
  }
`;

let placeholderID = 0;

export default (environment, {body, event, pullRequestID, viewerID}) => {
  const variables = {
    input: {pullRequestId: pullRequestID},
  };

  if (body) {
    variables.input.body = body;
  }
  if (event) {
    variables.input.event = event;
  }

  const configs = [{
    type: 'RANGE_ADD',
    parentID: pullRequestID,
    connectionInfo: [{key: 'ReviewSummariesAccumulator_reviews', rangeBehavior: 'append'}],
    edgeName: 'reviewEdge',
  }];

  function optimisticUpdater(store) {
    const pullRequest = store.get(pullRequestID);
    if (!pullRequest) {
      return;
    }

    const id = `add-pr-review:review:${placeholderID++}`;
    const review = store.create(id, 'PullRequestReview');
    review.setValue(id, 'id');
    review.setValue('PENDING', 'state');
    review.setValue(body, 'body');
    review.setValue(body ? renderMarkdown(body) : '...', 'bodyHTML');
    review.setLinkedRecords([], 'reactionGroups');
    review.setValue(false, 'viewerCanReact');
    review.setValue(false, 'viewerCanUpdate');

    let author;
    if (viewerID) {
      author = store.get(viewerID);
    } else {
      author = store.create(`add-pr-review-comment:author:${placeholderID++}`, 'User');
      author.setValue('...', 'login');
      author.setValue('atom://github/img/avatar.svg', 'avatarUrl');
    }
    review.setLinkedRecord(author, 'author');

    const reviews = ConnectionHandler.getConnection(pullRequest, 'ReviewSummariesAccumulator_reviews');
    const edge = ConnectionHandler.createEdge(store, reviews, review, 'PullRequestReviewEdge');
    ConnectionHandler.insertEdgeAfter(reviews, edge);
  }

  return new Promise((resolve, reject) => {
    commitMutation(
      environment,
      {
        mutation,
        variables,
        configs,
        optimisticUpdater,
        onCompleted: resolve,
        onError: reject,
      },
    );
  });
};
