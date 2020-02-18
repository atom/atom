import IDGenerator from './id-generator';

export function createCrossReferencedEventResult(opts) {
  const idGen = IDGenerator.fromOpts(opts);

  const o = {
    id: idGen.generate('xref'),
    includeActor: true,
    isCrossRepository: true,
    isPullRequest: true,
    referencedAt: '2018-07-02T09:00:00Z',
    number: 1,
    title: 'title',
    actorLogin: 'actor',
    actorAvatarUrl: 'https://avatars.com/u/300',
    repositoryName: 'repo',
    repositoryIsPrivate: false,
    repositoryOwnerLogin: 'owner',
    ...opts,
  };

  if (o.isPullRequest) {
    if (!o.url) {
      o.url = `https://github.com/${o.repositoryOwnerLogin}/${o.repositoryName}/pulls/${o.number}`;
    }

    if (!o.prState) {
      o.prState = 'OPEN';
    }
  } else {
    if (!o.url) {
      o.url = `https://github.com/${o.repositoryOwnerLogin}/${o.repositoryName}/issues/${o.number}`;
    }

    if (!o.issueState) {
      o.issueState = 'OPEN';
    }
  }

  return {
    id: o.id,
    referencedAt: o.referencedAt,
    isCrossRepository: o.isCrossRepository,
    actor: !o.includeActor ? null : {
      avatarUrl: o.actorAvatarUrl,
      login: o.actorLogin,
    },
    source: {
      __typename: o.isPullRequest ? 'PullRequest' : 'Issue',
      number: o.number,
      title: o.title,
      url: o.url,
      issueState: o.issueState,
      prState: o.prState,
      repository: {
        isPrivate: o.repositoryIsPrivate,
        owner: {
          login: o.repositoryOwnerLogin,
        },
        name: o.repositoryName,
      },
    },
  };
};
