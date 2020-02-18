/* istanbul ignore file */

import {commitMutation, graphql} from 'react-relay';

const mutation = graphql`
  mutation createRepositoryMutation($input: CreateRepositoryInput!) {
    createRepository(input: $input) {
      repository {
        sshUrl
        url
      }
    }
  }
`;

export default (environment, {name, ownerID, visibility}) => {
  const variables = {
    input: {
      name,
      ownerId: ownerID,
      visibility,
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
