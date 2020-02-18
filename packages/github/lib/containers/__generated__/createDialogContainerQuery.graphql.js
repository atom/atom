/**
 * @flow
 * @relayHash 72a9fbd2efed6312f034405f54084c6f
 */

/* eslint-disable */

'use strict';

/*::
import type { ConcreteRequest } from 'relay-runtime';
type createDialogController_user$ref = any;
export type createDialogContainerQueryVariables = {|
  organizationCount: number,
  organizationCursor?: ?string,
|};
export type createDialogContainerQueryResponse = {|
  +viewer: {|
    +$fragmentRefs: createDialogController_user$ref
  |}
|};
export type createDialogContainerQuery = {|
  variables: createDialogContainerQueryVariables,
  response: createDialogContainerQueryResponse,
|};
*/


/*
query createDialogContainerQuery(
  $organizationCount: Int!
  $organizationCursor: String
) {
  viewer {
    ...createDialogController_user_12CDS5
    id
  }
}

fragment createDialogController_user_12CDS5 on User {
  id
  ...repositoryHomeSelectionView_user_12CDS5
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
v1 = {
  "kind": "ScalarField",
  "alias": null,
  "name": "id",
  "args": null,
  "storageKey": null
},
v2 = {
  "kind": "ScalarField",
  "alias": null,
  "name": "login",
  "args": null,
  "storageKey": null
},
v3 = {
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
v4 = [
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
    "name": "createDialogContainerQuery",
    "type": "Query",
    "metadata": null,
    "argumentDefinitions": (v0/*: any*/),
    "selections": [
      {
        "kind": "LinkedField",
        "alias": null,
        "name": "viewer",
        "storageKey": null,
        "args": null,
        "concreteType": "User",
        "plural": false,
        "selections": [
          {
            "kind": "FragmentSpread",
            "name": "createDialogController_user",
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
  },
  "operation": {
    "kind": "Operation",
    "name": "createDialogContainerQuery",
    "argumentDefinitions": (v0/*: any*/),
    "selections": [
      {
        "kind": "LinkedField",
        "alias": null,
        "name": "viewer",
        "storageKey": null,
        "args": null,
        "concreteType": "User",
        "plural": false,
        "selections": [
          (v1/*: any*/),
          (v2/*: any*/),
          (v3/*: any*/),
          {
            "kind": "LinkedField",
            "alias": null,
            "name": "organizations",
            "storageKey": null,
            "args": (v4/*: any*/),
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
                      (v1/*: any*/),
                      (v2/*: any*/),
                      (v3/*: any*/),
                      {
                        "kind": "ScalarField",
                        "alias": null,
                        "name": "viewerCanCreateRepositories",
                        "args": null,
                        "storageKey": null
                      },
                      {
                        "kind": "ScalarField",
                        "alias": null,
                        "name": "__typename",
                        "args": null,
                        "storageKey": null
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
            "name": "organizations",
            "args": (v4/*: any*/),
            "handle": "connection",
            "key": "RepositoryHomeSelectionView_organizations",
            "filters": null
          }
        ]
      }
    ]
  },
  "params": {
    "operationKind": "query",
    "name": "createDialogContainerQuery",
    "id": null,
    "text": "query createDialogContainerQuery(\n  $organizationCount: Int!\n  $organizationCursor: String\n) {\n  viewer {\n    ...createDialogController_user_12CDS5\n    id\n  }\n}\n\nfragment createDialogController_user_12CDS5 on User {\n  id\n  ...repositoryHomeSelectionView_user_12CDS5\n}\n\nfragment repositoryHomeSelectionView_user_12CDS5 on User {\n  id\n  login\n  avatarUrl(size: 24)\n  organizations(first: $organizationCount, after: $organizationCursor) {\n    pageInfo {\n      hasNextPage\n      endCursor\n    }\n    edges {\n      cursor\n      node {\n        id\n        login\n        avatarUrl(size: 24)\n        viewerCanCreateRepositories\n        __typename\n      }\n    }\n  }\n}\n",
    "metadata": {}
  }
};
})();
// prettier-ignore
(node/*: any*/).hash = '862b8ec3127c9a52e9a54020afa47792';
module.exports = node;
