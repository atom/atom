/**
 * @flow
 * @relayHash 85e978dc2d00ae09ae543bf716b313c9
 */

/* eslint-disable */

'use strict';

/*::
import type { ConcreteRequest } from 'relay-runtime';
type aggregatedReviewsContainer_pullRequest$ref = any;
type issueishDetailController_repository$ref = any;
export type issueishDetailContainerQueryVariables = {|
  repoOwner: string,
  repoName: string,
  issueishNumber: number,
  timelineCount: number,
  timelineCursor?: ?string,
  commitCount: number,
  commitCursor?: ?string,
  reviewCount: number,
  reviewCursor?: ?string,
  threadCount: number,
  threadCursor?: ?string,
  commentCount: number,
  commentCursor?: ?string,
  checkSuiteCount: number,
  checkSuiteCursor?: ?string,
  checkRunCount: number,
  checkRunCursor?: ?string,
|};
export type issueishDetailContainerQueryResponse = {|
  +repository: ?{|
    +issueish: ?({|
      +__typename: "PullRequest",
      +$fragmentRefs: aggregatedReviewsContainer_pullRequest$ref,
    |} | {|
      // This will never be '%other', but we need some
      // value in case none of the concrete values match.
      +__typename: "%other"
    |}),
    +$fragmentRefs: issueishDetailController_repository$ref,
  |}
|};
export type issueishDetailContainerQuery = {|
  variables: issueishDetailContainerQueryVariables,
  response: issueishDetailContainerQueryResponse,
|};
*/


/*
query issueishDetailContainerQuery(
  $repoOwner: String!
  $repoName: String!
  $issueishNumber: Int!
  $timelineCount: Int!
  $timelineCursor: String
  $commitCount: Int!
  $commitCursor: String
  $reviewCount: Int!
  $reviewCursor: String
  $threadCount: Int!
  $threadCursor: String
  $commentCount: Int!
  $commentCursor: String
  $checkSuiteCount: Int!
  $checkSuiteCursor: String
  $checkRunCount: Int!
  $checkRunCursor: String
) {
  repository(owner: $repoOwner, name: $repoName) {
    issueish: issueOrPullRequest(number: $issueishNumber) {
      __typename
      ... on PullRequest {
        ...aggregatedReviewsContainer_pullRequest_qdneZ
      }
      ... on Node {
        id
      }
    }
    ...issueishDetailController_repository_3iQpNL
    id
  }
}

fragment aggregatedReviewsContainer_pullRequest_qdneZ on PullRequest {
  id
  ...reviewSummariesAccumulator_pullRequest_2zzc96
  ...reviewThreadsAccumulator_pullRequest_CKDvj
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

fragment issueDetailView_issue_3D8CP9 on Issue {
  id
  __typename
  url
  state
  number
  title
  bodyHTML
  author {
    __typename
    login
    avatarUrl
    url
    ... on Node {
      id
    }
  }
  ...issueTimelineController_issue_3D8CP9
  ...emojiReactionsView_reactable
}

fragment issueDetailView_repository on Repository {
  id
  name
  owner {
    __typename
    login
    id
  }
}

fragment issueTimelineController_issue_3D8CP9 on Issue {
  url
  timelineItems(first: $timelineCount, after: $timelineCursor) {
    pageInfo {
      endCursor
      hasNextPage
    }
    edges {
      cursor
      node {
        __typename
        ...issueCommentView_item
        ...crossReferencedEventsView_nodes
        ... on Node {
          id
        }
      }
    }
  }
}

fragment issueishDetailController_repository_3iQpNL on Repository {
  ...issueDetailView_repository
  ...prCheckoutController_repository
  ...prDetailView_repository
  name
  owner {
    __typename
    login
    id
  }
  issue: issueOrPullRequest(number: $issueishNumber) {
    __typename
    ... on Issue {
      title
      number
      ...issueDetailView_issue_3D8CP9
    }
    ... on Node {
      id
    }
  }
  pullRequest: issueOrPullRequest(number: $issueishNumber) {
    __typename
    ... on PullRequest {
      title
      number
      ...prCheckoutController_pullRequest
      ...prDetailView_pullRequest_1UVrY8
    }
    ... on Node {
      id
    }
  }
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

fragment prCheckoutController_pullRequest on PullRequest {
  number
  headRefName
  headRepository {
    name
    url
    sshUrl
    owner {
      __typename
      login
      id
    }
    id
  }
}

fragment prCheckoutController_repository on Repository {
  name
  owner {
    __typename
    login
    id
  }
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

fragment reviewCommentsAccumulator_reviewThread_1VbUmL on PullRequestReviewThread {
  id
  comments(first: $commentCount, after: $commentCursor) {
    pageInfo {
      hasNextPage
      endCursor
    }
    edges {
      cursor
      node {
        id
        author {
          __typename
          avatarUrl
          login
          url
          ... on Node {
            id
          }
        }
        bodyHTML
        body
        isMinimized
        state
        viewerCanReact
        viewerCanUpdate
        path
        position
        createdAt
        lastEditedAt
        url
        authorAssociation
        ...emojiReactionsController_reactable
        __typename
      }
    }
  }
}

fragment reviewSummariesAccumulator_pullRequest_2zzc96 on PullRequest {
  url
  reviews(first: $reviewCount, after: $reviewCursor) {
    pageInfo {
      hasNextPage
      endCursor
    }
    edges {
      cursor
      node {
        id
        body
        bodyHTML
        state
        submittedAt
        lastEditedAt
        url
        author {
          __typename
          login
          avatarUrl
          url
          ... on Node {
            id
          }
        }
        viewerCanUpdate
        authorAssociation
        ...emojiReactionsController_reactable
        __typename
      }
    }
  }
}

fragment reviewThreadsAccumulator_pullRequest_CKDvj on PullRequest {
  url
  reviewThreads(first: $threadCount, after: $threadCursor) {
    pageInfo {
      hasNextPage
      endCursor
    }
    edges {
      cursor
      node {
        id
        isResolved
        resolvedBy {
          login
          id
        }
        viewerCanResolve
        viewerCanUnresolve
        ...reviewCommentsAccumulator_reviewThread_1VbUmL
        __typename
      }
    }
  }
}
*/

const node/*: ConcreteRequest*/ = (function(){
var v0 = [
  {
    "kind": "LocalArgument",
    "name": "repoOwner",
    "type": "String!",
    "defaultValue": null
  },
  {
    "kind": "LocalArgument",
    "name": "repoName",
    "type": "String!",
    "defaultValue": null
  },
  {
    "kind": "LocalArgument",
    "name": "issueishNumber",
    "type": "Int!",
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
    "name": "reviewCount",
    "type": "Int!",
    "defaultValue": null
  },
  {
    "kind": "LocalArgument",
    "name": "reviewCursor",
    "type": "String",
    "defaultValue": null
  },
  {
    "kind": "LocalArgument",
    "name": "threadCount",
    "type": "Int!",
    "defaultValue": null
  },
  {
    "kind": "LocalArgument",
    "name": "threadCursor",
    "type": "String",
    "defaultValue": null
  },
  {
    "kind": "LocalArgument",
    "name": "commentCount",
    "type": "Int!",
    "defaultValue": null
  },
  {
    "kind": "LocalArgument",
    "name": "commentCursor",
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
    "name": "name",
    "variableName": "repoName"
  },
  {
    "kind": "Variable",
    "name": "owner",
    "variableName": "repoOwner"
  }
],
v2 = [
  {
    "kind": "Variable",
    "name": "number",
    "variableName": "issueishNumber"
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
  "name": "url",
  "args": null,
  "storageKey": null
},
v6 = [
  {
    "kind": "Variable",
    "name": "after",
    "variableName": "reviewCursor"
  },
  {
    "kind": "Variable",
    "name": "first",
    "variableName": "reviewCount"
  }
],
v7 = {
  "kind": "ScalarField",
  "alias": null,
  "name": "hasNextPage",
  "args": null,
  "storageKey": null
},
v8 = {
  "kind": "ScalarField",
  "alias": null,
  "name": "endCursor",
  "args": null,
  "storageKey": null
},
v9 = {
  "kind": "LinkedField",
  "alias": null,
  "name": "pageInfo",
  "storageKey": null,
  "args": null,
  "concreteType": "PageInfo",
  "plural": false,
  "selections": [
    (v7/*: any*/),
    (v8/*: any*/)
  ]
},
v10 = {
  "kind": "ScalarField",
  "alias": null,
  "name": "cursor",
  "args": null,
  "storageKey": null
},
v11 = {
  "kind": "ScalarField",
  "alias": null,
  "name": "body",
  "args": null,
  "storageKey": null
},
v12 = {
  "kind": "ScalarField",
  "alias": null,
  "name": "bodyHTML",
  "args": null,
  "storageKey": null
},
v13 = {
  "kind": "ScalarField",
  "alias": null,
  "name": "state",
  "args": null,
  "storageKey": null
},
v14 = {
  "kind": "ScalarField",
  "alias": null,
  "name": "lastEditedAt",
  "args": null,
  "storageKey": null
},
v15 = {
  "kind": "ScalarField",
  "alias": null,
  "name": "login",
  "args": null,
  "storageKey": null
},
v16 = {
  "kind": "ScalarField",
  "alias": null,
  "name": "avatarUrl",
  "args": null,
  "storageKey": null
},
v17 = {
  "kind": "LinkedField",
  "alias": null,
  "name": "author",
  "storageKey": null,
  "args": null,
  "concreteType": null,
  "plural": false,
  "selections": [
    (v3/*: any*/),
    (v15/*: any*/),
    (v16/*: any*/),
    (v5/*: any*/),
    (v4/*: any*/)
  ]
},
v18 = {
  "kind": "ScalarField",
  "alias": null,
  "name": "viewerCanUpdate",
  "args": null,
  "storageKey": null
},
v19 = {
  "kind": "ScalarField",
  "alias": null,
  "name": "authorAssociation",
  "args": null,
  "storageKey": null
},
v20 = [
  {
    "kind": "ScalarField",
    "alias": null,
    "name": "totalCount",
    "args": null,
    "storageKey": null
  }
],
v21 = {
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
      "selections": (v20/*: any*/)
    }
  ]
},
v22 = {
  "kind": "ScalarField",
  "alias": null,
  "name": "viewerCanReact",
  "args": null,
  "storageKey": null
},
v23 = [
  {
    "kind": "Variable",
    "name": "after",
    "variableName": "threadCursor"
  },
  {
    "kind": "Variable",
    "name": "first",
    "variableName": "threadCount"
  }
],
v24 = [
  (v15/*: any*/),
  (v4/*: any*/)
],
v25 = [
  {
    "kind": "Variable",
    "name": "after",
    "variableName": "commentCursor"
  },
  {
    "kind": "Variable",
    "name": "first",
    "variableName": "commentCount"
  }
],
v26 = {
  "kind": "ScalarField",
  "alias": null,
  "name": "path",
  "args": null,
  "storageKey": null
},
v27 = {
  "kind": "ScalarField",
  "alias": null,
  "name": "position",
  "args": null,
  "storageKey": null
},
v28 = {
  "kind": "ScalarField",
  "alias": null,
  "name": "createdAt",
  "args": null,
  "storageKey": null
},
v29 = {
  "kind": "ScalarField",
  "alias": null,
  "name": "name",
  "args": null,
  "storageKey": null
},
v30 = [
  (v3/*: any*/),
  (v15/*: any*/),
  (v4/*: any*/)
],
v31 = {
  "kind": "LinkedField",
  "alias": null,
  "name": "owner",
  "storageKey": null,
  "args": null,
  "concreteType": null,
  "plural": false,
  "selections": (v30/*: any*/)
},
v32 = {
  "kind": "ScalarField",
  "alias": null,
  "name": "title",
  "args": null,
  "storageKey": null
},
v33 = {
  "kind": "ScalarField",
  "alias": null,
  "name": "number",
  "args": null,
  "storageKey": null
},
v34 = [
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
v35 = {
  "kind": "LinkedField",
  "alias": null,
  "name": "pageInfo",
  "storageKey": null,
  "args": null,
  "concreteType": "PageInfo",
  "plural": false,
  "selections": [
    (v8/*: any*/),
    (v7/*: any*/)
  ]
},
v36 = [
  (v3/*: any*/),
  (v16/*: any*/),
  (v15/*: any*/),
  (v4/*: any*/)
],
v37 = {
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
      "selections": (v36/*: any*/)
    },
    (v12/*: any*/),
    (v28/*: any*/),
    (v5/*: any*/)
  ]
},
v38 = {
  "kind": "ScalarField",
  "alias": null,
  "name": "isCrossRepository",
  "args": null,
  "storageKey": null
},
v39 = [
  (v3/*: any*/),
  (v15/*: any*/),
  (v16/*: any*/),
  (v4/*: any*/)
],
v40 = {
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
    (v38/*: any*/),
    {
      "kind": "LinkedField",
      "alias": null,
      "name": "actor",
      "storageKey": null,
      "args": null,
      "concreteType": null,
      "plural": false,
      "selections": (v39/*: any*/)
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
            (v29/*: any*/),
            (v31/*: any*/),
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
            (v33/*: any*/),
            (v32/*: any*/),
            (v5/*: any*/),
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
            (v33/*: any*/),
            (v32/*: any*/),
            (v5/*: any*/),
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
},
v41 = [
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
v42 = {
  "kind": "ScalarField",
  "alias": "sha",
  "name": "oid",
  "args": null,
  "storageKey": null
},
v43 = [
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
v44 = {
  "kind": "ScalarField",
  "alias": null,
  "name": "status",
  "args": null,
  "storageKey": null
},
v45 = {
  "kind": "ScalarField",
  "alias": null,
  "name": "conclusion",
  "args": null,
  "storageKey": null
},
v46 = [
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
v47 = {
  "kind": "LinkedField",
  "alias": null,
  "name": "user",
  "storageKey": null,
  "args": null,
  "concreteType": "User",
  "plural": false,
  "selections": (v24/*: any*/)
},
v48 = {
  "kind": "LinkedField",
  "alias": null,
  "name": "actor",
  "storageKey": null,
  "args": null,
  "concreteType": null,
  "plural": false,
  "selections": (v36/*: any*/)
},
v49 = [
  {
    "kind": "ScalarField",
    "alias": null,
    "name": "oid",
    "args": null,
    "storageKey": null
  },
  (v4/*: any*/)
],
v50 = {
  "kind": "LinkedField",
  "alias": null,
  "name": "commit",
  "storageKey": null,
  "args": null,
  "concreteType": "Commit",
  "plural": false,
  "selections": (v49/*: any*/)
};
return {
  "kind": "Request",
  "fragment": {
    "kind": "Fragment",
    "name": "issueishDetailContainerQuery",
    "type": "Query",
    "metadata": null,
    "argumentDefinitions": (v0/*: any*/),
    "selections": [
      {
        "kind": "LinkedField",
        "alias": null,
        "name": "repository",
        "storageKey": null,
        "args": (v1/*: any*/),
        "concreteType": "Repository",
        "plural": false,
        "selections": [
          {
            "kind": "LinkedField",
            "alias": "issueish",
            "name": "issueOrPullRequest",
            "storageKey": null,
            "args": (v2/*: any*/),
            "concreteType": null,
            "plural": false,
            "selections": [
              (v3/*: any*/),
              {
                "kind": "InlineFragment",
                "type": "PullRequest",
                "selections": [
                  {
                    "kind": "FragmentSpread",
                    "name": "aggregatedReviewsContainer_pullRequest",
                    "args": [
                      {
                        "kind": "Variable",
                        "name": "commentCount",
                        "variableName": "commentCount"
                      },
                      {
                        "kind": "Variable",
                        "name": "commentCursor",
                        "variableName": "commentCursor"
                      },
                      {
                        "kind": "Variable",
                        "name": "reviewCount",
                        "variableName": "reviewCount"
                      },
                      {
                        "kind": "Variable",
                        "name": "reviewCursor",
                        "variableName": "reviewCursor"
                      },
                      {
                        "kind": "Variable",
                        "name": "threadCount",
                        "variableName": "threadCount"
                      },
                      {
                        "kind": "Variable",
                        "name": "threadCursor",
                        "variableName": "threadCursor"
                      }
                    ]
                  }
                ]
              }
            ]
          },
          {
            "kind": "FragmentSpread",
            "name": "issueishDetailController_repository",
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
                "name": "issueishNumber",
                "variableName": "issueishNumber"
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
    "name": "issueishDetailContainerQuery",
    "argumentDefinitions": (v0/*: any*/),
    "selections": [
      {
        "kind": "LinkedField",
        "alias": null,
        "name": "repository",
        "storageKey": null,
        "args": (v1/*: any*/),
        "concreteType": "Repository",
        "plural": false,
        "selections": [
          {
            "kind": "LinkedField",
            "alias": "issueish",
            "name": "issueOrPullRequest",
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
                  (v5/*: any*/),
                  {
                    "kind": "LinkedField",
                    "alias": null,
                    "name": "reviews",
                    "storageKey": null,
                    "args": (v6/*: any*/),
                    "concreteType": "PullRequestReviewConnection",
                    "plural": false,
                    "selections": [
                      (v9/*: any*/),
                      {
                        "kind": "LinkedField",
                        "alias": null,
                        "name": "edges",
                        "storageKey": null,
                        "args": null,
                        "concreteType": "PullRequestReviewEdge",
                        "plural": true,
                        "selections": [
                          (v10/*: any*/),
                          {
                            "kind": "LinkedField",
                            "alias": null,
                            "name": "node",
                            "storageKey": null,
                            "args": null,
                            "concreteType": "PullRequestReview",
                            "plural": false,
                            "selections": [
                              (v4/*: any*/),
                              (v11/*: any*/),
                              (v12/*: any*/),
                              (v13/*: any*/),
                              {
                                "kind": "ScalarField",
                                "alias": null,
                                "name": "submittedAt",
                                "args": null,
                                "storageKey": null
                              },
                              (v14/*: any*/),
                              (v5/*: any*/),
                              (v17/*: any*/),
                              (v18/*: any*/),
                              (v19/*: any*/),
                              (v21/*: any*/),
                              (v22/*: any*/),
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
                    "name": "reviews",
                    "args": (v6/*: any*/),
                    "handle": "connection",
                    "key": "ReviewSummariesAccumulator_reviews",
                    "filters": null
                  },
                  {
                    "kind": "LinkedField",
                    "alias": null,
                    "name": "reviewThreads",
                    "storageKey": null,
                    "args": (v23/*: any*/),
                    "concreteType": "PullRequestReviewThreadConnection",
                    "plural": false,
                    "selections": [
                      (v9/*: any*/),
                      {
                        "kind": "LinkedField",
                        "alias": null,
                        "name": "edges",
                        "storageKey": null,
                        "args": null,
                        "concreteType": "PullRequestReviewThreadEdge",
                        "plural": true,
                        "selections": [
                          (v10/*: any*/),
                          {
                            "kind": "LinkedField",
                            "alias": null,
                            "name": "node",
                            "storageKey": null,
                            "args": null,
                            "concreteType": "PullRequestReviewThread",
                            "plural": false,
                            "selections": [
                              (v4/*: any*/),
                              {
                                "kind": "ScalarField",
                                "alias": null,
                                "name": "isResolved",
                                "args": null,
                                "storageKey": null
                              },
                              {
                                "kind": "LinkedField",
                                "alias": null,
                                "name": "resolvedBy",
                                "storageKey": null,
                                "args": null,
                                "concreteType": "User",
                                "plural": false,
                                "selections": (v24/*: any*/)
                              },
                              {
                                "kind": "ScalarField",
                                "alias": null,
                                "name": "viewerCanResolve",
                                "args": null,
                                "storageKey": null
                              },
                              {
                                "kind": "ScalarField",
                                "alias": null,
                                "name": "viewerCanUnresolve",
                                "args": null,
                                "storageKey": null
                              },
                              {
                                "kind": "LinkedField",
                                "alias": null,
                                "name": "comments",
                                "storageKey": null,
                                "args": (v25/*: any*/),
                                "concreteType": "PullRequestReviewCommentConnection",
                                "plural": false,
                                "selections": [
                                  (v9/*: any*/),
                                  {
                                    "kind": "LinkedField",
                                    "alias": null,
                                    "name": "edges",
                                    "storageKey": null,
                                    "args": null,
                                    "concreteType": "PullRequestReviewCommentEdge",
                                    "plural": true,
                                    "selections": [
                                      (v10/*: any*/),
                                      {
                                        "kind": "LinkedField",
                                        "alias": null,
                                        "name": "node",
                                        "storageKey": null,
                                        "args": null,
                                        "concreteType": "PullRequestReviewComment",
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
                                            "selections": [
                                              (v3/*: any*/),
                                              (v16/*: any*/),
                                              (v15/*: any*/),
                                              (v5/*: any*/),
                                              (v4/*: any*/)
                                            ]
                                          },
                                          (v12/*: any*/),
                                          (v11/*: any*/),
                                          {
                                            "kind": "ScalarField",
                                            "alias": null,
                                            "name": "isMinimized",
                                            "args": null,
                                            "storageKey": null
                                          },
                                          (v13/*: any*/),
                                          (v22/*: any*/),
                                          (v18/*: any*/),
                                          (v26/*: any*/),
                                          (v27/*: any*/),
                                          (v28/*: any*/),
                                          (v14/*: any*/),
                                          (v5/*: any*/),
                                          (v19/*: any*/),
                                          (v21/*: any*/),
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
                                "name": "comments",
                                "args": (v25/*: any*/),
                                "handle": "connection",
                                "key": "ReviewCommentsAccumulator_comments",
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
                    "name": "reviewThreads",
                    "args": (v23/*: any*/),
                    "handle": "connection",
                    "key": "ReviewThreadsAccumulator_reviewThreads",
                    "filters": null
                  }
                ]
              }
            ]
          },
          (v4/*: any*/),
          (v29/*: any*/),
          (v31/*: any*/),
          {
            "kind": "LinkedField",
            "alias": "issue",
            "name": "issueOrPullRequest",
            "storageKey": null,
            "args": (v2/*: any*/),
            "concreteType": null,
            "plural": false,
            "selections": [
              (v3/*: any*/),
              (v4/*: any*/),
              {
                "kind": "InlineFragment",
                "type": "Issue",
                "selections": [
                  (v32/*: any*/),
                  (v33/*: any*/),
                  (v5/*: any*/),
                  (v13/*: any*/),
                  (v12/*: any*/),
                  (v17/*: any*/),
                  {
                    "kind": "LinkedField",
                    "alias": null,
                    "name": "timelineItems",
                    "storageKey": null,
                    "args": (v34/*: any*/),
                    "concreteType": "IssueTimelineItemsConnection",
                    "plural": false,
                    "selections": [
                      (v35/*: any*/),
                      {
                        "kind": "LinkedField",
                        "alias": null,
                        "name": "edges",
                        "storageKey": null,
                        "args": null,
                        "concreteType": "IssueTimelineItemsEdge",
                        "plural": true,
                        "selections": [
                          (v10/*: any*/),
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
                              (v37/*: any*/),
                              (v40/*: any*/)
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
                    "args": (v34/*: any*/),
                    "handle": "connection",
                    "key": "IssueTimelineController_timelineItems",
                    "filters": null
                  },
                  (v21/*: any*/),
                  (v22/*: any*/)
                ]
              }
            ]
          },
          {
            "kind": "LinkedField",
            "alias": "pullRequest",
            "name": "issueOrPullRequest",
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
                  (v32/*: any*/),
                  (v33/*: any*/),
                  {
                    "kind": "ScalarField",
                    "alias": null,
                    "name": "headRefName",
                    "args": null,
                    "storageKey": null
                  },
                  {
                    "kind": "LinkedField",
                    "alias": null,
                    "name": "headRepository",
                    "storageKey": null,
                    "args": null,
                    "concreteType": "Repository",
                    "plural": false,
                    "selections": [
                      (v29/*: any*/),
                      (v5/*: any*/),
                      {
                        "kind": "ScalarField",
                        "alias": null,
                        "name": "sshUrl",
                        "args": null,
                        "storageKey": null
                      },
                      (v31/*: any*/),
                      (v4/*: any*/)
                    ]
                  },
                  (v5/*: any*/),
                  (v38/*: any*/),
                  {
                    "kind": "ScalarField",
                    "alias": null,
                    "name": "changedFiles",
                    "args": null,
                    "storageKey": null
                  },
                  (v13/*: any*/),
                  (v12/*: any*/),
                  {
                    "kind": "ScalarField",
                    "alias": null,
                    "name": "baseRefName",
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
                    "selections": (v20/*: any*/)
                  },
                  (v17/*: any*/),
                  {
                    "kind": "LinkedField",
                    "alias": null,
                    "name": "commits",
                    "storageKey": null,
                    "args": (v41/*: any*/),
                    "concreteType": "PullRequestCommitConnection",
                    "plural": false,
                    "selections": [
                      (v35/*: any*/),
                      {
                        "kind": "LinkedField",
                        "alias": null,
                        "name": "edges",
                        "storageKey": null,
                        "args": null,
                        "concreteType": "PullRequestCommitEdge",
                        "plural": true,
                        "selections": [
                          (v10/*: any*/),
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
                                      (v29/*: any*/),
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
                                  (v42/*: any*/),
                                  (v5/*: any*/)
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
                    "args": (v41/*: any*/),
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
                                      (v13/*: any*/),
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
                                          (v13/*: any*/),
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
                                    "args": (v43/*: any*/),
                                    "concreteType": "CheckSuiteConnection",
                                    "plural": false,
                                    "selections": [
                                      (v9/*: any*/),
                                      {
                                        "kind": "LinkedField",
                                        "alias": null,
                                        "name": "edges",
                                        "storageKey": null,
                                        "args": null,
                                        "concreteType": "CheckSuiteEdge",
                                        "plural": true,
                                        "selections": [
                                          (v10/*: any*/),
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
                                              (v44/*: any*/),
                                              (v45/*: any*/),
                                              {
                                                "kind": "LinkedField",
                                                "alias": null,
                                                "name": "app",
                                                "storageKey": null,
                                                "args": null,
                                                "concreteType": "App",
                                                "plural": false,
                                                "selections": [
                                                  (v29/*: any*/),
                                                  (v4/*: any*/)
                                                ]
                                              },
                                              {
                                                "kind": "LinkedField",
                                                "alias": null,
                                                "name": "checkRuns",
                                                "storageKey": null,
                                                "args": (v46/*: any*/),
                                                "concreteType": "CheckRunConnection",
                                                "plural": false,
                                                "selections": [
                                                  (v9/*: any*/),
                                                  {
                                                    "kind": "LinkedField",
                                                    "alias": null,
                                                    "name": "edges",
                                                    "storageKey": null,
                                                    "args": null,
                                                    "concreteType": "CheckRunEdge",
                                                    "plural": true,
                                                    "selections": [
                                                      (v10/*: any*/),
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
                                                          (v44/*: any*/),
                                                          (v45/*: any*/),
                                                          (v29/*: any*/),
                                                          (v32/*: any*/),
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
                                                "args": (v46/*: any*/),
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
                                    "args": (v43/*: any*/),
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
                    "selections": (v30/*: any*/)
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
                      (v31/*: any*/),
                      (v4/*: any*/)
                    ]
                  },
                  {
                    "kind": "LinkedField",
                    "alias": null,
                    "name": "timelineItems",
                    "storageKey": null,
                    "args": (v34/*: any*/),
                    "concreteType": "PullRequestTimelineItemsConnection",
                    "plural": false,
                    "selections": [
                      (v35/*: any*/),
                      {
                        "kind": "LinkedField",
                        "alias": null,
                        "name": "edges",
                        "storageKey": null,
                        "args": null,
                        "concreteType": "PullRequestTimelineItemsEdge",
                        "plural": true,
                        "selections": [
                          (v10/*: any*/),
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
                                          (v29/*: any*/),
                                          (v47/*: any*/),
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
                                          (v29/*: any*/),
                                          (v16/*: any*/),
                                          (v47/*: any*/)
                                        ]
                                      },
                                      {
                                        "kind": "ScalarField",
                                        "alias": null,
                                        "name": "authoredByCommitter",
                                        "args": null,
                                        "storageKey": null
                                      },
                                      (v42/*: any*/),
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
                              (v37/*: any*/),
                              {
                                "kind": "InlineFragment",
                                "type": "MergedEvent",
                                "selections": [
                                  (v48/*: any*/),
                                  (v50/*: any*/),
                                  {
                                    "kind": "ScalarField",
                                    "alias": null,
                                    "name": "mergeRefName",
                                    "args": null,
                                    "storageKey": null
                                  },
                                  (v28/*: any*/)
                                ]
                              },
                              {
                                "kind": "InlineFragment",
                                "type": "HeadRefForcePushedEvent",
                                "selections": [
                                  (v48/*: any*/),
                                  {
                                    "kind": "LinkedField",
                                    "alias": null,
                                    "name": "beforeCommit",
                                    "storageKey": null,
                                    "args": null,
                                    "concreteType": "Commit",
                                    "plural": false,
                                    "selections": (v49/*: any*/)
                                  },
                                  {
                                    "kind": "LinkedField",
                                    "alias": null,
                                    "name": "afterCommit",
                                    "storageKey": null,
                                    "args": null,
                                    "concreteType": "Commit",
                                    "plural": false,
                                    "selections": (v49/*: any*/)
                                  },
                                  (v28/*: any*/)
                                ]
                              },
                              {
                                "kind": "InlineFragment",
                                "type": "PullRequestCommitCommentThread",
                                "selections": [
                                  (v50/*: any*/),
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
                                                "selections": (v39/*: any*/)
                                              },
                                              (v50/*: any*/),
                                              (v12/*: any*/),
                                              (v28/*: any*/),
                                              (v26/*: any*/),
                                              (v27/*: any*/)
                                            ]
                                          }
                                        ]
                                      }
                                    ]
                                  }
                                ]
                              },
                              (v40/*: any*/)
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
                    "args": (v34/*: any*/),
                    "handle": "connection",
                    "key": "prTimelineContainer_timelineItems",
                    "filters": null
                  },
                  (v21/*: any*/),
                  (v22/*: any*/)
                ]
              }
            ]
          }
        ]
      }
    ]
  },
  "params": {
    "operationKind": "query",
    "name": "issueishDetailContainerQuery",
    "id": null,
    "text": "query issueishDetailContainerQuery(\n  $repoOwner: String!\n  $repoName: String!\n  $issueishNumber: Int!\n  $timelineCount: Int!\n  $timelineCursor: String\n  $commitCount: Int!\n  $commitCursor: String\n  $reviewCount: Int!\n  $reviewCursor: String\n  $threadCount: Int!\n  $threadCursor: String\n  $commentCount: Int!\n  $commentCursor: String\n  $checkSuiteCount: Int!\n  $checkSuiteCursor: String\n  $checkRunCount: Int!\n  $checkRunCursor: String\n) {\n  repository(owner: $repoOwner, name: $repoName) {\n    issueish: issueOrPullRequest(number: $issueishNumber) {\n      __typename\n      ... on PullRequest {\n        ...aggregatedReviewsContainer_pullRequest_qdneZ\n      }\n      ... on Node {\n        id\n      }\n    }\n    ...issueishDetailController_repository_3iQpNL\n    id\n  }\n}\n\nfragment aggregatedReviewsContainer_pullRequest_qdneZ on PullRequest {\n  id\n  ...reviewSummariesAccumulator_pullRequest_2zzc96\n  ...reviewThreadsAccumulator_pullRequest_CKDvj\n}\n\nfragment checkRunView_checkRun on CheckRun {\n  name\n  status\n  conclusion\n  title\n  summary\n  permalink\n  detailsUrl\n}\n\nfragment checkRunsAccumulator_checkSuite_Rvfr1 on CheckSuite {\n  id\n  checkRuns(first: $checkRunCount, after: $checkRunCursor) {\n    pageInfo {\n      hasNextPage\n      endCursor\n    }\n    edges {\n      cursor\n      node {\n        id\n        status\n        conclusion\n        ...checkRunView_checkRun\n        __typename\n      }\n    }\n  }\n}\n\nfragment checkSuiteView_checkSuite on CheckSuite {\n  app {\n    name\n    id\n  }\n  status\n  conclusion\n}\n\nfragment checkSuitesAccumulator_commit_1oGSNs on Commit {\n  id\n  checkSuites(first: $checkSuiteCount, after: $checkSuiteCursor) {\n    pageInfo {\n      hasNextPage\n      endCursor\n    }\n    edges {\n      cursor\n      node {\n        id\n        status\n        conclusion\n        ...checkSuiteView_checkSuite\n        ...checkRunsAccumulator_checkSuite_Rvfr1\n        __typename\n      }\n    }\n  }\n}\n\nfragment commitCommentThreadView_item on PullRequestCommitCommentThread {\n  commit {\n    oid\n    id\n  }\n  comments(first: 100) {\n    edges {\n      node {\n        id\n        ...commitCommentView_item\n      }\n    }\n  }\n}\n\nfragment commitCommentView_item on CommitComment {\n  author {\n    __typename\n    login\n    avatarUrl\n    ... on Node {\n      id\n    }\n  }\n  commit {\n    oid\n    id\n  }\n  bodyHTML\n  createdAt\n  path\n  position\n}\n\nfragment commitView_commit on Commit {\n  author {\n    name\n    avatarUrl\n    user {\n      login\n      id\n    }\n  }\n  committer {\n    name\n    avatarUrl\n    user {\n      login\n      id\n    }\n  }\n  authoredByCommitter\n  sha: oid\n  message\n  messageHeadlineHTML\n  commitUrl\n}\n\nfragment commitsView_nodes on PullRequestCommit {\n  commit {\n    id\n    author {\n      name\n      user {\n        login\n        id\n      }\n    }\n    ...commitView_commit\n  }\n}\n\nfragment crossReferencedEventView_item on CrossReferencedEvent {\n  id\n  isCrossRepository\n  source {\n    __typename\n    ... on Issue {\n      number\n      title\n      url\n      issueState: state\n    }\n    ... on PullRequest {\n      number\n      title\n      url\n      prState: state\n    }\n    ... on RepositoryNode {\n      repository {\n        name\n        isPrivate\n        owner {\n          __typename\n          login\n          id\n        }\n        id\n      }\n    }\n    ... on Node {\n      id\n    }\n  }\n}\n\nfragment crossReferencedEventsView_nodes on CrossReferencedEvent {\n  id\n  referencedAt\n  isCrossRepository\n  actor {\n    __typename\n    login\n    avatarUrl\n    ... on Node {\n      id\n    }\n  }\n  source {\n    __typename\n    ... on RepositoryNode {\n      repository {\n        name\n        owner {\n          __typename\n          login\n          id\n        }\n        id\n      }\n    }\n    ... on Node {\n      id\n    }\n  }\n  ...crossReferencedEventView_item\n}\n\nfragment emojiReactionsController_reactable on Reactable {\n  id\n  ...emojiReactionsView_reactable\n}\n\nfragment emojiReactionsView_reactable on Reactable {\n  id\n  reactionGroups {\n    content\n    viewerHasReacted\n    users {\n      totalCount\n    }\n  }\n  viewerCanReact\n}\n\nfragment headRefForcePushedEventView_issueish on PullRequest {\n  headRefName\n  headRepositoryOwner {\n    __typename\n    login\n    id\n  }\n  repository {\n    owner {\n      __typename\n      login\n      id\n    }\n    id\n  }\n}\n\nfragment headRefForcePushedEventView_item on HeadRefForcePushedEvent {\n  actor {\n    __typename\n    avatarUrl\n    login\n    ... on Node {\n      id\n    }\n  }\n  beforeCommit {\n    oid\n    id\n  }\n  afterCommit {\n    oid\n    id\n  }\n  createdAt\n}\n\nfragment issueCommentView_item on IssueComment {\n  author {\n    __typename\n    avatarUrl\n    login\n    ... on Node {\n      id\n    }\n  }\n  bodyHTML\n  createdAt\n  url\n}\n\nfragment issueDetailView_issue_3D8CP9 on Issue {\n  id\n  __typename\n  url\n  state\n  number\n  title\n  bodyHTML\n  author {\n    __typename\n    login\n    avatarUrl\n    url\n    ... on Node {\n      id\n    }\n  }\n  ...issueTimelineController_issue_3D8CP9\n  ...emojiReactionsView_reactable\n}\n\nfragment issueDetailView_repository on Repository {\n  id\n  name\n  owner {\n    __typename\n    login\n    id\n  }\n}\n\nfragment issueTimelineController_issue_3D8CP9 on Issue {\n  url\n  timelineItems(first: $timelineCount, after: $timelineCursor) {\n    pageInfo {\n      endCursor\n      hasNextPage\n    }\n    edges {\n      cursor\n      node {\n        __typename\n        ...issueCommentView_item\n        ...crossReferencedEventsView_nodes\n        ... on Node {\n          id\n        }\n      }\n    }\n  }\n}\n\nfragment issueishDetailController_repository_3iQpNL on Repository {\n  ...issueDetailView_repository\n  ...prCheckoutController_repository\n  ...prDetailView_repository\n  name\n  owner {\n    __typename\n    login\n    id\n  }\n  issue: issueOrPullRequest(number: $issueishNumber) {\n    __typename\n    ... on Issue {\n      title\n      number\n      ...issueDetailView_issue_3D8CP9\n    }\n    ... on Node {\n      id\n    }\n  }\n  pullRequest: issueOrPullRequest(number: $issueishNumber) {\n    __typename\n    ... on PullRequest {\n      title\n      number\n      ...prCheckoutController_pullRequest\n      ...prDetailView_pullRequest_1UVrY8\n    }\n    ... on Node {\n      id\n    }\n  }\n}\n\nfragment mergedEventView_item on MergedEvent {\n  actor {\n    __typename\n    avatarUrl\n    login\n    ... on Node {\n      id\n    }\n  }\n  commit {\n    oid\n    id\n  }\n  mergeRefName\n  createdAt\n}\n\nfragment prCheckoutController_pullRequest on PullRequest {\n  number\n  headRefName\n  headRepository {\n    name\n    url\n    sshUrl\n    owner {\n      __typename\n      login\n      id\n    }\n    id\n  }\n}\n\nfragment prCheckoutController_repository on Repository {\n  name\n  owner {\n    __typename\n    login\n    id\n  }\n}\n\nfragment prCommitView_item on Commit {\n  committer {\n    avatarUrl\n    name\n    date\n  }\n  messageHeadline\n  messageBody\n  shortSha: abbreviatedOid\n  sha: oid\n  url\n}\n\nfragment prCommitsView_pullRequest_38TpXw on PullRequest {\n  url\n  commits(first: $commitCount, after: $commitCursor) {\n    pageInfo {\n      endCursor\n      hasNextPage\n    }\n    edges {\n      cursor\n      node {\n        commit {\n          id\n          ...prCommitView_item\n        }\n        id\n        __typename\n      }\n    }\n  }\n}\n\nfragment prDetailView_pullRequest_1UVrY8 on PullRequest {\n  id\n  __typename\n  url\n  isCrossRepository\n  changedFiles\n  state\n  number\n  title\n  bodyHTML\n  baseRefName\n  headRefName\n  countedCommits: commits {\n    totalCount\n  }\n  author {\n    __typename\n    login\n    avatarUrl\n    url\n    ... on Node {\n      id\n    }\n  }\n  ...prCommitsView_pullRequest_38TpXw\n  ...prStatusesView_pullRequest_1oGSNs\n  ...prTimelineController_pullRequest_3D8CP9\n  ...emojiReactionsController_reactable\n}\n\nfragment prDetailView_repository on Repository {\n  id\n  name\n  owner {\n    __typename\n    login\n    id\n  }\n}\n\nfragment prStatusContextView_context on StatusContext {\n  context\n  description\n  state\n  targetUrl\n}\n\nfragment prStatusesView_pullRequest_1oGSNs on PullRequest {\n  id\n  recentCommits: commits(last: 1) {\n    edges {\n      node {\n        commit {\n          status {\n            state\n            contexts {\n              id\n              state\n              ...prStatusContextView_context\n            }\n            id\n          }\n          ...checkSuitesAccumulator_commit_1oGSNs\n          id\n        }\n        id\n      }\n    }\n  }\n}\n\nfragment prTimelineController_pullRequest_3D8CP9 on PullRequest {\n  url\n  ...headRefForcePushedEventView_issueish\n  timelineItems(first: $timelineCount, after: $timelineCursor) {\n    pageInfo {\n      endCursor\n      hasNextPage\n    }\n    edges {\n      cursor\n      node {\n        __typename\n        ...commitsView_nodes\n        ...issueCommentView_item\n        ...mergedEventView_item\n        ...headRefForcePushedEventView_item\n        ...commitCommentThreadView_item\n        ...crossReferencedEventsView_nodes\n        ... on Node {\n          id\n        }\n      }\n    }\n  }\n}\n\nfragment reviewCommentsAccumulator_reviewThread_1VbUmL on PullRequestReviewThread {\n  id\n  comments(first: $commentCount, after: $commentCursor) {\n    pageInfo {\n      hasNextPage\n      endCursor\n    }\n    edges {\n      cursor\n      node {\n        id\n        author {\n          __typename\n          avatarUrl\n          login\n          url\n          ... on Node {\n            id\n          }\n        }\n        bodyHTML\n        body\n        isMinimized\n        state\n        viewerCanReact\n        viewerCanUpdate\n        path\n        position\n        createdAt\n        lastEditedAt\n        url\n        authorAssociation\n        ...emojiReactionsController_reactable\n        __typename\n      }\n    }\n  }\n}\n\nfragment reviewSummariesAccumulator_pullRequest_2zzc96 on PullRequest {\n  url\n  reviews(first: $reviewCount, after: $reviewCursor) {\n    pageInfo {\n      hasNextPage\n      endCursor\n    }\n    edges {\n      cursor\n      node {\n        id\n        body\n        bodyHTML\n        state\n        submittedAt\n        lastEditedAt\n        url\n        author {\n          __typename\n          login\n          avatarUrl\n          url\n          ... on Node {\n            id\n          }\n        }\n        viewerCanUpdate\n        authorAssociation\n        ...emojiReactionsController_reactable\n        __typename\n      }\n    }\n  }\n}\n\nfragment reviewThreadsAccumulator_pullRequest_CKDvj on PullRequest {\n  url\n  reviewThreads(first: $threadCount, after: $threadCursor) {\n    pageInfo {\n      hasNextPage\n      endCursor\n    }\n    edges {\n      cursor\n      node {\n        id\n        isResolved\n        resolvedBy {\n          login\n          id\n        }\n        viewerCanResolve\n        viewerCanUnresolve\n        ...reviewCommentsAccumulator_reviewThread_1VbUmL\n        __typename\n      }\n    }\n  }\n}\n",
    "metadata": {}
  }
};
})();
// prettier-ignore
(node/*: any*/).hash = 'c65534cd8bf43f640862f89187b6ff64';
module.exports = node;
