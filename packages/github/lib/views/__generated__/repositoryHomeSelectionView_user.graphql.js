/**
 * @flow
 */

/* eslint-disable */

'use strict';

/*::
import type { ReaderFragment } from 'relay-runtime';
import type { FragmentReference } from "relay-runtime";
declare export opaque type repositoryHomeSelectionView_user$ref: FragmentReference;
declare export opaque type repositoryHomeSelectionView_user$fragmentType: repositoryHomeSelectionView_user$ref;
export type repositoryHomeSelectionView_user = {|
  +id: string,
  +login: string,
  +avatarUrl: any,
  +organizations: {|
    +pageInfo: {|
      +hasNextPage: boolean,
      +endCursor: ?string,
    |},
    +edges: ?$ReadOnlyArray<?{|
      +cursor: string,
      +node: ?{|
        +id: string,
        +login: string,
        +avatarUrl: any,
        +viewerCanCreateRepositories: boolean,
      |},
    |}>,
  |},
  +$refType: repositoryHomeSelectionView_user$ref,
|};
export type repositoryHomeSelectionView_user$data = repositoryHomeSelectionView_user;
export type repositoryHomeSelectionView_user$key = {
  +$data?: repositoryHomeSelectionView_user$data,
  +$fragmentRefs: repositoryHomeSelectionView_user$ref,
};
*/


const node/*: ReaderFragment*/ = (function(){
var v0 = {
  "kind": "ScalarField",
  "alias": null,
  "name": "id",
  "args": null,
  "storageKey": null
},
v1 = {
  "kind": "ScalarField",
  "alias": null,
  "name": "login",
  "args": null,
  "storageKey": null
},
v2 = {
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
};
return {
  "kind": "Fragment",
  "name": "repositoryHomeSelectionView_user",
  "type": "User",
  "metadata": {
    "connection": [
      {
        "count": "organizationCount",
        "cursor": "organizationCursor",
        "direction": "forward",
        "path": [
          "organizations"
        ]
      }
    ]
  },
  "argumentDefinitions": [
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
  "selections": [
    (v0/*: any*/),
    (v1/*: any*/),
    (v2/*: any*/),
    {
      "kind": "LinkedField",
      "alias": "organizations",
      "name": "__RepositoryHomeSelectionView_organizations_connection",
      "storageKey": null,
      "args": null,
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
                (v0/*: any*/),
                (v1/*: any*/),
                (v2/*: any*/),
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
    }
  ]
};
})();
// prettier-ignore
(node/*: any*/).hash = '11a1f1d0eac32bff0a3371217c0eede3';
module.exports = node;
