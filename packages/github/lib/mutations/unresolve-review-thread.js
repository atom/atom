/* istanbul ignore file */

import {commitMutation, graphql} from 'react-relay';

const mutation = graphql`
  mutation unresolveReviewThreadMutation($input: UnresolveReviewThreadInput!) {
    unresolveReviewThread(input: $input) {
      thread {
        id
        isResolved
        viewerCanResolve
        viewerCanUnresolve
        resolvedBy {
          id
          login
        }
      }
    }
  }
`;

export default (environment, {threadID, viewerID, viewerLogin}) => {
  const variables = {
    input: {
      threadId: threadID,
    },
  };

  const optimisticResponse = {
    unresolveReviewThread: {
      thread: {
        id: threadID,
        isResolved: false,
        viewerCanResolve: true,
        viewerCanUnresolve: false,
        resolvedBy: {
          id: viewerID,
          login: viewerLogin || 'you',
        },
      },
    },
  };

  return new Promise((resolve, reject) => {
    commitMutation(
      environment,
      {
        mutation,
        variables,
        optimisticResponse,
        onCompleted: resolve,
        onError: reject,
      },
    );
  });
};
