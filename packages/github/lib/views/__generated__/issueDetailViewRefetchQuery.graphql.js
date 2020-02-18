/**
 * @flow
 * @relayHash 30fb0866995510475e94c3079069bf0e
 */

/* eslint-disable */

'use strict';

/*::
import type { ConcreteRequest } from 'relay-runtime';
type issueDetailView_issue$ref = any;
type issueDetailView_repository$ref = any;
export type issueDetailViewRefetchQueryVariables = {|
  repoId: string,
  issueishId: string,
  timelineCount: number,
  timelineCursor?: ?string,
|};
export type issueDetailViewRefetchQueryResponse = {|
  +repository: ?{|
    +$fragmentRefs: issueDetailView_repository$ref
  |},
  +issue: ?{|
    +$fragmentRefs: issueDetailView_issue$ref
  |},
|};
export type issueDetailViewRefetchQuery = {|
  variables: issueDetailViewRefetchQueryVariables,
  response: issueDetailViewRefetchQueryResponse,
|};
*/


/*
query issueDetailViewRefetchQuery(
  $repoId: ID!
  $issueishId: ID!
  $timelineCount: Int!
  $timelineCursor: String
) {
  repository: node(id: $repoId) {
    __typename
    ...issueDetailView_repository
    id
  }
  issue: node(id: $issueishId) {
    __typename
    ...issueDetailView_issue_3D8CP9
    id
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
v7 = {
  "kind": "LinkedField",
  "alias": null,
  "name": "owner",
  "storageKey": null,
  "args": null,
  "concreteType": null,
  "plural": false,
  "selections": [
    (v3/*: any*/),
    (v6/*: any*/),
    (v4/*: any*/)
  ]
},
v8 = {
  "kind": "ScalarField",
  "alias": null,
  "name": "url",
  "args": null,
  "storageKey": null
},
v9 = {
  "kind": "ScalarField",
  "alias": null,
  "name": "number",
  "args": null,
  "storageKey": null
},
v10 = {
  "kind": "ScalarField",
  "alias": null,
  "name": "title",
  "args": null,
  "storageKey": null
},
v11 = {
  "kind": "ScalarField",
  "alias": null,
  "name": "bodyHTML",
  "args": null,
  "storageKey": null
},
v12 = {
  "kind": "ScalarField",
  "alias": null,
  "name": "avatarUrl",
  "args": null,
  "storageKey": null
},
v13 = [
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
];
return {
  "kind": "Request",
  "fragment": {
    "kind": "Fragment",
    "name": "issueDetailViewRefetchQuery",
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
            "name": "issueDetailView_repository",
            "args": null
          }
        ]
      },
      {
        "kind": "LinkedField",
        "alias": "issue",
        "name": "node",
        "storageKey": null,
        "args": (v2/*: any*/),
        "concreteType": null,
        "plural": false,
        "selections": [
          {
            "kind": "FragmentSpread",
            "name": "issueDetailView_issue",
            "args": [
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
    "name": "issueDetailViewRefetchQuery",
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
              (v7/*: any*/)
            ]
          }
        ]
      },
      {
        "kind": "LinkedField",
        "alias": "issue",
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
            "type": "Issue",
            "selections": [
              (v3/*: any*/),
              (v8/*: any*/),
              {
                "kind": "ScalarField",
                "alias": null,
                "name": "state",
                "args": null,
                "storageKey": null
              },
              (v9/*: any*/),
              (v10/*: any*/),
              (v11/*: any*/),
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
                  (v12/*: any*/),
                  (v8/*: any*/),
                  (v4/*: any*/)
                ]
              },
              {
                "kind": "LinkedField",
                "alias": null,
                "name": "timelineItems",
                "storageKey": null,
                "args": (v13/*: any*/),
                "concreteType": "IssueTimelineItemsConnection",
                "plural": false,
                "selections": [
                  {
                    "kind": "LinkedField",
                    "alias": null,
                    "name": "pageInfo",
                    "storageKey": null,
                    "args": null,
                    "concreteType": "PageInfo",
                    "plural": false,
                    "selections": [
                      {
                        "kind": "ScalarField",
                        "alias": null,
                        "name": "endCursor",
                        "args": null,
                        "storageKey": null
                      },
                      {
                        "kind": "ScalarField",
                        "alias": null,
                        "name": "hasNextPage",
                        "args": null,
                        "storageKey": null
                      }
                    ]
                  },
                  {
                    "kind": "LinkedField",
                    "alias": null,
                    "name": "edges",
                    "storageKey": null,
                    "args": null,
                    "concreteType": "IssueTimelineItemsEdge",
                    "plural": true,
                    "selections": [
                      {
                        "kind": "ScalarField",
                        "alias": null,
                        "name": "cursor",
                        "args": null,
                        "storageKey": null
                      },
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
                                "selections": [
                                  (v3/*: any*/),
                                  (v12/*: any*/),
                                  (v6/*: any*/),
                                  (v4/*: any*/)
                                ]
                              },
                              (v11/*: any*/),
                              {
                                "kind": "ScalarField",
                                "alias": null,
                                "name": "createdAt",
                                "args": null,
                                "storageKey": null
                              },
                              (v8/*: any*/)
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
                              {
                                "kind": "ScalarField",
                                "alias": null,
                                "name": "isCrossRepository",
                                "args": null,
                                "storageKey": null
                              },
                              {
                                "kind": "LinkedField",
                                "alias": null,
                                "name": "actor",
                                "storageKey": null,
                                "args": null,
                                "concreteType": null,
                                "plural": false,
                                "selections": [
                                  (v3/*: any*/),
                                  (v6/*: any*/),
                                  (v12/*: any*/),
                                  (v4/*: any*/)
                                ]
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
                                      (v7/*: any*/),
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
                                      (v9/*: any*/),
                                      (v10/*: any*/),
                                      (v8/*: any*/),
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
                                      (v9/*: any*/),
                                      (v10/*: any*/),
                                      (v8/*: any*/),
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
                "args": (v13/*: any*/),
                "handle": "connection",
                "key": "IssueTimelineController_timelineItems",
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
                    "selections": [
                      {
                        "kind": "ScalarField",
                        "alias": null,
                        "name": "totalCount",
                        "args": null,
                        "storageKey": null
                      }
                    ]
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
    "name": "issueDetailViewRefetchQuery",
    "id": null,
    "text": "query issueDetailViewRefetchQuery(\n  $repoId: ID!\n  $issueishId: ID!\n  $timelineCount: Int!\n  $timelineCursor: String\n) {\n  repository: node(id: $repoId) {\n    __typename\n    ...issueDetailView_repository\n    id\n  }\n  issue: node(id: $issueishId) {\n    __typename\n    ...issueDetailView_issue_3D8CP9\n    id\n  }\n}\n\nfragment crossReferencedEventView_item on CrossReferencedEvent {\n  id\n  isCrossRepository\n  source {\n    __typename\n    ... on Issue {\n      number\n      title\n      url\n      issueState: state\n    }\n    ... on PullRequest {\n      number\n      title\n      url\n      prState: state\n    }\n    ... on RepositoryNode {\n      repository {\n        name\n        isPrivate\n        owner {\n          __typename\n          login\n          id\n        }\n        id\n      }\n    }\n    ... on Node {\n      id\n    }\n  }\n}\n\nfragment crossReferencedEventsView_nodes on CrossReferencedEvent {\n  id\n  referencedAt\n  isCrossRepository\n  actor {\n    __typename\n    login\n    avatarUrl\n    ... on Node {\n      id\n    }\n  }\n  source {\n    __typename\n    ... on RepositoryNode {\n      repository {\n        name\n        owner {\n          __typename\n          login\n          id\n        }\n        id\n      }\n    }\n    ... on Node {\n      id\n    }\n  }\n  ...crossReferencedEventView_item\n}\n\nfragment emojiReactionsView_reactable on Reactable {\n  id\n  reactionGroups {\n    content\n    viewerHasReacted\n    users {\n      totalCount\n    }\n  }\n  viewerCanReact\n}\n\nfragment issueCommentView_item on IssueComment {\n  author {\n    __typename\n    avatarUrl\n    login\n    ... on Node {\n      id\n    }\n  }\n  bodyHTML\n  createdAt\n  url\n}\n\nfragment issueDetailView_issue_3D8CP9 on Issue {\n  id\n  __typename\n  url\n  state\n  number\n  title\n  bodyHTML\n  author {\n    __typename\n    login\n    avatarUrl\n    url\n    ... on Node {\n      id\n    }\n  }\n  ...issueTimelineController_issue_3D8CP9\n  ...emojiReactionsView_reactable\n}\n\nfragment issueDetailView_repository on Repository {\n  id\n  name\n  owner {\n    __typename\n    login\n    id\n  }\n}\n\nfragment issueTimelineController_issue_3D8CP9 on Issue {\n  url\n  timelineItems(first: $timelineCount, after: $timelineCursor) {\n    pageInfo {\n      endCursor\n      hasNextPage\n    }\n    edges {\n      cursor\n      node {\n        __typename\n        ...issueCommentView_item\n        ...crossReferencedEventsView_nodes\n        ... on Node {\n          id\n        }\n      }\n    }\n  }\n}\n",
    "metadata": {}
  }
};
})();
// prettier-ignore
(node/*: any*/).hash = '180dc18124ae95e41044932a2daf88ad';
module.exports = node;
