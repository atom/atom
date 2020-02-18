/**
 * @flow
 * @relayHash a78ba6dc675389ea6933d328c4cca744
 */

/* eslint-disable */

'use strict';

/*::
import type { ConcreteRequest } from 'relay-runtime';
type prDetailView_pullRequest$ref = any;
type prDetailView_repository$ref = any;
export type prDetailViewRefetchQueryVariables = {|
  repoId: string,
  issueishId: string,
  timelineCount: number,
  timelineCursor?: ?string,
  commitCount: number,
  commitCursor?: ?string,
  checkSuiteCount: number,
  checkSuiteCursor?: ?string,
  checkRunCount: number,
  checkRunCursor?: ?string,
|};
export type prDetailViewRefetchQueryResponse = {|
  +repository: ?{|
    +$fragmentRefs: prDetailView_repository$ref
  |},
  +pullRequest: ?{|
    +$fragmentRefs: prDetailView_pullRequest$ref
  |},
|};
export type prDetailViewRefetchQuery = {|
  variables: prDetailViewRefetchQueryVariables,
  response: prDetailViewRefetchQueryResponse,
|};
*/


/*
query prDetailViewRefetchQuery(
  $repoId: ID!
  $issueishId: ID!
  $timelineCount: Int!
  $timelineCursor: String
  $commitCount: Int!
  $commitCursor: String
  $checkSuiteCount: Int!
  $checkSuiteCursor: String
  $checkRunCount: Int!
  $checkRunCursor: String
) {
  repository: node(id: $repoId) {
    __typename
    ...prDetailView_repository
    id
  }
  pullRequest: node(id: $issueishId) {
    __typename
    ...prDetailView_pullRequest_1UVrY8
    id
  }
}

fragment checkRunView_checkRun on CheckRun {
  name
  status
  conclusion
  title
  summary
  permalink
  detailsUrl
}

fragment checkRunsAccumulator_checkSuite_Rvfr1 on CheckSuite {
  id
  checkRuns(first: $checkRunCount, after: $checkRunCursor) {
    pageInfo {
      hasNextPage
      endCursor
    }
    edges {
      cursor
      node {
        id
        status
        conclusion
        ...checkRunView_checkRun
        __typename
      }
    }
  }
}

fragment checkSuiteView_checkSuite on CheckSuite {
  app {
    name
    id
  }
  status
  conclusion
}

fragment checkSuitesAccumulator_commit_1oGSNs on Commit {
  id
  checkSuites(first: $checkSuiteCount, after: $checkSuiteCursor) {
    pageInfo {
      hasNextPage
      endCursor
    }
    edges {
      cursor
      node {
        id
        status
        conclusion
        ...checkSuiteView_checkSuite
        ...checkRunsAccumulator_checkSuite_Rvfr1
        __typename
      }
    }
  }
}

fragment commitCommentThreadView_item on PullRequestCommitCommentThread {
  commit {
    oid
    id
  }
  comments(first: 100) {
    edges {
      node {
        id
        ...commitCommentView_item
      }
    }
  }
}

fragment commitCommentView_item on CommitComment {
  author {
    __typename
    login
    avatarUrl
    ... on Node {
      id
    }
  }
  commit {
    oid
    id
  }
  bodyHTML
  createdAt
  path
  position
}

fragment commitView_commit on Commit {
  author {
    name
    avatarUrl
    user {
      login
      id
    }
  }
  committer {
    name
    avatarUrl
    user {
      login
      id
    }
  }
  authoredByCommitter
  sha: oid
  message
  messageHeadlineHTML
  commitUrl
}

fragment commitsView_nodes on PullRequestCommit {
  commit {
    id
    author {
      name
      user {
        login
        id
      }
    }
    ...commitView_commit
  }
}

fragment crossReferencedEventView_item on CrossReferencedEvent {
  id
  isCrossRepository
  source {
    __typename
    ... on Issue {
      number
      title
      url
      issueState: state
    }
    ... on PullRequest {
      number
      title
      url
      prState: state
    }
    ... on RepositoryNode {
      repository {
        name
        isPrivate
        owner {
          __typename
          login
          id
        }
        id
      }
    }
    ... on Node {
      id
    }
  }
}

fragment crossReferencedEventsView_nodes on CrossReferencedEvent {
  id
  referencedAt
  isCrossRepository
  actor {
    __typename
    login
    avatarUrl
    ... on Node {
      id
    }
  }
  source {
    __typename
    ... on RepositoryNode {
      repository {
        name
        owner {
          __typename
          login
          id
        }
        id
      }
    }
    ... on Node {
      id
    }
  }
  ...crossReferencedEventView_item
}

fragment emojiReactionsController_reactable on Reactable {
  id
  ...emojiReactionsView_reactable
}

fragment emojiReactionsView_reactable on Reactable {
  id
  reactionGroups {
    content
    viewerHasReacted
    users {
      totalCount
    }
  }
  viewerCanReact
}

fragment headRefForcePushedEventView_issueish on PullRequest {
  headRefName
  headRepositoryOwner {
    __typename
    login
    id
  }
  repository {
    owner {
      __typename
      login
      id
    }
    id
  }
}

fragment headRefForcePushedEventView_item on HeadRefForcePushedEvent {
  actor {
    __typename
    avatarUrl
    login
    ... on Node {
      id
    }
  }
  beforeCommit {
    oid
    id
  }
  afterCommit {
    oid
    id
  }
  createdAt
}

fragment issueCommentView_item on IssueComment {
  author {
    __typename
    avatarUrl
    login
    ... on Node {
      id
    }
  }
  bodyHTML
  createdAt
  url
}

fragment mergedEventView_item on MergedEvent {
  actor {
    __typename
    avatarUrl
    login
    ... on Node {
      id
    }
  }
  commit {
    oid
    id
  }
  mergeRefName
  createdAt
}

fragment prCommitView_item on Commit {
  committer {
    avatarUrl
    name
    date
  }
  messageHeadline
  messageBody
  shortSha: abbreviatedOid
  sha: oid
  url
}

fragment prCommitsView_pullRequest_38TpXw on PullRequest {
  url
  commits(first: $commitCount, after: $commitCursor) {
    pageInfo {
      endCursor
      hasNextPage
    }
    edges {
      cursor
      node {
        commit {
          id
          ...prCommitView_item
        }
        id
        __typename
      }
    }
  }
}

fragment prDetailView_pullRequest_1UVrY8 on PullRequest {
  id
  __typename
  url
  isCrossRepository
  changedFiles
  state
  number
  title
  bodyHTML
  baseRefName
  headRefName
  countedCommits: commits {
    totalCount
  }
  author {
    __typename
    login
    avatarUrl
    url
    ... on Node {
      id
    }
  }
  ...prCommitsView_pullRequest_38TpXw
  ...prStatusesView_pullRequest_1oGSNs
  ...prTimelineController_pullRequest_3D8CP9
  ...emojiReactionsController_reactable
}

fragment prDetailView_repository on Repository {
  id
  name
  owner {
    __typename
    login
    id
  }
}

fragment prStatusContextView_context on StatusContext {
  context
  description
  state
  targetUrl
}

fragment prStatusesView_pullRequest_1oGSNs on PullRequest {
  id
  recentCommits: commits(last: 1) {
    edges {
      node {
        commit {
          status {
            state
            contexts {
              id
              state
              ...prStatusContextView_context
            }
            id
          }
          ...checkSuitesAccumulator_commit_1oGSNs
          id
        }
        id
      }
    }
  }
}

fragment prTimelineController_pullRequest_3D8CP9 on PullRequest {
  url
  ...headRefForcePushedEventView_issueish
  timelineItems(first: $timelineCount, after: $timelineCursor) {
    pageInfo {
      endCursor
      hasNextPage
    }
    edges {
      cursor
      node {
        __typename
        ...commitsView_nodes
        ...issueCommentView_item
        ...mergedEventView_item
        ...headRefForcePushedEventView_item
        ...commitCommentThreadView_item
        ...crossReferencedEventsView_nodes
        ... on Node {
          id
        }
      }
    }
  }
}
*/

const node/*: ConcreteRequest*/ = (function(){
var v0 = [
  {
    "kind": "LocalArgument",
    "name": "repoId",
    "type": "ID!",
    "defaultValue": null
  },
  {
    "kind": "LocalArgument",
    "name": "issueishId",
    "type": "ID!",
    "defaultValue": null
  },
  {
    "kind": "LocalArgument",
    "name": "timelineCount",
    "type": "Int!",
    "defaultValue": null
  },
  {
    "kind": "LocalArgument",
    "name": "timelineCursor",
    "type": "String",
    "defaultValue": null
  },
  {
    "kind": "LocalArgument",
    "name": "commitCount",
    "type": "Int!",
    "defaultValue": null
  },
  {
    "kind": "LocalArgument",
    "name": "commitCursor",
    "type": "String",
    "defaultValue": null
  },
  {
    "kind": "LocalArgument",
    "name": "checkSuiteCount",
    "type": "Int!",
    "defaultValue": null
  },
  {
    "kind": "LocalArgument",
    "name": "checkSuiteCursor",
    "type": "String",
    "defaultValue": null
  },
  {
    "kind": "LocalArgument",
    "name": "checkRunCount",
    "type": "Int!",
    "defaultValue": null
  },
  {
    "kind": "LocalArgument",
    "name": "checkRunCursor",
    "type": "String",
    "defaultValue": null
  }
],
v1 = [
  {
    "kind": "Variable",
    "name": "id",
    "variableName": "repoId"
  }
],
v2 = [
  {
    "kind": "Variable",
    "name": "id",
    "variableName": "issueishId"
  }
],
v3 = {
  "kind": "ScalarField",
  "alias": null,
  "name": "__typename",
  "args": null,
  "storageKey": null
},
v4 = {
  "kind": "ScalarField",
  "alias": null,
  "name": "id",
  "args": null,
  "storageKey": null
},
v5 = {
  "kind": "ScalarField",
  "alias": null,
  "name": "name",
  "args": null,
  "storageKey": null
},
v6 = {
  "kind": "ScalarField",
  "alias": null,
  "name": "login",
  "args": null,
  "storageKey": null
},
v7 = [
  (v3/*: any*/),
  (v6/*: any*/),
  (v4/*: any*/)
],
v8 = {
  "kind": "LinkedField",
  "alias": null,
  "name": "owner",
  "storageKey": null,
  "args": null,
  "concreteType": null,
  "plural": false,
  "selections": (v7/*: any*/)
},
v9 = {
  "kind": "ScalarField",
  "alias": null,
  "name": "url",
  "args": null,
  "storageKey": null
},
v10 = {
  "kind": "ScalarField",
  "alias": null,
  "name": "isCrossRepository",
  "args": null,
  "storageKey": null
},
v11 = {
  "kind": "ScalarField",
  "alias": null,
  "name": "state",
  "args": null,
  "storageKey": null
},
v12 = {
  "kind": "ScalarField",
  "alias": null,
  "name": "number",
  "args": null,
  "storageKey": null
},
v13 = {
  "kind": "ScalarField",
  "alias": null,
  "name": "title",
  "args": null,
  "storageKey": null
},
v14 = {
  "kind": "ScalarField",
  "alias": null,
  "name": "bodyHTML",
  "args": null,
  "storageKey": null
},
v15 = [
  {
    "kind": "ScalarField",
    "alias": null,
    "name": "totalCount",
    "args": null,
    "storageKey": null
  }
],
v16 = {
  "kind": "ScalarField",
  "alias": null,
  "name": "avatarUrl",
  "args": null,
  "storageKey": null
},
v17 = [
  {
    "kind": "Variable",
    "name": "after",
    "variableName": "commitCursor"
  },
  {
    "kind": "Variable",
    "name": "first",
    "variableName": "commitCount"
  }
],
v18 = {
  "kind": "ScalarField",
  "alias": null,
  "name": "endCursor",
  "args": null,
  "storageKey": null
},
v19 = {
  "kind": "ScalarField",
  "alias": null,
  "name": "hasNextPage",
  "args": null,
  "storageKey": null
},
v20 = {
  "kind": "LinkedField",
  "alias": null,
  "name": "pageInfo",
  "storageKey": null,
  "args": null,
  "concreteType": "PageInfo",
  "plural": false,
  "selections": [
    (v18/*: any*/),
    (v19/*: any*/)
  ]
},
v21 = {
  "kind": "ScalarField",
  "alias": null,
  "name": "cursor",
  "args": null,
  "storageKey": null
},
v22 = {
  "kind": "ScalarField",
  "alias": "sha",
  "name": "oid",
  "args": null,
  "storageKey": null
},
v23 = [
  {
    "kind": "Variable",
    "name": "after",
    "variableName": "checkSuiteCursor"
  },
  {
    "kind": "Variable",
    "name": "first",
    "variableName": "checkSuiteCount"
  }
],
v24 = {
  "kind": "LinkedField",
  "alias": null,
  "name": "pageInfo",
  "storageKey": null,
  "args": null,
  "concreteType": "PageInfo",
  "plural": false,
  "selections": [
    (v19/*: any*/),
    (v18/*: any*/)
  ]
},
v25 = {
  "kind": "ScalarField",
  "alias": null,
  "name": "status",
  "args": null,
  "storageKey": null
},
v26 = {
  "kind": "ScalarField",
  "alias": null,
  "name": "conclusion",
  "args": null,
  "storageKey": null
},
v27 = [
  {
    "kind": "Variable",
    "name": "after",
    "variableName": "checkRunCursor"
  },
  {
    "kind": "Variable",
    "name": "first",
    "variableName": "checkRunCount"
  }
],
v28 = [
  {
    "kind": "Variable",
    "name": "after",
    "variableName": "timelineCursor"
  },
  {
    "kind": "Variable",
    "name": "first",
    "variableName": "timelineCount"
  }
],
v29 = {
  "kind": "LinkedField",
  "alias": null,
  "name": "user",
  "storageKey": null,
  "args": null,
  "concreteType": "User",
  "plural": false,
  "selections": [
    (v6/*: any*/),
    (v4/*: any*/)
  ]
},
v30 = [
  (v3/*: any*/),
  (v16/*: any*/),
  (v6/*: any*/),
  (v4/*: any*/)
],
v31 = {
  "kind": "ScalarField",
  "alias": null,
  "name": "createdAt",
  "args": null,
  "storageKey": null
},
v32 = {
  "kind": "LinkedField",
  "alias": null,
  "name": "actor",
  "storageKey": null,
  "args": null,
  "concreteType": null,
  "plural": false,
  "selections": (v30/*: any*/)
},
v33 = [
  {
    "kind": "ScalarField",
    "alias": null,
    "name": "oid",
    "args": null,
    "storageKey": null
  },
  (v4/*: any*/)
],
v34 = {
  "kind": "LinkedField",
  "alias": null,
  "name": "commit",
  "storageKey": null,
  "args": null,
  "concreteType": "Commit",
  "plural": false,
  "selections": (v33/*: any*/)
},
v35 = [
  (v3/*: any*/),
  (v6/*: any*/),
  (v16/*: any*/),
  (v4/*: any*/)
];
return {
  "kind": "Request",
  "fragment": {
    "kind": "Fragment",
    "name": "prDetailViewRefetchQuery",
    "type": "Query",
    "metadata": null,
    "argumentDefinitions": (v0/*: any*/),
    "selections": [
      {
        "kind": "LinkedField",
        "alias": "repository",
        "name": "node",
        "storageKey": null,
        "args": (v1/*: any*/),
        "concreteType": null,
        "plural": false,
        "selections": [
          {
            "kind": "FragmentSpread",
            "name": "prDetailView_repository",
            "args": null
          }
        ]
      },
      {
        "kind": "LinkedField",
        "alias": "pullRequest",
        "name": "node",
        "storageKey": null,
        "args": (v2/*: any*/),
        "concreteType": null,
        "plural": false,
        "selections": [
          {
            "kind": "FragmentSpread",
            "name": "prDetailView_pullRequest",
            "args": [
              {
                "kind": "Variable",
                "name": "checkRunCount",
                "variableName": "checkRunCount"
              },
              {
                "kind": "Variable",
                "name": "checkRunCursor",
                "variableName": "checkRunCursor"
              },
              {
                "kind": "Variable",
                "name": "checkSuiteCount",
                "variableName": "checkSuiteCount"
              },
              {
                "kind": "Variable",
                "name": "checkSuiteCursor",
                "variableName": "checkSuiteCursor"
              },
              {
                "kind": "Variable",
                "name": "commitCount",
                "variableName": "commitCount"
              },
              {
                "kind": "Variable",
                "name": "commitCursor",
                "variableName": "commitCursor"
              },
              {
                "kind": "Variable",
                "name": "timelineCount",
                "variableName": "timelineCount"
              },
              {
                "kind": "Variable",
                "name": "timelineCursor",
                "variableName": "timelineCursor"
              }
            ]
          }
        ]
      }
    ]
  },
  "operation": {
    "kind": "Operation",
    "name": "prDetailViewRefetchQuery",
    "argumentDefinitions": (v0/*: any*/),
    "selections": [
      {
        "kind": "LinkedField",
        "alias": "repository",
        "name": "node",
        "storageKey": null,
        "args": (v1/*: any*/),
        "concreteType": null,
        "plural": false,
        "selections": [
          (v3/*: any*/),
          (v4/*: any*/),
          {
            "kind": "InlineFragment",
            "type": "Repository",
            "selections": [
              (v5/*: any*/),
              (v8/*: any*/)
            ]
          }
        ]
      },
      {
        "kind": "LinkedField",
        "alias": "pullRequest",
        "name": "node",
        "storageKey": null,
        "args": (v2/*: any*/),
        "concreteType": null,
        "plural": false,
        "selections": [
          (v3/*: any*/),
          (v4/*: any*/),
          {
            "kind": "InlineFragment",
            "type": "PullRequest",
            "selections": [
              (v3/*: any*/),
              (v9/*: any*/),
              (v10/*: any*/),
              {
                "kind": "ScalarField",
                "alias": null,
                "name": "changedFiles",
                "args": null,
                "storageKey": null
              },
              (v11/*: any*/),
              (v12/*: any*/),
              (v13/*: any*/),
              (v14/*: any*/),
              {
                "kind": "ScalarField",
                "alias": null,
                "name": "baseRefName",
                "args": null,
                "storageKey": null
              },
              {
                "kind": "ScalarField",
                "alias": null,
                "name": "headRefName",
                "args": null,
                "storageKey": null
              },
              {
                "kind": "LinkedField",
                "alias": "countedCommits",
                "name": "commits",
                "storageKey": null,
                "args": null,
                "concreteType": "PullRequestCommitConnection",
                "plural": false,
                "selections": (v15/*: any*/)
              },
              {
                "kind": "LinkedField",
                "alias": null,
                "name": "author",
                "storageKey": null,
                "args": null,
                "concreteType": null,
                "plural": false,
                "selections": [
                  (v3/*: any*/),
                  (v6/*: any*/),
                  (v16/*: any*/),
                  (v9/*: any*/),
                  (v4/*: any*/)
                ]
              },
              {
                "kind": "LinkedField",
                "alias": null,
                "name": "commits",
                "storageKey": null,
                "args": (v17/*: any*/),
                "concreteType": "PullRequestCommitConnection",
                "plural": false,
                "selections": [
                  (v20/*: any*/),
                  {
                    "kind": "LinkedField",
                    "alias": null,
                    "name": "edges",
                    "storageKey": null,
                    "args": null,
                    "concreteType": "PullRequestCommitEdge",
                    "plural": true,
                    "selections": [
                      (v21/*: any*/),
                      {
                        "kind": "LinkedField",
                        "alias": null,
                        "name": "node",
                        "storageKey": null,
                        "args": null,
                        "concreteType": "PullRequestCommit",
                        "plural": false,
                        "selections": [
                          {
                            "kind": "LinkedField",
                            "alias": null,
                            "name": "commit",
                            "storageKey": null,
                            "args": null,
                            "concreteType": "Commit",
                            "plural": false,
                            "selections": [
                              (v4/*: any*/),
                              {
                                "kind": "LinkedField",
                                "alias": null,
                                "name": "committer",
                                "storageKey": null,
                                "args": null,
                                "concreteType": "GitActor",
                                "plural": false,
                                "selections": [
                                  (v16/*: any*/),
                                  (v5/*: any*/),
                                  {
                                    "kind": "ScalarField",
                                    "alias": null,
                                    "name": "date",
                                    "args": null,
                                    "storageKey": null
                                  }
                                ]
                              },
                              {
                                "kind": "ScalarField",
                                "alias": null,
                                "name": "messageHeadline",
                                "args": null,
                                "storageKey": null
                              },
                              {
                                "kind": "ScalarField",
                                "alias": null,
                                "name": "messageBody",
                                "args": null,
                                "storageKey": null
                              },
                              {
                                "kind": "ScalarField",
                                "alias": "shortSha",
                                "name": "abbreviatedOid",
                                "args": null,
                                "storageKey": null
                              },
                              (v22/*: any*/),
                              (v9/*: any*/)
                            ]
                          },
                          (v4/*: any*/),
                          (v3/*: any*/)
                        ]
                      }
                    ]
                  }
                ]
              },
              {
                "kind": "LinkedHandle",
                "alias": null,
                "name": "commits",
                "args": (v17/*: any*/),
                "handle": "connection",
                "key": "prCommitsView_commits",
                "filters": null
              },
              {
                "kind": "LinkedField",
                "alias": "recentCommits",
                "name": "commits",
                "storageKey": "commits(last:1)",
                "args": [
                  {
                    "kind": "Literal",
                    "name": "last",
                    "value": 1
                  }
                ],
                "concreteType": "PullRequestCommitConnection",
                "plural": false,
                "selections": [
                  {
                    "kind": "LinkedField",
                    "alias": null,
                    "name": "edges",
                    "storageKey": null,
                    "args": null,
                    "concreteType": "PullRequestCommitEdge",
                    "plural": true,
                    "selections": [
                      {
                        "kind": "LinkedField",
                        "alias": null,
                        "name": "node",
                        "storageKey": null,
                        "args": null,
                        "concreteType": "PullRequestCommit",
                        "plural": false,
                        "selections": [
                          {
                            "kind": "LinkedField",
                            "alias": null,
                            "name": "commit",
                            "storageKey": null,
                            "args": null,
                            "concreteType": "Commit",
                            "plural": false,
                            "selections": [
                              {
                                "kind": "LinkedField",
                                "alias": null,
                                "name": "status",
                                "storageKey": null,
                                "args": null,
                                "concreteType": "Status",
                                "plural": false,
                                "selections": [
                                  (v11/*: any*/),
                                  {
                                    "kind": "LinkedField",
                                    "alias": null,
                                    "name": "contexts",
                                    "storageKey": null,
                                    "args": null,
                                    "concreteType": "StatusContext",
                                    "plural": true,
                                    "selections": [
                                      (v4/*: any*/),
                                      (v11/*: any*/),
                                      {
                                        "kind": "ScalarField",
                                        "alias": null,
                                        "name": "context",
                                        "args": null,
                                        "storageKey": null
                                      },
                                      {
                                        "kind": "ScalarField",
                                        "alias": null,
                                        "name": "description",
                                        "args": null,
                                        "storageKey": null
                                      },
                                      {
                                        "kind": "ScalarField",
                                        "alias": null,
                                        "name": "targetUrl",
                                        "args": null,
                                        "storageKey": null
                                      }
                                    ]
                                  },
                                  (v4/*: any*/)
                                ]
                              },
                              (v4/*: any*/),
                              {
                                "kind": "LinkedField",
                                "alias": null,
                                "name": "checkSuites",
                                "storageKey": null,
                                "args": (v23/*: any*/),
                                "concreteType": "CheckSuiteConnection",
                                "plural": false,
                                "selections": [
                                  (v24/*: any*/),
                                  {
                                    "kind": "LinkedField",
                                    "alias": null,
                                    "name": "edges",
                                    "storageKey": null,
                                    "args": null,
                                    "concreteType": "CheckSuiteEdge",
                                    "plural": true,
                                    "selections": [
                                      (v21/*: any*/),
                                      {
                                        "kind": "LinkedField",
                                        "alias": null,
                                        "name": "node",
                                        "storageKey": null,
                                        "args": null,
                                        "concreteType": "CheckSuite",
                                        "plural": false,
                                        "selections": [
                                          (v4/*: any*/),
                                          (v25/*: any*/),
                                          (v26/*: any*/),
                                          {
                                            "kind": "LinkedField",
                                            "alias": null,
                                            "name": "app",
                                            "storageKey": null,
                                            "args": null,
                                            "concreteType": "App",
                                            "plural": false,
                                            "selections": [
                                              (v5/*: any*/),
                                              (v4/*: any*/)
                                            ]
                                          },
                                          {
                                            "kind": "LinkedField",
                                            "alias": null,
                                            "name": "checkRuns",
                                            "storageKey": null,
                                            "args": (v27/*: any*/),
                                            "concreteType": "CheckRunConnection",
                                            "plural": false,
                                            "selections": [
                                              (v24/*: any*/),
                                              {
                                                "kind": "LinkedField",
                                                "alias": null,
                                                "name": "edges",
                                                "storageKey": null,
                                                "args": null,
                                                "concreteType": "CheckRunEdge",
                                                "plural": true,
                                                "selections": [
                                                  (v21/*: any*/),
                                                  {
                                                    "kind": "LinkedField",
                                                    "alias": null,
                                                    "name": "node",
                                                    "storageKey": null,
                                                    "args": null,
                                                    "concreteType": "CheckRun",
                                                    "plural": false,
                                                    "selections": [
                                                      (v4/*: any*/),
                                                      (v25/*: any*/),
                                                      (v26/*: any*/),
                                                      (v5/*: any*/),
                                                      (v13/*: any*/),
                                                      {
                                                        "kind": "ScalarField",
                                                        "alias": null,
                                                        "name": "summary",
                                                        "args": null,
                                                        "storageKey": null
                                                      },
                                                      {
                                                        "kind": "ScalarField",
                                                        "alias": null,
                                                        "name": "permalink",
                                                        "args": null,
                                                        "storageKey": null
                                                      },
                                                      {
                                                        "kind": "ScalarField",
                                                        "alias": null,
                                                        "name": "detailsUrl",
                                                        "args": null,
                                                        "storageKey": null
                                                      },
                                                      (v3/*: any*/)
                                                    ]
                                                  }
                                                ]
                                              }
                                            ]
                                          },
                                          {
                                            "kind": "LinkedHandle",
                                            "alias": null,
                                            "name": "checkRuns",
                                            "args": (v27/*: any*/),
                                            "handle": "connection",
                                            "key": "CheckRunsAccumulator_checkRuns",
                                            "filters": null
                                          },
                                          (v3/*: any*/)
                                        ]
                                      }
                                    ]
                                  }
                                ]
                              },
                              {
                                "kind": "LinkedHandle",
                                "alias": null,
                                "name": "checkSuites",
                                "args": (v23/*: any*/),
                                "handle": "connection",
                                "key": "CheckSuiteAccumulator_checkSuites",
                                "filters": null
                              }
                            ]
                          },
                          (v4/*: any*/)
                        ]
                      }
                    ]
                  }
                ]
              },
              {
                "kind": "LinkedField",
                "alias": null,
                "name": "headRepositoryOwner",
                "storageKey": null,
                "args": null,
                "concreteType": null,
                "plural": false,
                "selections": (v7/*: any*/)
              },
              {
                "kind": "LinkedField",
                "alias": null,
                "name": "repository",
                "storageKey": null,
                "args": null,
                "concreteType": "Repository",
                "plural": false,
                "selections": [
                  (v8/*: any*/),
                  (v4/*: any*/)
                ]
              },
              {
                "kind": "LinkedField",
                "alias": null,
                "name": "timelineItems",
                "storageKey": null,
                "args": (v28/*: any*/),
                "concreteType": "PullRequestTimelineItemsConnection",
                "plural": false,
                "selections": [
                  (v20/*: any*/),
                  {
                    "kind": "LinkedField",
                    "alias": null,
                    "name": "edges",
                    "storageKey": null,
                    "args": null,
                    "concreteType": "PullRequestTimelineItemsEdge",
                    "plural": true,
                    "selections": [
                      (v21/*: any*/),
                      {
                        "kind": "LinkedField",
                        "alias": null,
                        "name": "node",
                        "storageKey": null,
                        "args": null,
                        "concreteType": null,
                        "plural": false,
                        "selections": [
                          (v3/*: any*/),
                          (v4/*: any*/),
                          {
                            "kind": "InlineFragment",
                            "type": "PullRequestCommit",
                            "selections": [
                              {
                                "kind": "LinkedField",
                                "alias": null,
                                "name": "commit",
                                "storageKey": null,
                                "args": null,
                                "concreteType": "Commit",
                                "plural": false,
                                "selections": [
                                  (v4/*: any*/),
                                  {
                                    "kind": "LinkedField",
                                    "alias": null,
                                    "name": "author",
                                    "storageKey": null,
                                    "args": null,
                                    "concreteType": "GitActor",
                                    "plural": false,
                                    "selections": [
                                      (v5/*: any*/),
                                      (v29/*: any*/),
                                      (v16/*: any*/)
                                    ]
                                  },
                                  {
                                    "kind": "LinkedField",
                                    "alias": null,
                                    "name": "committer",
                                    "storageKey": null,
                                    "args": null,
                                    "concreteType": "GitActor",
                                    "plural": false,
                                    "selections": [
                                      (v5/*: any*/),
                                      (v16/*: any*/),
                                      (v29/*: any*/)
                                    ]
                                  },
                                  {
                                    "kind": "ScalarField",
                                    "alias": null,
                                    "name": "authoredByCommitter",
                                    "args": null,
                                    "storageKey": null
                                  },
                                  (v22/*: any*/),
                                  {
                                    "kind": "ScalarField",
                                    "alias": null,
                                    "name": "message",
                                    "args": null,
                                    "storageKey": null
                                  },
                                  {
                                    "kind": "ScalarField",
                                    "alias": null,
                                    "name": "messageHeadlineHTML",
                                    "args": null,
                                    "storageKey": null
                                  },
                                  {
                                    "kind": "ScalarField",
                                    "alias": null,
                                    "name": "commitUrl",
                                    "args": null,
                                    "storageKey": null
                                  }
                                ]
                              }
                            ]
                          },
                          {
                            "kind": "InlineFragment",
                            "type": "IssueComment",
                            "selections": [
                              {
                                "kind": "LinkedField",
                                "alias": null,
                                "name": "author",
                                "storageKey": null,
                                "args": null,
                                "concreteType": null,
                                "plural": false,
                                "selections": (v30/*: any*/)
                              },
                              (v14/*: any*/),
                              (v31/*: any*/),
                              (v9/*: any*/)
                            ]
                          },
                          {
                            "kind": "InlineFragment",
                            "type": "MergedEvent",
                            "selections": [
                              (v32/*: any*/),
                              (v34/*: any*/),
                              {
                                "kind": "ScalarField",
                                "alias": null,
                                "name": "mergeRefName",
                                "args": null,
                                "storageKey": null
                              },
                              (v31/*: any*/)
                            ]
                          },
                          {
                            "kind": "InlineFragment",
                            "type": "HeadRefForcePushedEvent",
                            "selections": [
                              (v32/*: any*/),
                              {
                                "kind": "LinkedField",
                                "alias": null,
                                "name": "beforeCommit",
                                "storageKey": null,
                                "args": null,
                                "concreteType": "Commit",
                                "plural": false,
                                "selections": (v33/*: any*/)
                              },
                              {
                                "kind": "LinkedField",
                                "alias": null,
                                "name": "afterCommit",
                                "storageKey": null,
                                "args": null,
                                "concreteType": "Commit",
                                "plural": false,
                                "selections": (v33/*: any*/)
                              },
                              (v31/*: any*/)
                            ]
                          },
                          {
                            "kind": "InlineFragment",
                            "type": "PullRequestCommitCommentThread",
                            "selections": [
                              (v34/*: any*/),
                              {
                                "kind": "LinkedField",
                                "alias": null,
                                "name": "comments",
                                "storageKey": "comments(first:100)",
                                "args": [
                                  {
                                    "kind": "Literal",
                                    "name": "first",
                                    "value": 100
                                  }
                                ],
                                "concreteType": "CommitCommentConnection",
                                "plural": false,
                                "selections": [
                                  {
                                    "kind": "LinkedField",
                                    "alias": null,
                                    "name": "edges",
                                    "storageKey": null,
                                    "args": null,
                                    "concreteType": "CommitCommentEdge",
                                    "plural": true,
                                    "selections": [
                                      {
                                        "kind": "LinkedField",
                                        "alias": null,
                                        "name": "node",
                                        "storageKey": null,
                                        "args": null,
                                        "concreteType": "CommitComment",
                                        "plural": false,
                                        "selections": [
                                          (v4/*: any*/),
                                          {
                                            "kind": "LinkedField",
                                            "alias": null,
                                            "name": "author",
                                            "storageKey": null,
                                            "args": null,
                                            "concreteType": null,
                                            "plural": false,
                                            "selections": (v35/*: any*/)
                                          },
                                          (v34/*: any*/),
                                          (v14/*: any*/),
                                          (v31/*: any*/),
                                          {
                                            "kind": "ScalarField",
                                            "alias": null,
                                            "name": "path",
                                            "args": null,
                                            "storageKey": null
                                          },
                                          {
                                            "kind": "ScalarField",
                                            "alias": null,
                                            "name": "position",
                                            "args": null,
                                            "storageKey": null
                                          }
                                        ]
                                      }
                                    ]
                                  }
                                ]
                              }
                            ]
                          },
                          {
                            "kind": "InlineFragment",
                            "type": "CrossReferencedEvent",
                            "selections": [
                              {
                                "kind": "ScalarField",
                                "alias": null,
                                "name": "referencedAt",
                                "args": null,
                                "storageKey": null
                              },
                              (v10/*: any*/),
                              {
                                "kind": "LinkedField",
                                "alias": null,
                                "name": "actor",
                                "storageKey": null,
                                "args": null,
                                "concreteType": null,
                                "plural": false,
                                "selections": (v35/*: any*/)
                              },
                              {
                                "kind": "LinkedField",
                                "alias": null,
                                "name": "source",
                                "storageKey": null,
                                "args": null,
                                "concreteType": null,
                                "plural": false,
                                "selections": [
                                  (v3/*: any*/),
                                  {
                                    "kind": "LinkedField",
                                    "alias": null,
                                    "name": "repository",
                                    "storageKey": null,
                                    "args": null,
                                    "concreteType": "Repository",
                                    "plural": false,
                                    "selections": [
                                      (v5/*: any*/),
                                      (v8/*: any*/),
                                      (v4/*: any*/),
                                      {
                                        "kind": "ScalarField",
                                        "alias": null,
                                        "name": "isPrivate",
                                        "args": null,
                                        "storageKey": null
                                      }
                                    ]
                                  },
                                  (v4/*: any*/),
                                  {
                                    "kind": "InlineFragment",
                                    "type": "Issue",
                                    "selections": [
                                      (v12/*: any*/),
                                      (v13/*: any*/),
                                      (v9/*: any*/),
                                      {
                                        "kind": "ScalarField",
                                        "alias": "issueState",
                                        "name": "state",
                                        "args": null,
                                        "storageKey": null
                                      }
                                    ]
                                  },
                                  {
                                    "kind": "InlineFragment",
                                    "type": "PullRequest",
                                    "selections": [
                                      (v12/*: any*/),
                                      (v13/*: any*/),
                                      (v9/*: any*/),
                                      {
                                        "kind": "ScalarField",
                                        "alias": "prState",
                                        "name": "state",
                                        "args": null,
                                        "storageKey": null
                                      }
                                    ]
                                  }
                                ]
                              }
                            ]
                          }
                        ]
                      }
                    ]
                  }
                ]
              },
              {
                "kind": "LinkedHandle",
                "alias": null,
                "name": "timelineItems",
                "args": (v28/*: any*/),
                "handle": "connection",
                "key": "prTimelineContainer_timelineItems",
                "filters": null
              },
              {
                "kind": "LinkedField",
                "alias": null,
                "name": "reactionGroups",
                "storageKey": null,
                "args": null,
                "concreteType": "ReactionGroup",
                "plural": true,
                "selections": [
                  {
                    "kind": "ScalarField",
                    "alias": null,
                    "name": "content",
                    "args": null,
                    "storageKey": null
                  },
                  {
                    "kind": "ScalarField",
                    "alias": null,
                    "name": "viewerHasReacted",
                    "args": null,
                    "storageKey": null
                  },
                  {
                    "kind": "LinkedField",
                    "alias": null,
                    "name": "users",
                    "storageKey": null,
                    "args": null,
                    "concreteType": "ReactingUserConnection",
                    "plural": false,
                    "selections": (v15/*: any*/)
                  }
                ]
              },
              {
                "kind": "ScalarField",
                "alias": null,
                "name": "viewerCanReact",
                "args": null,
                "storageKey": null
              }
            ]
          }
        ]
      }
    ]
  },
  "params": {
    "operationKind": "query",
    "name": "prDetailViewRefetchQuery",
    "id": null,
    "text": "query prDetailViewRefetchQuery(\n  $repoId: ID!\n  $issueishId: ID!\n  $timelineCount: Int!\n  $timelineCursor: String\n  $commitCount: Int!\n  $commitCursor: String\n  $checkSuiteCount: Int!\n  $checkSuiteCursor: String\n  $checkRunCount: Int!\n  $checkRunCursor: String\n) {\n  repository: node(id: $repoId) {\n    __typename\n    ...prDetailView_repository\n    id\n  }\n  pullRequest: node(id: $issueishId) {\n    __typename\n    ...prDetailView_pullRequest_1UVrY8\n    id\n  }\n}\n\nfragment checkRunView_checkRun on CheckRun {\n  name\n  status\n  conclusion\n  title\n  summary\n  permalink\n  detailsUrl\n}\n\nfragment checkRunsAccumulator_checkSuite_Rvfr1 on CheckSuite {\n  id\n  checkRuns(first: $checkRunCount, after: $checkRunCursor) {\n    pageInfo {\n      hasNextPage\n      endCursor\n    }\n    edges {\n      cursor\n      node {\n        id\n        status\n        conclusion\n        ...checkRunView_checkRun\n        __typename\n      }\n    }\n  }\n}\n\nfragment checkSuiteView_checkSuite on CheckSuite {\n  app {\n    name\n    id\n  }\n  status\n  conclusion\n}\n\nfragment checkSuitesAccumulator_commit_1oGSNs on Commit {\n  id\n  checkSuites(first: $checkSuiteCount, after: $checkSuiteCursor) {\n    pageInfo {\n      hasNextPage\n      endCursor\n    }\n    edges {\n      cursor\n      node {\n        id\n        status\n        conclusion\n        ...checkSuiteView_checkSuite\n        ...checkRunsAccumulator_checkSuite_Rvfr1\n        __typename\n      }\n    }\n  }\n}\n\nfragment commitCommentThreadView_item on PullRequestCommitCommentThread {\n  commit {\n    oid\n    id\n  }\n  comments(first: 100) {\n    edges {\n      node {\n        id\n        ...commitCommentView_item\n      }\n    }\n  }\n}\n\nfragment commitCommentView_item on CommitComment {\n  author {\n    __typename\n    login\n    avatarUrl\n    ... on Node {\n      id\n    }\n  }\n  commit {\n    oid\n    id\n  }\n  bodyHTML\n  createdAt\n  path\n  position\n}\n\nfragment commitView_commit on Commit {\n  author {\n    name\n    avatarUrl\n    user {\n      login\n      id\n    }\n  }\n  committer {\n    name\n    avatarUrl\n    user {\n      login\n      id\n    }\n  }\n  authoredByCommitter\n  sha: oid\n  message\n  messageHeadlineHTML\n  commitUrl\n}\n\nfragment commitsView_nodes on PullRequestCommit {\n  commit {\n    id\n    author {\n      name\n      user {\n        login\n        id\n      }\n    }\n    ...commitView_commit\n  }\n}\n\nfragment crossReferencedEventView_item on CrossReferencedEvent {\n  id\n  isCrossRepository\n  source {\n    __typename\n    ... on Issue {\n      number\n      title\n      url\n      issueState: state\n    }\n    ... on PullRequest {\n      number\n      title\n      url\n      prState: state\n    }\n    ... on RepositoryNode {\n      repository {\n        name\n        isPrivate\n        owner {\n          __typename\n          login\n          id\n        }\n        id\n      }\n    }\n    ... on Node {\n      id\n    }\n  }\n}\n\nfragment crossReferencedEventsView_nodes on CrossReferencedEvent {\n  id\n  referencedAt\n  isCrossRepository\n  actor {\n    __typename\n    login\n    avatarUrl\n    ... on Node {\n      id\n    }\n  }\n  source {\n    __typename\n    ... on RepositoryNode {\n      repository {\n        name\n        owner {\n          __typename\n          login\n          id\n        }\n        id\n      }\n    }\n    ... on Node {\n      id\n    }\n  }\n  ...crossReferencedEventView_item\n}\n\nfragment emojiReactionsController_reactable on Reactable {\n  id\n  ...emojiReactionsView_reactable\n}\n\nfragment emojiReactionsView_reactable on Reactable {\n  id\n  reactionGroups {\n    content\n    viewerHasReacted\n    users {\n      totalCount\n    }\n  }\n  viewerCanReact\n}\n\nfragment headRefForcePushedEventView_issueish on PullRequest {\n  headRefName\n  headRepositoryOwner {\n    __typename\n    login\n    id\n  }\n  repository {\n    owner {\n      __typename\n      login\n      id\n    }\n    id\n  }\n}\n\nfragment headRefForcePushedEventView_item on HeadRefForcePushedEvent {\n  actor {\n    __typename\n    avatarUrl\n    login\n    ... on Node {\n      id\n    }\n  }\n  beforeCommit {\n    oid\n    id\n  }\n  afterCommit {\n    oid\n    id\n  }\n  createdAt\n}\n\nfragment issueCommentView_item on IssueComment {\n  author {\n    __typename\n    avatarUrl\n    login\n    ... on Node {\n      id\n    }\n  }\n  bodyHTML\n  createdAt\n  url\n}\n\nfragment mergedEventView_item on MergedEvent {\n  actor {\n    __typename\n    avatarUrl\n    login\n    ... on Node {\n      id\n    }\n  }\n  commit {\n    oid\n    id\n  }\n  mergeRefName\n  createdAt\n}\n\nfragment prCommitView_item on Commit {\n  committer {\n    avatarUrl\n    name\n    date\n  }\n  messageHeadline\n  messageBody\n  shortSha: abbreviatedOid\n  sha: oid\n  url\n}\n\nfragment prCommitsView_pullRequest_38TpXw on PullRequest {\n  url\n  commits(first: $commitCount, after: $commitCursor) {\n    pageInfo {\n      endCursor\n      hasNextPage\n    }\n    edges {\n      cursor\n      node {\n        commit {\n          id\n          ...prCommitView_item\n        }\n        id\n        __typename\n      }\n    }\n  }\n}\n\nfragment prDetailView_pullRequest_1UVrY8 on PullRequest {\n  id\n  __typename\n  url\n  isCrossRepository\n  changedFiles\n  state\n  number\n  title\n  bodyHTML\n  baseRefName\n  headRefName\n  countedCommits: commits {\n    totalCount\n  }\n  author {\n    __typename\n    login\n    avatarUrl\n    url\n    ... on Node {\n      id\n    }\n  }\n  ...prCommitsView_pullRequest_38TpXw\n  ...prStatusesView_pullRequest_1oGSNs\n  ...prTimelineController_pullRequest_3D8CP9\n  ...emojiReactionsController_reactable\n}\n\nfragment prDetailView_repository on Repository {\n  id\n  name\n  owner {\n    __typename\n    login\n    id\n  }\n}\n\nfragment prStatusContextView_context on StatusContext {\n  context\n  description\n  state\n  targetUrl\n}\n\nfragment prStatusesView_pullRequest_1oGSNs on PullRequest {\n  id\n  recentCommits: commits(last: 1) {\n    edges {\n      node {\n        commit {\n          status {\n            state\n            contexts {\n              id\n              state\n              ...prStatusContextView_context\n            }\n            id\n          }\n          ...checkSuitesAccumulator_commit_1oGSNs\n          id\n        }\n        id\n      }\n    }\n  }\n}\n\nfragment prTimelineController_pullRequest_3D8CP9 on PullRequest {\n  url\n  ...headRefForcePushedEventView_issueish\n  timelineItems(first: $timelineCount, after: $timelineCursor) {\n    pageInfo {\n      endCursor\n      hasNextPage\n    }\n    edges {\n      cursor\n      node {\n        __typename\n        ...commitsView_nodes\n        ...issueCommentView_item\n        ...mergedEventView_item\n        ...headRefForcePushedEventView_item\n        ...commitCommentThreadView_item\n        ...crossReferencedEventsView_nodes\n        ... on Node {\n          id\n        }\n      }\n    }\n  }\n}\n",
    "metadata": {}
  }
};
})();
// prettier-ignore
(node/*: any*/).hash = 'a997586597e1b33bb527359554fb7415';
module.exports = node;
