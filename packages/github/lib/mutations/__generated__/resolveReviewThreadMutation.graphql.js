/**
 * @flow
 * @relayHash 75200195d76356be6d31a71143dcd6a8
 */

/* eslint-disable */

'use strict';

/*::
import type { ConcreteRequest } from 'relay-runtime';
export type ResolveReviewThreadInput = {|
  threadId: string,
  clientMutationId?: ?string,
|};
export type resolveReviewThreadMutationVariables = {|
  input: ResolveReviewThreadInput
|};
export type resolveReviewThreadMutationResponse = {|
  +resolveReviewThread: ?{|
    +thread: ?{|
      +id: string,
      +isResolved: boolean,
      +viewerCanResolve: boolean,
      +viewerCanUnresolve: boolean,
      +resolvedBy: ?{|
        +id: string,
        +login: string,
      |},
    |}
  |}
|};
export type resolveReviewThreadMutation = {|
  variables: resolveReviewThreadMutationVariables,
  response: resolveReviewThreadMutationResponse,
|};
*/


/*
mutation resolveReviewThreadMutation(
  $input: ResolveReviewThreadInput!
) {
  resolveReviewThread(input: $input) {
    thread {
      id
      isResolved
      viewerCanResolve
      viewerCanUnresolve
      resolvedBy {
        id
        login
      }
    }
  }
}
*/

const node/*: ConcreteRequest*/ = (function(){
var v0 = [
  {
    "kind": "LocalArgument",
    "name": "input",
    "type": "ResolveReviewThreadInput!",
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
v2 = [
  {
    "kind": "LinkedField",
    "alias": null,
    "name": "resolveReviewThread",
    "storageKey": null,
    "args": [
      {
        "kind": "Variable",
        "name": "input",
        "variableName": "input"
      }
    ],
    "concreteType": "ResolveReviewThreadPayload",
    "plural": false,
    "selections": [
      {
        "kind": "LinkedField",
        "alias": null,
        "name": "thread",
        "storageKey": null,
        "args": null,
        "concreteType": "PullRequestReviewThread",
        "plural": false,
        "selections": [
          (v1/*: any*/),
          {
            "kind": "ScalarField",
            "alias": null,
            "name": "isResolved",
            "args": null,
            "storageKey": null
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
            "name": "resolvedBy",
            "storageKey": null,
            "args": null,
            "concreteType": "User",
            "plural": false,
            "selections": [
              (v1/*: any*/),
              {
                "kind": "ScalarField",
                "alias": null,
                "name": "login",
                "args": null,
                "storageKey": null
              }
            ]
          }
        ]
      }
    ]
  }
];
return {
  "kind": "Request",
  "fragment": {
    "kind": "Fragment",
    "name": "resolveReviewThreadMutation",
    "type": "Mutation",
    "metadata": null,
    "argumentDefinitions": (v0/*: any*/),
    "selections": (v2/*: any*/)
  },
  "operation": {
    "kind": "Operation",
    "name": "resolveReviewThreadMutation",
    "argumentDefinitions": (v0/*: any*/),
    "selections": (v2/*: any*/)
  },
  "params": {
    "operationKind": "mutation",
    "name": "resolveReviewThreadMutation",
    "id": null,
    "text": "mutation resolveReviewThreadMutation(\n  $input: ResolveReviewThreadInput!\n) {\n  resolveReviewThread(input: $input) {\n    thread {\n      id\n      isResolved\n      viewerCanResolve\n      viewerCanUnresolve\n      resolvedBy {\n        id\n        login\n      }\n    }\n  }\n}\n",
    "metadata": {}
  }
};
})();
// prettier-ignore
(node/*: any*/).hash = '6947ef6710d494dc52fba1a5b532cd76';
module.exports = node;
