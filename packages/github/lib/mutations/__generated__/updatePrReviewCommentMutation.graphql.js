/**
 * @flow
 * @relayHash 887a4669e3d39128b391814ca67df4d0
 */

/* eslint-disable */

'use strict';

/*::
import type { ConcreteRequest } from 'relay-runtime';
export type UpdatePullRequestReviewCommentInput = {|
  pullRequestReviewCommentId: string,
  body: string,
  clientMutationId?: ?string,
|};
export type updatePrReviewCommentMutationVariables = {|
  input: UpdatePullRequestReviewCommentInput
|};
export type updatePrReviewCommentMutationResponse = {|
  +updatePullRequestReviewComment: ?{|
    +pullRequestReviewComment: ?{|
      +id: string,
      +lastEditedAt: ?any,
      +body: string,
      +bodyHTML: any,
    |}
  |}
|};
export type updatePrReviewCommentMutation = {|
  variables: updatePrReviewCommentMutationVariables,
  response: updatePrReviewCommentMutationResponse,
|};
*/


/*
mutation updatePrReviewCommentMutation(
  $input: UpdatePullRequestReviewCommentInput!
) {
  updatePullRequestReviewComment(input: $input) {
    pullRequestReviewComment {
      id
      lastEditedAt
      body
      bodyHTML
    }
  }
}
*/

const node/*: ConcreteRequest*/ = (function(){
var v0 = [
  {
    "kind": "LocalArgument",
    "name": "input",
    "type": "UpdatePullRequestReviewCommentInput!",
    "defaultValue": null
  }
],
v1 = [
  {
    "kind": "LinkedField",
    "alias": null,
    "name": "updatePullRequestReviewComment",
    "storageKey": null,
    "args": [
      {
        "kind": "Variable",
        "name": "input",
        "variableName": "input"
      }
    ],
    "concreteType": "UpdatePullRequestReviewCommentPayload",
    "plural": false,
    "selections": [
      {
        "kind": "LinkedField",
        "alias": null,
        "name": "pullRequestReviewComment",
        "storageKey": null,
        "args": null,
        "concreteType": "PullRequestReviewComment",
        "plural": false,
        "selections": [
          {
            "kind": "ScalarField",
            "alias": null,
            "name": "id",
            "args": null,
            "storageKey": null
          },
          {
            "kind": "ScalarField",
            "alias": null,
            "name": "lastEditedAt",
            "args": null,
            "storageKey": null
          },
          {
            "kind": "ScalarField",
            "alias": null,
            "name": "body",
            "args": null,
            "storageKey": null
          },
          {
            "kind": "ScalarField",
            "alias": null,
            "name": "bodyHTML",
            "args": null,
            "storageKey": null
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
    "name": "updatePrReviewCommentMutation",
    "type": "Mutation",
    "metadata": null,
    "argumentDefinitions": (v0/*: any*/),
    "selections": (v1/*: any*/)
  },
  "operation": {
    "kind": "Operation",
    "name": "updatePrReviewCommentMutation",
    "argumentDefinitions": (v0/*: any*/),
    "selections": (v1/*: any*/)
  },
  "params": {
    "operationKind": "mutation",
    "name": "updatePrReviewCommentMutation",
    "id": null,
    "text": "mutation updatePrReviewCommentMutation(\n  $input: UpdatePullRequestReviewCommentInput!\n) {\n  updatePullRequestReviewComment(input: $input) {\n    pullRequestReviewComment {\n      id\n      lastEditedAt\n      body\n      bodyHTML\n    }\n  }\n}\n",
    "metadata": {}
  }
};
})();
// prettier-ignore
(node/*: any*/).hash = 'd7b4e823f4604a2b193a1faceb3fcfca';
module.exports = node;
