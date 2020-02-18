const {Toolkit} = require('actions-toolkit');
const {withDefaults} = require('actions-toolkit/lib/graphql');

Toolkit.run(async tools => {
  // Re-authenticate with the correct secret.
  tools.github.graphql = withDefaults(process.env.GRAPHQL_TOKEN);

  // Ensure that the actor of the triggering action belongs to the core team
  const actorLogin = tools.context.actor;
  const teamResponse = await tools.github.graphql(`
    query {
      organization(login: "atom") {
        team(slug: "github-package") {
          members(first: 100) {
            nodes {
              login
            }
          }
        }
      }
    }
  `);
  if (!teamResponse.organization.team.members.nodes.some(node => node.login === actorLogin)) {
    tools.exit.neutral('User %s is not in the github-package team. Thanks for your contribution!', actorLogin);
  }

  // Identify the active release board and its "In progress" column
  const projectQuery = await tools.github.graphql(`
    query {
      repository(owner: "atom", name: "github") {
        projects(
          search: "Release"
          states: [OPEN]
          first: 1
          orderBy: {field: CREATED_AT, direction: DESC}
        ) {
          nodes {
            id
            name

            columns(first: 10) {
              nodes {
                id
                name
              }
            }
          }
        }
      }
    }
  `);
  const project = projectQuery.repository.projects.nodes[0];
  if (!project) {
    tools.exit.failure('No open project found with a name matching "Release".');
  }
  const column = project.columns.nodes.find(node => node.name === 'In progress');
  if (!column) {
    tools.exit.failure('No column found in the project %s with a name of exactly "In progress".', project.name);
  }

  // Add the issue/pull request to the sprint board
  await tools.github.graphql(`
    mutation ProjectCardAddition($columnID: ID!, $issueishID: ID!) {
      addProjectCard(input: {projectColumnId: $columnID, contentId: $issueishID}) {
        clientMutationId
      }
    }
  `, {
    columnID: column.id,
    issueishID: tools.context.event === 'issues'
      ? tools.context.payload.issue.node_id
      : tools.context.payload.pull_request.node_id,
  });
  tools.exit.success('Added as a project card.');
}, {
  event: [
    'issues.assigned',
    'pull_request.opened',
    'pull_request.merged',
    'pull_request.assigned',
    'pull_request.reopened',
  ],
  secrets: ['GRAPHQL_TOKEN'],
});
