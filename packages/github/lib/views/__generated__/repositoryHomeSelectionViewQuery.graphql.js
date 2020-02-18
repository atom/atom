/**
 * @flow
 * @relayHash 7b497054797ead3f15d4ce610e26e24c
 */

/* eslint-disable */

'use strict';

/*::
import type { ConcreteRequest } from 'relay-runtime';
type repositoryHomeSelectionView_user$ref = any;
export type repositoryHomeSelectionViewQueryVariables = {|
  id: string,
  organizationCount: number,
  organizationCursor?: ?string,
|};
export type repositoryHomeSelectionViewQueryResponse = {|
  +node: ?{|
    +$fragmentRefs: repositoryHomeSelectionView_user$ref
  |}
|};
export type repositoryHomeSelectionViewQuery = {|
  variables: repositoryHomeSelectionViewQueryVariables,
  response: repositoryHomeSelectionViewQueryResponse,
|};
*/


/*
query repositoryHomeSelectionViewQuery(
  $id: ID!
  $organizationCount: Int!
  $organizationCursor: String
) {
  node(id: $id) {
    __typename
    ... on User {
      ...repositoryHomeSelectionView_user_12CDS5
    }
    id
  }
}

fragment repositoryHomeSelectionView_user_12CDS5 on User {
  id
  login
  avatarUrl(size: 24)
  organizations(first: $organizationCount, after: $organizationCursor) {
    pageInfo {
      hasNextPage
      endCursor
    }
    edges {
      cursor
      node {
        id
        login
        avatarUrl(size: 24)
        viewerCanCreateRepositories
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
    "name": "id",
    "type": "ID!",
    "defaultValue": null
  },
  {
    "kind": "LocalArgument",
    "name": "organizationCount",
    "type": "Int!",
    "defaultValue": null
  },
  {
    "kind": "LocalArgument",
    "name": "organizationCursor",
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
  "name": "login",
  "args": null,
  "storageKey": null
},
v5 = {
  "kind": "ScalarField",
  "alias": null,
  "name": "avatarUrl",
  "args": [
    {
      "kind": "Literal",
      "name": "size",
      "value": 24
    }
  ],
  "storageKey": "avatarUrl(size:24)"
},
v6 = [
  {
    "kind": "Variable",
    "name": "after",
    "variableName": "organizationCursor"
  },
  {
    "kind": "Variable",
    "name": "first",
    "variableName": "organizationCount"
  }
];
return {
  "kind": "Request",
  "fragment": {
    "kind": "Fragment",
    "name": "repositoryHomeSelectionViewQuery",
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
            "type": "User",
            "selections": [
              {
                "kind": "FragmentSpread",
                "name": "repositoryHomeSelectionView_user",
                "args": [
                  {
                    "kind": "Variable",
                    "name": "organizationCount",
                    "variableName": "organizationCount"
                  },
                  {
                    "kind": "Variable",
                    "name": "organizationCursor",
                    "variableName": "organizationCursor"
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
    "name": "repositoryHomeSelectionViewQuery",
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
            "type": "User",
            "selections": [
              (v4/*: any*/),
              (v5/*: any*/),
              {
                "kind": "LinkedField",
                "alias": null,
                "name": "organizations",
                "storageKey": null,
                "args": (v6/*: any*/),
                "concreteType": "OrganizationConnection",
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
                  {
                    "kind": "LinkedField",
                    "alias": null,
                    "name": "edges",
                    "storageKey": null,
                    "args": null,
                    "concreteType": "OrganizationEdge",
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
                        "concreteType": "Organization",
                        "plural": false,
                        "selections": [
                          (v3/*: any*/),
                          (v4/*: any*/),
                          (v5/*: any*/),
                          {
                            "kind": "ScalarField",
                            "alias": null,
                            "name": "viewerCanCreateRepositories",
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
                "name": "organizations",
                "args": (v6/*: any*/),
                "handle": "connection",
                "key": "RepositoryHomeSelectionView_organizations",
                "filters": null
              }
            ]
          }
        ]
      }
    ]
  },
  "params": {
    "operationKind": "query",
    "name": "repositoryHomeSelectionViewQuery",
    "id": null,
    "text": "query repositoryHomeSelectionViewQuery(\n  $id: ID!\n  $organizationCount: Int!\n  $organizationCursor: String\n) {\n  node(id: $id) {\n    __typename\n    ... on User {\n      ...repositoryHomeSelectionView_user_12CDS5\n    }\n    id\n  }\n}\n\nfragment repositoryHomeSelectionView_user_12CDS5 on User {\n  id\n  login\n  avatarUrl(size: 24)\n  organizations(first: $organizationCount, after: $organizationCursor) {\n    pageInfo {\n      hasNextPage\n      endCursor\n    }\n    edges {\n      cursor\n      node {\n        id\n        login\n        avatarUrl(size: 24)\n        viewerCanCreateRepositories\n        __typename\n      }\n    }\n  }\n}\n",
    "metadata": {}
  }
};
})();
// prettier-ignore
(node/*: any*/).hash = '67e7843e3ff792e86e979cc948929ea3';
module.exports = node;
