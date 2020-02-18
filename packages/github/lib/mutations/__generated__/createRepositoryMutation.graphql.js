/**
 * @flow
 * @relayHash f8963f231e08ebd4d2cffd1223e19770
 */

/* eslint-disable */

'use strict';

/*::
import type { ConcreteRequest } from 'relay-runtime';
export type RepositoryVisibility = "INTERNAL" | "PRIVATE" | "PUBLIC" | "%future added value";
export type CreateRepositoryInput = {|
  name: string,
  ownerId?: ?string,
  description?: ?string,
  visibility: RepositoryVisibility,
  template?: ?boolean,
  homepageUrl?: ?any,
  hasWikiEnabled?: ?boolean,
  hasIssuesEnabled?: ?boolean,
  teamId?: ?string,
  clientMutationId?: ?string,
|};
export type createRepositoryMutationVariables = {|
  input: CreateRepositoryInput
|};
export type createRepositoryMutationResponse = {|
  +createRepository: ?{|
    +repository: ?{|
      +sshUrl: any,
      +url: any,
    |}
  |}
|};
export type createRepositoryMutation = {|
  variables: createRepositoryMutationVariables,
  response: createRepositoryMutationResponse,
|};
*/


/*
mutation createRepositoryMutation(
  $input: CreateRepositoryInput!
) {
  createRepository(input: $input) {
    repository {
      sshUrl
      url
      id
    }
  }
}
*/

const node/*: ConcreteRequest*/ = (function(){
var v0 = [
  {
    "kind": "LocalArgument",
    "name": "input",
    "type": "CreateRepositoryInput!",
    "defaultValue": null
  }
],
v1 = [
  {
    "kind": "Variable",
    "name": "input",
    "variableName": "input"
  }
],
v2 = {
  "kind": "ScalarField",
  "alias": null,
  "name": "sshUrl",
  "args": null,
  "storageKey": null
},
v3 = {
  "kind": "ScalarField",
  "alias": null,
  "name": "url",
  "args": null,
  "storageKey": null
};
return {
  "kind": "Request",
  "fragment": {
    "kind": "Fragment",
    "name": "createRepositoryMutation",
    "type": "Mutation",
    "metadata": null,
    "argumentDefinitions": (v0/*: any*/),
    "selections": [
      {
        "kind": "LinkedField",
        "alias": null,
        "name": "createRepository",
        "storageKey": null,
        "args": (v1/*: any*/),
        "concreteType": "CreateRepositoryPayload",
        "plural": false,
        "selections": [
          {
            "kind": "LinkedField",
            "alias": null,
            "name": "repository",
            "storageKey": null,
            "args": null,
            "concreteType": "Repository",
            "plural": false,
            "selections": [
              (v2/*: any*/),
              (v3/*: any*/)
            ]
          }
        ]
      }
    ]
  },
  "operation": {
    "kind": "Operation",
    "name": "createRepositoryMutation",
    "argumentDefinitions": (v0/*: any*/),
    "selections": [
      {
        "kind": "LinkedField",
        "alias": null,
        "name": "createRepository",
        "storageKey": null,
        "args": (v1/*: any*/),
        "concreteType": "CreateRepositoryPayload",
        "plural": false,
        "selections": [
          {
            "kind": "LinkedField",
            "alias": null,
            "name": "repository",
            "storageKey": null,
            "args": null,
            "concreteType": "Repository",
            "plural": false,
            "selections": [
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
      }
    ]
  },
  "params": {
    "operationKind": "mutation",
    "name": "createRepositoryMutation",
    "id": null,
    "text": "mutation createRepositoryMutation(\n  $input: CreateRepositoryInput!\n) {\n  createRepository(input: $input) {\n    repository {\n      sshUrl\n      url\n      id\n    }\n  }\n}\n",
    "metadata": {}
  }
};
})();
// prettier-ignore
(node/*: any*/).hash = 'e8f154d9f35411a15f77583bb44f7ed5';
module.exports = node;
