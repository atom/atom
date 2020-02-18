/* istanbul ignore file */

import {commitMutation, graphql} from 'react-relay';

const mutation = graphql`
  mutation submitPrReviewMutation($input: SubmitPullRequestReviewInput!) {
    submitPullRequestReview(input: $input) {
      pullRequestReview {
        id
      }
    }
  }
`;

export default (environment, {reviewID, event}) => {
  const variables = {
    input: {
      event,
      pullRequestReviewId: reviewID,
    },
  };

  return new Promise((resolve, reject) => {
    commitMutation(
      environment,
      {
        mutation,
        variables,
        onCompleted: resolve,
        onError: reject,
      },
    );
  });
};
