import IDGenerator from './id-generator';

export function createCommitComment(opts = {}) {
  const idGen = IDGenerator.fromOpts(opts);

  const o = {
    id: idGen.generate('comment-comment'),
    commitOid: '1234abcd',
    includeAuthor: true,
    authorLogin: 'author0',
    authorAvatarUrl: 'https://avatars2.githubusercontent.com/u/0?v=12',
    bodyHTML: '<p>body</p>',
    createdAt: '2018-06-28T15:04:05Z',
    commentPath: null,
    ...opts,
  };

  const comment = {
    id: o.id,
    author: null,
    commit: {
      oid: o.commitOid,
    },
    bodyHTML: o.bodyHTML,
    createdAt: o.createdAt,
    path: o.commentPath,
  };

  if (o.includeAuthor) {
    comment.author = {
      __typename: 'User',
      id: idGen.generate('user'),
      login: o.authorLogin,
      avatarUrl: o.authorAvatarUrl,
    }
  }

  return comment;
}

export function createCommitCommentThread(opts = {}) {
  const idGen = IDGenerator.fromOpts(opts);

  const o = {
    id: idGen.generate('commit-comment-thread'),
    commitOid: '1234abcd',
    commitCommentOpts: [],
    ...opts,
  };

  return {
    id: o.id,
    commit: {
      oid: o.commitOid,
    },
    comments: {
      edges: o.commitCommentOpts.map(eachOpts => {
        return {
          node: createCommitComment({
            ...idGen.embed(),
            ...eachOpts,
          }),
        }
      }),
    },
  };
}
