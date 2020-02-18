import IDGenerator from './id-generator';

export function createCommitResult(opts = {}) {
  const idGen = IDGenerator.fromOpts(opts);

  const o = {
    id: idGen.generate('commit'),
    authorName: 'Author',
    authorHasUser: true,
    authorLogin: 'author0',
    authorAvatarURL: 'https://avatars2.githubusercontent.com/u/0?v=1',
    authoredByCommitter: true,
    oid: '0000',
    message: 'message',
    messageHeadlineHTML: '<h1>headline</h1>',
    ...opts,
  };

  if (!o.committerLogin) {
    o.committerLogin = o.authorLogin;
  }
  if (!o.committerName) {
    o.committerName = o.authorName;
  }
  if (!o.committerAvatarURL) {
    o.committerAvatarURL = o.authorAvatarURL;
  }
  if (!o.committerHasUser) {
    o.committerHasUser = o.authorHasUser;
  }

  return {
    author: {
      name: o.authorName,
      avatarUrl: o.authorAvatarURL,
      user: o.authorHasUser ? {login: o.authorLogin} : null,
    },
    committer: {
      name: o.committerName,
      avatarUrl: o.committerAvatarURL,
      user: o.committerHasUser ? {login: o.committerLogin} : null,
    },
    authoredByCommitter: o.authoredByCommitter,
    oid: o.oid,
    message: o.message,
    messageHeadlineHTML: o.messageHeadlineHTML,
  }
}
