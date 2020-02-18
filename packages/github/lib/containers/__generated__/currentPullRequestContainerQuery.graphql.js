/**
 * @flow
 * @relayHash 11d909ebcdc948ee058ed9dced388da7
 */

/* eslint-disable */

'use strict';

/*::
import type { ConcreteRequest } from 'relay-runtime';
type issueishListController_results$ref = any;
export type currentPullRequestContainerQueryVariables = {|
  headOwner: string,
  headName: string,
  headRef: string,
  first: number,
  checkSuiteCount: number,
  checkSuiteCursor?: ?string,
  checkRunCount: number,
  checkRunCursor?: ?string,
|};
export type currentPullRequestContainerQueryResponse = {|
  +repository: ?{|
    +ref: ?{|
      +associatedPullRequests: {|
        +totalCount: number,
        +nodes: ?$ReadOnlyArray<?{|
          +$fragmentRefs: issueishListController_results$ref
        |}>,
      |}
    |}
  |}
|};
export type currentPullRequestContainerQuery = {|
  variables: currentPullRequestContainerQueryVariables,
  response: currentPullRequestContainerQueryResponse,
|};
*/


/*
query currentPullRequestContainerQuery(
  $headOwner: String!
  $headName: String!
  $headRef: String!
  $first: Int!
  $checkSuiteCount: Int!
  $checkSuiteCursor: String
  $checkRunCount: Int!
  $checkRunCursor: String
) {
  repository(owner: $headOwner, name: $headName) {
    ref(qualifiedName: $headRef) {
      associatedPullRequests(first: $first, states: [OPEN]) {
        totalCount
        nodes {
          ...issueishListController_results_1oGSNs
          id
        }
      }
      id
    }
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

fragment issueishListController_results_1oGSNs on PullRequest {
  number
  title
  url
  author {
    __typename
    login
    avatarUrl
    ... on Node {
      id
    }
  }
  createdAt
  headRefName
  repository {
    id
    name
    owner {
      __typename
      login
      id
    }
  }
  commits(last: 1) {
    nodes {
      commit {
        status {
          contexts {
            id
            state
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
*/

const node/*: ConcreteRequest*/ = (function(){
var v0 = [
  {
    "kind": "LocalArgument",
    "name": "headOwner",
    "type": "String!",
    "defaultValue": null
  },
  {
    "kind": "LocalArgument",
    "name": "headName",
    "type": "String!",
    "defaultValue": null
  },
  {
    "kind": "LocalArgument",
    "name": "headRef",
    "type": "String!",
    "defaultValue": null
  },
  {
    "kind": "LocalArgument",
    "name": "first",
    "type": "Int!",
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
    "variableName": "headName"
  },
  {
    "kind": "Variable",
    "name": "owner",
    "variableName": "headOwner"
  }
],
v2 = [
  {
    "kind": "Variable",
    "name": "qualifiedName",
    "variableName": "headRef"
  }
],
v3 = [
  {
    "kind": "Variable",
    "name": "first",
    "variableName": "first"
  },
  {
    "kind": "Literal",
    "name": "states",
    "value": [
      "OPEN"
    ]
  }
],
v4 = {
  "kind": "ScalarField",
  "alias": null,
  "name": "totalCount",
  "args": null,
  "storageKey": null
},
v5 = {
  "kind": "ScalarField",
  "alias": null,
  "name": "title",
  "args": null,
  "storageKey": null
},
v6 = {
  "kind": "ScalarField",
  "alias": null,
  "name": "__typename",
  "args": null,
  "storageKey": null
},
v7 = {
  "kind": "ScalarField",
  "alias": null,
  "name": "login",
  "args": null,
  "storageKey": null
},
v8 = {
  "kind": "ScalarField",
  "alias": null,
  "name": "id",
  "args": null,
  "storageKey": null
},
v9 = {
  "kind": "ScalarField",
  "alias": null,
  "name": "name",
  "args": null,
  "storageKey": null
},
v10 = [
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
v11 = {
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
      "name": "hasNextPage",
      "args": null,
      "storageKey": null
    },
    {
      "kind": "ScalarField",
      "alias": null,
      "name": "endCursor",
      "args": null,
      "storageKey": null
    }
  ]
},
v12 = {
  "kind": "ScalarField",
  "alias": null,
  "name": "cursor",
  "args": null,
  "storageKey": null
},
v13 = {
  "kind": "ScalarField",
  "alias": null,
  "name": "status",
  "args": null,
  "storageKey": null
},
v14 = {
  "kind": "ScalarField",
  "alias": null,
  "name": "conclusion",
  "args": null,
  "storageKey": null
},
v15 = [
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
];
return {
  "kind": "Request",
  "fragment": {
    "kind": "Fragment",
    "name": "currentPullRequestContainerQuery",
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
            "alias": null,
            "name": "ref",
            "storageKey": null,
            "args": (v2/*: any*/),
            "concreteType": "Ref",
            "plural": false,
            "selections": [
              {
                "kind": "LinkedField",
                "alias": null,
                "name": "associatedPullRequests",
                "storageKey": null,
                "args": (v3/*: any*/),
                "concreteType": "PullRequestConnection",
                "plural": false,
                "selections": [
                  (v4/*: any*/),
                  {
                    "kind": "LinkedField",
                    "alias": null,
                    "name": "nodes",
                    "storageKey": null,
                    "args": null,
                    "concreteType": "PullRequest",
                    "plural": true,
                    "selections": [
                      {
                        "kind": "FragmentSpread",
                        "name": "issueishListController_results",
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
  "operation": {
    "kind": "Operation",
    "name": "currentPullRequestContainerQuery",
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
            "alias": null,
            "name": "ref",
            "storageKey": null,
            "args": (v2/*: any*/),
            "concreteType": "Ref",
            "plural": false,
            "selections": [
              {
                "kind": "LinkedField",
                "alias": null,
                "name": "associatedPullRequests",
                "storageKey": null,
                "args": (v3/*: any*/),
                "concreteType": "PullRequestConnection",
                "plural": false,
                "selections": [
                  (v4/*: any*/),
                  {
                    "kind": "LinkedField",
                    "alias": null,
                    "name": "nodes",
                    "storageKey": null,
                    "args": null,
                    "concreteType": "PullRequest",
                    "plural": true,
                    "selections": [
                      {
                        "kind": "ScalarField",
                        "alias": null,
                        "name": "number",
                        "args": null,
                        "storageKey": null
                      },
                      (v5/*: any*/),
                      {
                        "kind": "ScalarField",
                        "alias": null,
                        "name": "url",
                        "args": null,
                        "storageKey": null
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
                          (v6/*: any*/),
                          (v7/*: any*/),
                          {
                            "kind": "ScalarField",
                            "alias": null,
                            "name": "avatarUrl",
                            "args": null,
                            "storageKey": null
                          },
                          (v8/*: any*/)
                        ]
                      },
                      {
                        "kind": "ScalarField",
                        "alias": null,
                        "name": "createdAt",
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
                        "alias": null,
                        "name": "repository",
                        "storageKey": null,
                        "args": null,
                        "concreteType": "Repository",
                        "plural": false,
                        "selections": [
                          (v8/*: any*/),
                          (v9/*: any*/),
                          {
                            "kind": "LinkedField",
                            "alias": null,
                            "name": "owner",
                            "storageKey": null,
                            "args": null,
                            "concreteType": null,
                            "plural": false,
                            "selections": [
                              (v6/*: any*/),
                              (v7/*: any*/),
                              (v8/*: any*/)
                            ]
                          }
                        ]
                      },
                      {
                        "kind": "LinkedField",
                        "alias": null,
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
                            "name": "nodes",
                            "storageKey": null,
                            "args": null,
                            "concreteType": "PullRequestCommit",
                            "plural": true,
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
                                      {
                                        "kind": "LinkedField",
                                        "alias": null,
                                        "name": "contexts",
                                        "storageKey": null,
                                        "args": null,
                                        "concreteType": "StatusContext",
                                        "plural": true,
                                        "selections": [
                                          (v8/*: any*/),
                                          {
                                            "kind": "ScalarField",
                                            "alias": null,
                                            "name": "state",
                                            "args": null,
                                            "storageKey": null
                                          }
                                        ]
                                      },
                                      (v8/*: any*/)
                                    ]
                                  },
                                  (v8/*: any*/),
                                  {
                                    "kind": "LinkedField",
                                    "alias": null,
                                    "name": "checkSuites",
                                    "storageKey": null,
                                    "args": (v10/*: any*/),
                                    "concreteType": "CheckSuiteConnection",
                                    "plural": false,
                                    "selections": [
                                      (v11/*: any*/),
                                      {
                                        "kind": "LinkedField",
                                        "alias": null,
                                        "name": "edges",
                                        "storageKey": null,
                                        "args": null,
                                        "concreteType": "CheckSuiteEdge",
                                        "plural": true,
                                        "selections": [
                                          (v12/*: any*/),
                                          {
                                            "kind": "LinkedField",
                                            "alias": null,
                                            "name": "node",
                                            "storageKey": null,
                                            "args": null,
                                            "concreteType": "CheckSuite",
                                            "plural": false,
                                            "selections": [
                                              (v8/*: any*/),
                                              (v13/*: any*/),
                                              (v14/*: any*/),
                                              {
                                                "kind": "LinkedField",
                                                "alias": null,
                                                "name": "app",
                                                "storageKey": null,
                                                "args": null,
                                                "concreteType": "App",
                                                "plural": false,
                                                "selections": [
                                                  (v9/*: any*/),
                                                  (v8/*: any*/)
                                                ]
                                              },
                                              {
                                                "kind": "LinkedField",
                                                "alias": null,
                                                "name": "checkRuns",
                                                "storageKey": null,
                                                "args": (v15/*: any*/),
                                                "concreteType": "CheckRunConnection",
                                                "plural": false,
                                                "selections": [
                                                  (v11/*: any*/),
                                                  {
                                                    "kind": "LinkedField",
                                                    "alias": null,
                                                    "name": "edges",
                                                    "storageKey": null,
                                                    "args": null,
                                                    "concreteType": "CheckRunEdge",
                                                    "plural": true,
                                                    "selections": [
                                                      (v12/*: any*/),
                                                      {
                                                        "kind": "LinkedField",
                                                        "alias": null,
                                                        "name": "node",
                                                        "storageKey": null,
                                                        "args": null,
                                                        "concreteType": "CheckRun",
                                                        "plural": false,
                                                        "selections": [
                                                          (v8/*: any*/),
                                                          (v13/*: any*/),
                                                          (v14/*: any*/),
                                                          (v9/*: any*/),
                                                          (v5/*: any*/),
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
                                                          (v6/*: any*/)
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
                                                "args": (v15/*: any*/),
                                                "handle": "connection",
                                                "key": "CheckRunsAccumulator_checkRuns",
                                                "filters": null
                                              },
                                              (v6/*: any*/)
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
                                    "args": (v10/*: any*/),
                                    "handle": "connection",
                                    "key": "CheckSuiteAccumulator_checkSuites",
                                    "filters": null
                                  }
                                ]
                              },
                              (v8/*: any*/)
                            ]
                          }
                        ]
                      },
                      (v8/*: any*/)
                    ]
                  }
                ]
              },
              (v8/*: any*/)
            ]
          },
          (v8/*: any*/)
        ]
      }
    ]
  },
  "params": {
    "operationKind": "query",
    "name": "currentPullRequestContainerQuery",
    "id": null,
    "text": "query currentPullRequestContainerQuery(\n  $headOwner: String!\n  $headName: String!\n  $headRef: String!\n  $first: Int!\n  $checkSuiteCount: Int!\n  $checkSuiteCursor: String\n  $checkRunCount: Int!\n  $checkRunCursor: String\n) {\n  repository(owner: $headOwner, name: $headName) {\n    ref(qualifiedName: $headRef) {\n      associatedPullRequests(first: $first, states: [OPEN]) {\n        totalCount\n        nodes {\n          ...issueishListController_results_1oGSNs\n          id\n        }\n      }\n      id\n    }\n    id\n  }\n}\n\nfragment checkRunView_checkRun on CheckRun {\n  name\n  status\n  conclusion\n  title\n  summary\n  permalink\n  detailsUrl\n}\n\nfragment checkRunsAccumulator_checkSuite_Rvfr1 on CheckSuite {\n  id\n  checkRuns(first: $checkRunCount, after: $checkRunCursor) {\n    pageInfo {\n      hasNextPage\n      endCursor\n    }\n    edges {\n      cursor\n      node {\n        id\n        status\n        conclusion\n        ...checkRunView_checkRun\n        __typename\n      }\n    }\n  }\n}\n\nfragment checkSuiteView_checkSuite on CheckSuite {\n  app {\n    name\n    id\n  }\n  status\n  conclusion\n}\n\nfragment checkSuitesAccumulator_commit_1oGSNs on Commit {\n  id\n  checkSuites(first: $checkSuiteCount, after: $checkSuiteCursor) {\n    pageInfo {\n      hasNextPage\n      endCursor\n    }\n    edges {\n      cursor\n      node {\n        id\n        status\n        conclusion\n        ...checkSuiteView_checkSuite\n        ...checkRunsAccumulator_checkSuite_Rvfr1\n        __typename\n      }\n    }\n  }\n}\n\nfragment issueishListController_results_1oGSNs on PullRequest {\n  number\n  title\n  url\n  author {\n    __typename\n    login\n    avatarUrl\n    ... on Node {\n      id\n    }\n  }\n  createdAt\n  headRefName\n  repository {\n    id\n    name\n    owner {\n      __typename\n      login\n      id\n    }\n  }\n  commits(last: 1) {\n    nodes {\n      commit {\n        status {\n          contexts {\n            id\n            state\n          }\n          id\n        }\n        ...checkSuitesAccumulator_commit_1oGSNs\n        id\n      }\n      id\n    }\n  }\n}\n",
    "metadata": {}
  }
};
})();
// prettier-ignore
(node/*: any*/).hash = 'b571ac1d752d4d13bc8e9bdffedb0a5e';
module.exports = node;
