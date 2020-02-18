/* istanbul ignore file */

import {commitMutation, graphql} from 'react-relay';

const mutation = graphql`
  mutation deletePrReviewMutation($input: DeletePullRequestReviewInput!) {
    deletePullRequestReview(input: $input) {
      pullRequestReview {
        id
      }
    }
  }
`;

export default (environment, {reviewID, pullRequestID}) => {
  const variables = {
    input: {pullRequestReviewId: reviewID},
  };

  const configs = [
    {
      type: 'NODE_DELETE',
      deletedIDFieldName: 'id',
    },
    {
      type: 'RANGE_DELETE',
      parentID: pullRequestID,
      connectionKeys: [{key: 'ReviewSummariesAccumulator_reviews'}],
      pathToConnection: ['pullRequest', 'reviews'],
      deletedIDFieldName: 'id',
    },
  ];

  return new Promise((resolve, reject) => {
    commitMutation(
      environment,
      {
        mutation,
        variables,
        configs,
        onCompleted: resolve,
        onError: reject,
      },
    );
  });
};
