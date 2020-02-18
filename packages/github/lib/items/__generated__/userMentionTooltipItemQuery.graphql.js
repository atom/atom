/**
 * @flow
 * @relayHash a61e817b6d5e19dae9a8a7f4f4e156fa
 */

/* eslint-disable */

'use strict';

/*::
import type { ConcreteRequest } from 'relay-runtime';
type userMentionTooltipContainer_repositoryOwner$ref = any;
export type userMentionTooltipItemQueryVariables = {|
  username: string
|};
export type userMentionTooltipItemQueryResponse = {|
  +repositoryOwner: ?{|
    +$fragmentRefs: userMentionTooltipContainer_repositoryOwner$ref
  |}
|};
export type userMentionTooltipItemQuery = {|
  variables: userMentionTooltipItemQueryVariables,
  response: userMentionTooltipItemQueryResponse,
|};
*/


/*
query userMentionTooltipItemQuery(
  $username: String!
) {
  repositoryOwner(login: $username) {
    __typename
    ...userMentionTooltipContainer_repositoryOwner
    id
  }
}

fragment userMentionTooltipContainer_repositoryOwner on RepositoryOwner {
  login
  avatarUrl
  repositories {
    totalCount
  }
  ... on User {
    company
  }
  ... on Organization {
    membersWithRole {
      totalCount
    }
  }
}
*/

const node/*: ConcreteRequest*/ = (function(){
var v0 = [
  {
    "kind": "LocalArgument",
    "name": "username",
    "type": "String!",
    "defaultValue": null
  }
],
v1 = [
  {
    "kind": "Variable",
    "name": "login",
    "variableName": "username"
  }
],
v2 = [
  {
    "kind": "ScalarField",
    "alias": null,
    "name": "totalCount",
    "args": null,
    "storageKey": null
  }
];
return {
  "kind": "Request",
  "fragment": {
    "kind": "Fragment",
    "name": "userMentionTooltipItemQuery",
    "type": "Query",
    "metadata": null,
    "argumentDefinitions": (v0/*: any*/),
    "selections": [
      {
        "kind": "LinkedField",
        "alias": null,
        "name": "repositoryOwner",
        "storageKey": null,
        "args": (v1/*: any*/),
        "concreteType": null,
        "plural": false,
        "selections": [
          {
            "kind": "FragmentSpread",
            "name": "userMentionTooltipContainer_repositoryOwner",
            "args": null
          }
        ]
      }
    ]
  },
  "operation": {
    "kind": "Operation",
    "name": "userMentionTooltipItemQuery",
    "argumentDefinitions": (v0/*: any*/),
    "selections": [
      {
        "kind": "LinkedField",
        "alias": null,
        "name": "repositoryOwner",
        "storageKey": null,
        "args": (v1/*: any*/),
        "concreteType": null,
        "plural": false,
        "selections": [
          {
            "kind": "ScalarField",
            "alias": null,
            "name": "__typename",
            "args": null,
            "storageKey": null
          },
          {
            "kind": "ScalarField",
            "alias": null,
            "name": "login",
            "args": null,
            "storageKey": null
          },
          {
            "kind": "ScalarField",
            "alias": null,
            "name": "avatarUrl",
            "args": null,
            "storageKey": null
          },
          {
            "kind": "LinkedField",
            "alias": null,
            "name": "repositories",
            "storageKey": null,
            "args": null,
            "concreteType": "RepositoryConnection",
            "plural": false,
            "selections": (v2/*: any*/)
          },
          {
            "kind": "ScalarField",
            "alias": null,
            "name": "id",
            "args": null,
            "storageKey": null
          },
          {
            "kind": "InlineFragment",
            "type": "User",
            "selections": [
              {
                "kind": "ScalarField",
                "alias": null,
                "name": "company",
                "args": null,
                "storageKey": null
              }
            ]
          },
          {
            "kind": "InlineFragment",
            "type": "Organization",
            "selections": [
              {
                "kind": "LinkedField",
                "alias": null,
                "name": "membersWithRole",
                "storageKey": null,
                "args": null,
                "concreteType": "OrganizationMemberConnection",
                "plural": false,
                "selections": (v2/*: any*/)
              }
            ]
          }
        ]
      }
    ]
  },
  "params": {
    "operationKind": "query",
    "name": "userMentionTooltipItemQuery",
    "id": null,
    "text": "query userMentionTooltipItemQuery(\n  $username: String!\n) {\n  repositoryOwner(login: $username) {\n    __typename\n    ...userMentionTooltipContainer_repositoryOwner\n    id\n  }\n}\n\nfragment userMentionTooltipContainer_repositoryOwner on RepositoryOwner {\n  login\n  avatarUrl\n  repositories {\n    totalCount\n  }\n  ... on User {\n    company\n  }\n  ... on Organization {\n    membersWithRole {\n      totalCount\n    }\n  }\n}\n",
    "metadata": {}
  }
};
})();
// prettier-ignore
(node/*: any*/).hash = 'c0e8b6f6d3028f3f2679ce9e1486981e';
module.exports = node;
