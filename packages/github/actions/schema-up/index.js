const path = require('path');

const {Toolkit} = require('actions-toolkit');
const fetchSchema = require('./fetch-schema');

const schemaUpdateLabel = {
  name: 'schema update',
  id: 'MDU6TGFiZWwxMzQyMzM1MjQ2',
};

Toolkit.run(async tools => {
  await tools.runInWorkspace('git', ['config', '--global', 'user.email', 'hubot@github.com']);
  await tools.runInWorkspace('git', ['config', '--global', 'user.name', 'hubot']);

  tools.log.info('Fetching the latest GraphQL schema changes.');
  await fetchSchema();

  const {code: hasSchemaChanges} = await tools.runInWorkspace(
    'git', ['diff', '--quiet', '--', 'graphql/schema.graphql'],
    {reject: false},
  );
  if (hasSchemaChanges === 0) {
    tools.log.info('No schema changes to fetch.');
    tools.exit.success('Nothing to do.');
  }

  tools.log.info('Checking for unmerged schema update pull requests.');
  const openPullRequestsQuery = await tools.github.graphql(`
    query openPullRequestsQuery($owner: String!, $repo: String!, $labelName: String!) {
      repository(owner: $owner, name: $repo) {
        id
        pullRequests(first: 1, states: [OPEN], labels: [$labelName]) {
          totalCount
        }
      }
    }
  `, {...tools.context.repo, labelName: schemaUpdateLabel.name});

  const repositoryId = openPullRequestsQuery.repository.id;

  if (openPullRequestsQuery.repository.pullRequests.totalCount > 0) {
    tools.exit.success('One or more schema update pull requests are already open. Please resolve those first.');
  }

  const branchName = `schema-update/${Date.now()}`;
  tools.log.info(`Creating a new branch ${branchName}.`);
  await tools.runInWorkspace('git', ['checkout', '-b', branchName]);

  tools.log.info('Committing schema changes.');
  await tools.runInWorkspace('git', ['commit', '--all', '--message', ':arrow_up: GraphQL schema']);

  tools.log.info('Re-running the Relay compiler.');
  const {failed: relayFailed, stdout: relayOutput} = await tools.runInWorkspace(
    path.resolve(__dirname, 'node_modules', '.bin', 'relay-compiler'),
    ['--watchman', 'false', '--src', './lib', '--schema', 'graphql/schema.graphql'],
    {reject: false},
  );
  tools.log.info('Relay output:\n%s', relayOutput);

  const {code: hasRelayChanges} = await tools.runInWorkspace(
    'git', ['diff', '--quiet'],
    {reject: false},
  );

  if (hasRelayChanges !== 0 && !relayFailed) {
    await tools.runInWorkspace('git', ['commit', '--all', '--message', ':gear: relay-compiler changes']);
  }

  const actor = process.env.GITHUB_ACTOR;
  const token = process.env.GITHUB_TOKEN;
  const repository = process.env.GITHUB_REPOSITORY;

  await tools.runInWorkspace('git', ['push', `https://${actor}:${token}@github.com/${repository}.git`, branchName]);

  tools.log.info('Creating a pull request.');

  let body = `:robot: _This automated pull request brought to you by [a GitHub action](https://github.com/atom/github/tree/master/actions/schema-up)_ :robot:

The GraphQL schema has been updated and \`relay-compiler\` has been re-run on the package source. `;

  if (!relayFailed) {
    if (hasRelayChanges !== 0) {
      body += 'The modified files have been committed to this branch and pushed. ';
      body += 'If all of the tests pass in CI, merge with confidence :zap:';
    } else {
      body += 'The new schema has been committed to this branch and pushed. None of the ';
      body += 'generated Relay source has changed as a result, so this should be a trivial merge :shipit: :rocket:';
    }
  } else {
    body += ' `relay-compiler` failed with the following output:\n\n```\n';
    body += relayOutput;
    body += '\n```\n\n:rotating_light: Check out this branch to fix things so we don\'t break. :rotating_light:';
  }

  const createPullRequestMutation = await tools.github.graphql(`
    mutation createPullRequestMutation($repositoryId: ID!, $headRefName: String!, $body: String!) {
      createPullRequest(input: {
        repositoryId: $repositoryId
        title: "GraphQL schema update"
        body: $body
        baseRefName: "master"
        headRefName: $headRefName
      }) {
        pullRequest {
          id
          number
        }
      }
    }
  `, {
    repositoryId,
    headRefName: branchName,
    body,
  });

  const createdPullRequest = createPullRequestMutation.createPullRequest.pullRequest;
  tools.log.info(
    `Pull request #${createdPullRequest.number} has been opened with the changes from this schema upgrade.`,
  );

  await tools.github.graphql(`
    mutation labelPullRequestMutation($id: ID!, $labelIDs: [ID!]!) {
      addLabelsToLabelable(input: {
        labelableId: $id,
        labelIds: $labelIDs
      }) {
        clientMutationId
      }
    }
  `, {id: createdPullRequest.id, labelIDs: [schemaUpdateLabel.id]});
  tools.exit.success(
    `Pull request #${createdPullRequest.number} has been opened and labelled for this schema upgrade.`,
  );
}, {
  secrets: ['GITHUB_TOKEN'],
});
