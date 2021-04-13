const { request } = require('@octokit/request');

const requestWithAuth = request.defaults({
  baseUrl: 'https://api.github.com',
  headers: {
    'user-agent': 'atom',
    authorization: `token ${process.env.AUTH_TOKEN}`
  },
  owner: 'atom',
  repo: 'atom'
});

module.exports = {
  createPR: async (
    { moduleName, isCorePackage, latest, installed },
    branch
  ) => {
    let description = `Bumps ${moduleName} from ${installed} to ${latest}`;
    if (isCorePackage) {
      description = `*List of changes between ${moduleName}@${installed} and ${moduleName}@${latest}: https://github.com/atom/${moduleName}/compare/v${installed}...v${latest}*`;
    }
    return requestWithAuth('POST /repos/:owner/:repo/pulls', {
      title: `⬆️ ${moduleName}@${latest}`,
      body: description,
      base: 'master',
      head: branch
    });
  },
  findPR: async ({ moduleName, latest }, branch) => {
    return requestWithAuth('GET /search/issues', {
      q: `${moduleName} type:pr ${moduleName}@${latest} in:title repo:atom/atom head:${branch}`
    });
  },
  findOpenPRs: async () => {
    return requestWithAuth('GET /search/issues', {
      q: 'type:pr repo:atom/atom state:open label:"depency ⬆️"'
    });
  },
  checkCIstatus: async ({ ref }) => {
    return requestWithAuth('GET /repos/:owner/:repo/commits/:ref/status', {
      ref
    });
  },
  mergePR: async ({ ref }) => {
    return requestWithAuth('POST /repos/{owner}/{repo}/merges', {
      base: 'master',
      head: ref
    });
  },
  addLabel: async pullRequestNumber => {
    return requestWithAuth('PATCH /repos/:owner/:repo/issues/:issue_number', {
      labels: ['depency ⬆️'],
      issue_number: pullRequestNumber
    });
  }
};
