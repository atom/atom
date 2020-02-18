/**
 * @flow
 * @relayHash f4ea156db8d2e5b7488028bf9c4607dd
 */

/* eslint-disable */

'use strict';

/*::
import type { ConcreteRequest } from 'relay-runtime';
type issueishTooltipContainer_resource$ref = any;
export type issueishTooltipItemQueryVariables = {|
  issueishUrl: any
|};
export type issueishTooltipItemQueryResponse = {|
  +resource: ?{|
    +$fragmentRefs: issueishTooltipContainer_resource$ref
  |}
|};
export type issueishTooltipItemQuery = {|
  variables: issueishTooltipItemQueryVariables,
  response: issueishTooltipItemQueryResponse,
|};
*/


/*
query issueishTooltipItemQuery(
  $issueishUrl: URI!
) {
  resource(url: $issueishUrl) {
    __typename
    ...issueishTooltipContainer_resource
    ... on Node {
      id
    }
  }
}

fragment issueishTooltipContainer_resource on UniformResourceLocatable {
  __typename
  ... on Issue {
    state
    number
    title
    repository {
      name
      owner {
        __typename
        login
        id
      }
      id
    }
    author {
      __typename
      login
      avatarUrl
      ... on Node {
        id
      }
    }
  }
  ... on PullRequest {
    state
    number
    title
    repository {
      name
      owner {
        __typename
        login
        id
      }
      id
    }
    author {
      __typename
      login
      avatarUrl
      ... on Node {
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
    "name": "issueishUrl",
    "type": "URI!",
    "defaultValue": null
  }
],
v1 = [
  {
    "kind": "Variable",
    "name": "url",
    "variableName": "issueishUrl"
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
v5 = [
  {
    "kind": "ScalarField",
    "alias": null,
    "name": "state",
    "args": null,
    "storageKey": null
  },
  {
    "kind": "ScalarField",
    "alias": null,
    "name": "number",
    "args": null,
    "storageKey": null
  },
  {
    "kind": "ScalarField",
    "alias": null,
    "name": "title",
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
      {
        "kind": "ScalarField",
        "alias": null,
        "name": "name",
        "args": null,
        "storageKey": null
      },
      {
        "kind": "LinkedField",
        "alias": null,
        "name": "owner",
        "storageKey": null,
        "args": null,
        "concreteType": null,
        "plural": false,
        "selections": [
          (v2/*: any*/),
          (v4/*: any*/),
          (v3/*: any*/)
        ]
      },
      (v3/*: any*/)
    ]
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
      (v2/*: any*/),
      (v4/*: any*/),
      {
        "kind": "ScalarField",
        "alias": null,
        "name": "avatarUrl",
        "args": null,
        "storageKey": null
      },
      (v3/*: any*/)
    ]
  }
];
return {
  "kind": "Request",
  "fragment": {
    "kind": "Fragment",
    "name": "issueishTooltipItemQuery",
    "type": "Query",
    "metadata": null,
    "argumentDefinitions": (v0/*: any*/),
    "selections": [
      {
        "kind": "LinkedField",
        "alias": null,
        "name": "resource",
        "storageKey": null,
        "args": (v1/*: any*/),
        "concreteType": null,
        "plural": false,
        "selections": [
          {
            "kind": "FragmentSpread",
            "name": "issueishTooltipContainer_resource",
            "args": null
          }
        ]
      }
    ]
  },
  "operation": {
    "kind": "Operation",
    "name": "issueishTooltipItemQuery",
    "argumentDefinitions": (v0/*: any*/),
    "selections": [
      {
        "kind": "LinkedField",
        "alias": null,
        "name": "resource",
        "storageKey": null,
        "args": (v1/*: any*/),
        "concreteType": null,
        "plural": false,
        "selections": [
          (v2/*: any*/),
          (v3/*: any*/),
          {
            "kind": "InlineFragment",
            "type": "Issue",
            "selections": (v5/*: any*/)
          },
          {
            "kind": "InlineFragment",
            "type": "PullRequest",
            "selections": (v5/*: any*/)
          }
        ]
      }
    ]
  },
  "params": {
    "operationKind": "query",
    "name": "issueishTooltipItemQuery",
    "id": null,
    "text": "query issueishTooltipItemQuery(\n  $issueishUrl: URI!\n) {\n  resource(url: $issueishUrl) {\n    __typename\n    ...issueishTooltipContainer_resource\n    ... on Node {\n      id\n    }\n  }\n}\n\nfragment issueishTooltipContainer_resource on UniformResourceLocatable {\n  __typename\n  ... on Issue {\n    state\n    number\n    title\n    repository {\n      name\n      owner {\n        __typename\n        login\n        id\n      }\n      id\n    }\n    author {\n      __typename\n      login\n      avatarUrl\n      ... on Node {\n        id\n      }\n    }\n  }\n  ... on PullRequest {\n    state\n    number\n    title\n    repository {\n      name\n      owner {\n        __typename\n        login\n        id\n      }\n      id\n    }\n    author {\n      __typename\n      login\n      avatarUrl\n      ... on Node {\n        id\n      }\n    }\n  }\n}\n",
    "metadata": {}
  }
};
})();
// prettier-ignore
(node/*: any*/).hash = '8e6b32b5cdcdd3debccc7adaa2b4e82c';
module.exports = node;
