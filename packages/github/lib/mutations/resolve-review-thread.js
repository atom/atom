/* istanbul ignore file */

import {
  commitMutation,
  graphql,
} from 'react-relay';

const mutation = graphql`
  mutation resolveReviewThreadMutation($input: ResolveReviewThreadInput!) {
    resolveReviewThread(input: $input) {
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
    resolveReviewThread: {
      thread: {
        id: threadID,
        isResolved: true,
        viewerCanResolve: false,
        viewerCanUnresolve: true,
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
