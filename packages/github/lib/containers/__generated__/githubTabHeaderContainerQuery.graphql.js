/**
 * @flow
 * @relayHash 180d6bab8f919e61ddfec71b206e25a5
 */

/* eslint-disable */

'use strict';

/*::
import type { ConcreteRequest } from 'relay-runtime';
export type githubTabHeaderContainerQueryVariables = {||};
export type githubTabHeaderContainerQueryResponse = {|
  +viewer: {|
    +name: ?string,
    +email: string,
    +avatarUrl: any,
    +login: string,
  |}
|};
export type githubTabHeaderContainerQuery = {|
  variables: githubTabHeaderContainerQueryVariables,
  response: githubTabHeaderContainerQueryResponse,
|};
*/


/*
query githubTabHeaderContainerQuery {
  viewer {
    name
    email
    avatarUrl
    login
    id
  }
}
*/

const node/*: ConcreteRequest*/ = (function(){
var v0 = {
  "kind": "ScalarField",
  "alias": null,
  "name": "name",
  "args": null,
  "storageKey": null
},
v1 = {
  "kind": "ScalarField",
  "alias": null,
  "name": "email",
  "args": null,
  "storageKey": null
},
v2 = {
  "kind": "ScalarField",
  "alias": null,
  "name": "avatarUrl",
  "args": null,
  "storageKey": null
},
v3 = {
  "kind": "ScalarField",
  "alias": null,
  "name": "login",
  "args": null,
  "storageKey": null
};
return {
  "kind": "Request",
  "fragment": {
    "kind": "Fragment",
    "name": "githubTabHeaderContainerQuery",
    "type": "Query",
    "metadata": null,
    "argumentDefinitions": [],
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
          (v0/*: any*/),
          (v1/*: any*/),
          (v2/*: any*/),
          (v3/*: any*/)
        ]
      }
    ]
  },
  "operation": {
    "kind": "Operation",
    "name": "githubTabHeaderContainerQuery",
    "argumentDefinitions": [],
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
          (v0/*: any*/),
          (v1/*: any*/),
          (v2/*: any*/),
          (v3/*: any*/),
          {
            "kind": "ScalarField",
            "alias": null,
            "name": "id",
            "args": null,
            "storageKey": null
          }
        ]
      }
    ]
  },
  "params": {
    "operationKind": "query",
    "name": "githubTabHeaderContainerQuery",
    "id": null,
    "text": "query githubTabHeaderContainerQuery {\n  viewer {\n    name\n    email\n    avatarUrl\n    login\n    id\n  }\n}\n",
    "metadata": {}
  }
};
})();
// prettier-ignore
(node/*: any*/).hash = '003bcc6b15469f788437eba2b4ce780b';
module.exports = node;
