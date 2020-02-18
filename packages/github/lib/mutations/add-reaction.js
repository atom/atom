/* istanbul ignore file */

import {commitMutation, graphql} from 'react-relay';

const mutation = graphql`
  mutation addReactionMutation($input: AddReactionInput!) {
    addReaction(input: $input) {
      subject {
        reactionGroups {
          content
          viewerHasReacted
          users {
            totalCount
          }
        }
      }
    }
  }
`;

let placeholderID = 0;

export default (environment, subjectId, content) => {
  const variables = {
    input: {
      content,
      subjectId,
    },
  };

  function optimisticUpdater(store) {
    const subject = store.get(subjectId);
    const reactionGroups = subject.getLinkedRecords('reactionGroups') || [];
    const reactionGroup = reactionGroups.find(group => group.getValue('content') === content);
    if (!reactionGroup) {
      const group = store.create(`add-reaction:reaction-group:${placeholderID++}`, 'ReactionGroup');
      group.setValue(true, 'viewerHasReacted');
      group.setValue(content, 'content');

      const conn = store.create(`add-reaction:reacting-user-conn:${placeholderID++}`, 'ReactingUserConnection');
      conn.setValue(1, 'totalCount');
      group.setLinkedRecord(conn, 'users');

      subject.setLinkedRecords([...reactionGroups, group], 'reactionGroups');

      return;
    }

    reactionGroup.setValue(true, 'viewerHasReacted');
    const conn = reactionGroup.getLinkedRecord('users');
    conn.setValue(conn.getValue('totalCount') + 1, 'totalCount');
  }

  return new Promise((resolve, reject) => {
    commitMutation(
      environment,
      {
        mutation,
        variables,
        optimisticUpdater,
        onCompleted: resolve,
        onError: reject,
      },
    );
  });
};
