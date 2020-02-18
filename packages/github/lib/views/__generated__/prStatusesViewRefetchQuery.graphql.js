/**
 * @flow
 * @relayHash 0464a2c670f74f89527619b5422aff65
 */

/* eslint-disable */

'use strict';

/*::
import type { ConcreteRequest } from 'relay-runtime';
type prStatusesView_pullRequest$ref = any;
export type prStatusesViewRefetchQueryVariables = {|
  id: string,
  checkSuiteCount: number,
  checkSuiteCursor?: ?string,
  checkRunCount: number,
  checkRunCursor?: ?string,
|};
export type prStatusesViewRefetchQueryResponse = {|
  +node: ?{|
    +$fragmentRefs: prStatusesView_pullRequest$ref
  |}
|};
export type prStatusesViewRefetchQuery = {|
  variables: prStatusesViewRefetchQueryVariables,
  response: prStatusesViewRefetchQueryResponse,
|};
*/


/*
query prStatusesViewRefetchQuery(
  $id: ID!
  $checkSuiteCount: Int!
  $checkSuiteCursor: String
  $checkRunCount: Int!
  $checkRunCursor: String
) {
  node(id: $id) {
    __typename
    ... on PullRequest {
      ...prStatusesView_pullRequest_1oGSNs
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
*/

const node/*: ConcreteRequest*/ = (function(){
var v0 = [
  {
    "kind": "LocalArgument",
    "name": "id",
    "type": "ID!",
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
    "variableName": "id"
  }
],
v2 = {
  "kind": "ScalarField",
  "alias": null,
  "name": "__typename",
  "args": null,
  "storageKey": null
},
v3 = {
  "kind": "ScalarField",
  "alias": null,
  "name": "id",
  "args": null,
  "storageKey": null
},
v4 = {
  "kind": "ScalarField",
  "alias": null,
  "name": "state",
  "args": null,
  "storageKey": null
},
v5 = [
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
v6 = {
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
v7 = {
  "kind": "ScalarField",
  "alias": null,
  "name": "cursor",
  "args": null,
  "storageKey": null
},
v8 = {
  "kind": "ScalarField",
  "alias": null,
  "name": "status",
  "args": null,
  "storageKey": null
},
v9 = {
  "kind": "ScalarField",
  "alias": null,
  "name": "conclusion",
  "args": null,
  "storageKey": null
},
v10 = {
  "kind": "ScalarField",
  "alias": null,
  "name": "name",
  "args": null,
  "storageKey": null
},
v11 = [
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
    "name": "prStatusesViewRefetchQuery",
    "type": "Query",
    "metadata": null,
    "argumentDefinitions": (v0/*: any*/),
    "selections": [
      {
        "kind": "LinkedField",
        "alias": null,
        "name": "node",
        "storageKey": null,
        "args": (v1/*: any*/),
        "concreteType": null,
        "plural": false,
        "selections": [
          {
            "kind": "InlineFragment",
            "type": "PullRequest",
            "selections": [
              {
                "kind": "FragmentSpread",
                "name": "prStatusesView_pullRequest",
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
  },
  "operation": {
    "kind": "Operation",
    "name": "prStatusesViewRefetchQuery",
    "argumentDefinitions": (v0/*: any*/),
    "selections": [
      {
        "kind": "LinkedField",
        "alias": null,
        "name": "node",
        "storageKey": null,
        "args": (v1/*: any*/),
        "concreteType": null,
        "plural": false,
        "selections": [
          (v2/*: any*/),
          (v3/*: any*/),
          {
            "kind": "InlineFragment",
            "type": "PullRequest",
            "selections": [
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
                                  (v4/*: any*/),
                                  {
                                    "kind": "LinkedField",
                                    "alias": null,
                                    "name": "contexts",
                                    "storageKey": null,
                                    "args": null,
                                    "concreteType": "StatusContext",
                                    "plural": true,
                                    "selections": [
                                      (v3/*: any*/),
                                      (v4/*: any*/),
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
                                  (v3/*: any*/)
                                ]
                              },
                              (v3/*: any*/),
                              {
                                "kind": "LinkedField",
                                "alias": null,
                                "name": "checkSuites",
                                "storageKey": null,
                                "args": (v5/*: any*/),
                                "concreteType": "CheckSuiteConnection",
                                "plural": false,
                                "selections": [
                                  (v6/*: any*/),
                                  {
                                    "kind": "LinkedField",
                                    "alias": null,
                                    "name": "edges",
                                    "storageKey": null,
                                    "args": null,
                                    "concreteType": "CheckSuiteEdge",
                                    "plural": true,
                                    "selections": [
                                      (v7/*: any*/),
                                      {
                                        "kind": "LinkedField",
                                        "alias": null,
                                        "name": "node",
                                        "storageKey": null,
                                        "args": null,
                                        "concreteType": "CheckSuite",
                                        "plural": false,
                                        "selections": [
                                          (v3/*: any*/),
                                          (v8/*: any*/),
                                          (v9/*: any*/),
                                          {
                                            "kind": "LinkedField",
                                            "alias": null,
                                            "name": "app",
                                            "storageKey": null,
                                            "args": null,
                                            "concreteType": "App",
                                            "plural": false,
                                            "selections": [
                                              (v10/*: any*/),
                                              (v3/*: any*/)
                                            ]
                                          },
                                          {
                                            "kind": "LinkedField",
                                            "alias": null,
                                            "name": "checkRuns",
                                            "storageKey": null,
                                            "args": (v11/*: any*/),
                                            "concreteType": "CheckRunConnection",
                                            "plural": false,
                                            "selections": [
                                              (v6/*: any*/),
                                              {
                                                "kind": "LinkedField",
                                                "alias": null,
                                                "name": "edges",
                                                "storageKey": null,
                                                "args": null,
                                                "concreteType": "CheckRunEdge",
                                                "plural": true,
                                                "selections": [
                                                  (v7/*: any*/),
                                                  {
                                                    "kind": "LinkedField",
                                                    "alias": null,
                                                    "name": "node",
                                                    "storageKey": null,
                                                    "args": null,
                                                    "concreteType": "CheckRun",
                                                    "plural": false,
                                                    "selections": [
                                                      (v3/*: any*/),
                                                      (v8/*: any*/),
                                                      (v9/*: any*/),
                                                      (v10/*: any*/),
                                                      {
                                                        "kind": "ScalarField",
                                                        "alias": null,
                                                        "name": "title",
                                                        "args": null,
                                                        "storageKey": null
                                                      },
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
                                                      (v2/*: any*/)
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
                                            "args": (v11/*: any*/),
                                            "handle": "connection",
                                            "key": "CheckRunsAccumulator_checkRuns",
                                            "filters": null
                                          },
                                          (v2/*: any*/)
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
                                "args": (v5/*: any*/),
                                "handle": "connection",
                                "key": "CheckSuiteAccumulator_checkSuites",
                                "filters": null
                              }
                            ]
                          },
                          (v3/*: any*/)
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
  "params": {
    "operationKind": "query",
    "name": "prStatusesViewRefetchQuery",
    "id": null,
    "text": "query prStatusesViewRefetchQuery(\n  $id: ID!\n  $checkSuiteCount: Int!\n  $checkSuiteCursor: String\n  $checkRunCount: Int!\n  $checkRunCursor: String\n) {\n  node(id: $id) {\n    __typename\n    ... on PullRequest {\n      ...prStatusesView_pullRequest_1oGSNs\n    }\n    id\n  }\n}\n\nfragment checkRunView_checkRun on CheckRun {\n  name\n  status\n  conclusion\n  title\n  summary\n  permalink\n  detailsUrl\n}\n\nfragment checkRunsAccumulator_checkSuite_Rvfr1 on CheckSuite {\n  id\n  checkRuns(first: $checkRunCount, after: $checkRunCursor) {\n    pageInfo {\n      hasNextPage\n      endCursor\n    }\n    edges {\n      cursor\n      node {\n        id\n        status\n        conclusion\n        ...checkRunView_checkRun\n        __typename\n      }\n    }\n  }\n}\n\nfragment checkSuiteView_checkSuite on CheckSuite {\n  app {\n    name\n    id\n  }\n  status\n  conclusion\n}\n\nfragment checkSuitesAccumulator_commit_1oGSNs on Commit {\n  id\n  checkSuites(first: $checkSuiteCount, after: $checkSuiteCursor) {\n    pageInfo {\n      hasNextPage\n      endCursor\n    }\n    edges {\n      cursor\n      node {\n        id\n        status\n        conclusion\n        ...checkSuiteView_checkSuite\n        ...checkRunsAccumulator_checkSuite_Rvfr1\n        __typename\n      }\n    }\n  }\n}\n\nfragment prStatusContextView_context on StatusContext {\n  context\n  description\n  state\n  targetUrl\n}\n\nfragment prStatusesView_pullRequest_1oGSNs on PullRequest {\n  id\n  recentCommits: commits(last: 1) {\n    edges {\n      node {\n        commit {\n          status {\n            state\n            contexts {\n              id\n              state\n              ...prStatusContextView_context\n            }\n            id\n          }\n          ...checkSuitesAccumulator_commit_1oGSNs\n          id\n        }\n        id\n      }\n    }\n  }\n}\n",
    "metadata": {}
  }
};
})();
// prettier-ignore
(node/*: any*/).hash = '34c4cfc61df6413f34a5efa61768cd48';
module.exports = node;
