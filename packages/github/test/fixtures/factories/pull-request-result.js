import IDGenerator from './id-generator';

function createCommitResult(attrs = {}) {
  return {
    commit: {
      status: {
        contexts: [ {state: 'PASSED'} ]
      }
    }
  };
}

export function createStatusContextResult(attrs = {}) {
  const idGen = IDGenerator.fromOpts(attrs);

  const o = {
    id: idGen.generate('context'),
    context: 'context',
    description: 'description',
    state: 'SUCCESS',
    creatorLogin: 'me',
    creatorAvatarUrl: 'https://avatars3.githubusercontent.com/u/000?v=1',
    ...idGen.embed(),
    ...attrs,
  }

  if (!o.targetUrl) {
    o.targetUrl = `https://ci.provider.com/builds/${o.id}`
  }

  return {
    id: o.id,
    context: o.context,
    description: o.description,
    state: o.state,
    targetUrl: o.targetUrl,
    creator: {
      avatarUrl: o.creatorAvatarUrl,
      login: o.creatorLogin,
    }
  }
}

export function createPrStatusesResult(attrs = {}) {
  const idGen = IDGenerator.fromOpts(attrs);

  const o = {
    id: idGen.generate('pullrequest'),
    number: 0,
    repositoryID: idGen.generate('repository'),
    summaryState: null,
    states: null,
    headRefName: 'master',
    includeEdges: false,
    ...attrs,
  };

  if (o.summaryState && !o.states) {
    o.states = [{state: o.summaryState, ...idGen.embed()}];
  }

  if (o.states) {
    o.states = o.states.map(state => {
      return typeof state === 'string'
        ? {state: state, ...idGen.embed()}
        : state
    });
  }

  const commit = {
    id: idGen.generate('commit'),
  };

  if (o.states === null) {
    commit.status = null;
  } else {
    commit.status = {
      state: o.summaryState,
      contexts: o.states.map(createStatusContextResult),
    };
  }

  const recentCommits = o.includeEdges
    ? {edges: [{node: {id: idGen.generate('node'), commit}}]}
    : {nodes: [{commit, id: idGen.generate('node')}]};

  return {
    __typename: 'PullRequest',
    id: o.id,
    number: o.number,
    title: `Pull Request ${o.number}`,
    url: `https://github.com/owner/repo/pulls/${o.number}`,
    author: {
      __typename: 'User',
      login: 'me',
      avatarUrl: 'https://avatars3.githubusercontent.com/u/000?v=4',
      id: 'user0'
    },
    createdAt: '2018-06-12T14:50:08Z',
    headRefName: o.headRefName,

    repository: {
      id: o.repositoryID,
    },

    recentCommits,
  }
}

export function createPullRequestResult(attrs = {}) {
  const idGen = IDGenerator.fromOpts(attrs);

  const o = {
    id: idGen.generate('pullrequest'),
    number: 0,
    repositoryID: idGen.generate('repository'),
    summaryState: null,
    states: null,
    headRefName: 'master',
    includeEdges: false,
    ...attrs,
  };

  if (o.summaryState && !o.states) {
    o.states = [{state: o.summaryState, ...idGen.embed()}];
  }

  if (o.states) {
    o.states = o.states.map(state => {
      return typeof state === 'string'
        ? {state: state, ...idGen.embed()}
        : state
    });
  }

  const commit = {
    id: idGen.generate('commit'),
  };

  if (o.states === null) {
    commit.status = null;
  } else {
    commit.status = {
      state: o.summaryState,
      contexts: o.states.map(createStatusContextResult),
    };
  }

  const commits = o.includeEdges
    ? {edges: [{node: {id: idGen.generate('node'), commit}}]}
    : {nodes: [{commit, id: idGen.generate('node')}]};

  return {
    __typename: 'PullRequest',
    id: o.id,
    number: o.number,
    title: `Pull Request ${o.number}`,
    url: `https://github.com/owner/repo/pulls/${o.number}`,
    author: {
      __typename: 'User',
      login: 'me',
      avatarUrl: 'https://avatars3.githubusercontent.com/u/000?v=4',
      id: 'user0'
    },
    createdAt: '2018-06-12T14:50:08Z',
    headRefName: o.headRefName,

    repository: {
      id: o.repositoryID,
    },

    commits,
  }
}

export function createPullRequestsResult(...attrs) {
  const idGen = IDGenerator.fromOpts({});
  const embed = idGen.embed();

  return attrs.map(attr => {
    return createPullRequestResult({...attr, ...embed});
  });
}

export function createPullRequestDetailResult(attrs = {}) {
  const idGen = IDGenerator.fromOpts(attrs);

  const o = {
    id: idGen.generate('pullrequest'),
    __typename: 'PullRequest',
    number: 0,
    title: 'title',
    state: 'OPEN',
    authorLogin: 'me',
    authorAvatarURL: 'https://avatars3.githubusercontent.com/u/000?v=4',
    headRefName: 'headref',
    headRepositoryName: 'headrepo',
    headRepositoryLogin: 'headlogin',
    baseRepositoryLogin: 'baseLogin',
    changedFileCount: 0,
    commitCount: 0,
    baseRefName: 'baseRefName',
    ...attrs,
  };

  const commit = {
    id: idGen.generate('commit'),
    status: null,
  };

  return {
    __typename: 'PullRequest',
    id: o.id,
    title: o.title,
    number: o.number,
    countedCommits: {
      totalCount: o.commitCount
    },
    changedFiles: o.changedFileCount,
    state: o.state,
    bodyHTML: '<p>body</p>',
    baseRefName: o.baseRefName,
    author: {
      __typename: 'User',
      id: idGen.generate('user'),
      login: o.authorLogin,
      avatarUrl: o.authorAvatarURL,
      url: `https://github.com/${o.authorLogin}`,
    },
    url: `https://github.com/owner/repo/pull/${o.number}`,
    reactionGroups: [],
    recentCommits: {
      edges: [{
        node: {commit, id: 'node0'}
      }],
    },
    timeline: {
      pageInfo: {
        endCursor: 'end',
        hasNextPage: false,
      },
      edges: [],
    },
    headRefName: o.headRefName,
    headRepository: {
      id: idGen.generate('repo'),
      name: o.headRepositoryName,
      owner: {
        __typename: 'User',
        id: idGen.generate('user'),
        login: o.headRepositoryLogin,
      },
      url: `https://github.com/${o.headRepositoryLogin}/${o.headRepositoryName}`,
      sshUrl: `git@github.com:${o.headRepositoryLogin}/${o.headRepositoryName}`,
    },
    headRepositoryOwner: {
      __typename: 'User',
      id: idGen.generate('user'),
      login: o.headRepositoryLogin,
    },
    repository: {
      owner: {
        __typename: 'User',
        id: idGen.generate('user'),
        login: o.baseRepositoryLogin,
      },
      id: idGen.generate('repository'),
    }
  };
}
