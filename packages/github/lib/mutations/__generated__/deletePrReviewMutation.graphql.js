/**
 * @flow
 * @relayHash b78f52f30e644f67a35efd13a162469d
 */

/* eslint-disable */

'use strict';

/*::
import type { ConcreteRequest } from 'relay-runtime';
export type DeletePullRequestReviewInput = {|
  pullRequestReviewId: string,
  clientMutationId?: ?string,
|};
export type deletePrReviewMutationVariables = {|
  input: DeletePullRequestReviewInput
|};
export type deletePrReviewMutationResponse = {|
  +deletePullRequestReview: ?{|
    +pullRequestReview: ?{|
      +id: string
    |}
  |}
|};
export type deletePrReviewMutation = {|
  variables: deletePrReviewMutationVariables,
  response: deletePrReviewMutationResponse,
|};
*/


/*
mutation deletePrReviewMutation(
  $input: DeletePullRequestReviewInput!
) {
  deletePullRequestReview(input: $input) {
    pullRequestReview {
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
    "type": "DeletePullRequestReviewInput!",
    "defaultValue": null
  }
],
v1 = [
  {
    "kind": "LinkedField",
    "alias": null,
    "name": "deletePullRequestReview",
    "storageKey": null,
    "args": [
      {
        "kind": "Variable",
        "name": "input",
        "variableName": "input"
      }
    ],
    "concreteType": "DeletePullRequestReviewPayload",
    "plural": false,
    "selections": [
      {
        "kind": "LinkedField",
        "alias": null,
        "name": "pullRequestReview",
        "storageKey": null,
        "args": null,
        "concreteType": "PullRequestReview",
        "plural": false,
        "selections": [
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
];
return {
  "kind": "Request",
  "fragment": {
    "kind": "Fragment",
    "name": "deletePrReviewMutation",
    "type": "Mutation",
    "metadata": null,
    "argumentDefinitions": (v0/*: any*/),
    "selections": (v1/*: any*/)
  },
  "operation": {
    "kind": "Operation",
    "name": "deletePrReviewMutation",
    "argumentDefinitions": (v0/*: any*/),
    "selections": (v1/*: any*/)
  },
  "params": {
    "operationKind": "mutation",
    "name": "deletePrReviewMutation",
    "id": null,
    "text": "mutation deletePrReviewMutation(\n  $input: DeletePullRequestReviewInput!\n) {\n  deletePullRequestReview(input: $input) {\n    pullRequestReview {\n      id\n    }\n  }\n}\n",
    "metadata": {}
  }
};
})();
// prettier-ignore
(node/*: any*/).hash = '768b81334e225cb5d15c0508d2bd4b1f';
module.exports = node;
