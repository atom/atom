/**
 * @flow
 * @relayHash 1e5a909372f6ceeb9cfa8fa991399495
 */

/* eslint-disable */

'use strict';

/*::
import type { ConcreteRequest } from 'relay-runtime';
export type PullRequestReviewEvent = "APPROVE" | "COMMENT" | "DISMISS" | "REQUEST_CHANGES" | "%future added value";
export type SubmitPullRequestReviewInput = {|
  pullRequestReviewId: string,
  event: PullRequestReviewEvent,
  body?: ?string,
  clientMutationId?: ?string,
|};
export type submitPrReviewMutationVariables = {|
  input: SubmitPullRequestReviewInput
|};
export type submitPrReviewMutationResponse = {|
  +submitPullRequestReview: ?{|
    +pullRequestReview: ?{|
      +id: string
    |}
  |}
|};
export type submitPrReviewMutation = {|
  variables: submitPrReviewMutationVariables,
  response: submitPrReviewMutationResponse,
|};
*/


/*
mutation submitPrReviewMutation(
  $input: SubmitPullRequestReviewInput!
) {
  submitPullRequestReview(input: $input) {
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
    "type": "SubmitPullRequestReviewInput!",
    "defaultValue": null
  }
],
v1 = [
  {
    "kind": "LinkedField",
    "alias": null,
    "name": "submitPullRequestReview",
    "storageKey": null,
    "args": [
      {
        "kind": "Variable",
        "name": "input",
        "variableName": "input"
      }
    ],
    "concreteType": "SubmitPullRequestReviewPayload",
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
    "name": "submitPrReviewMutation",
    "type": "Mutation",
    "metadata": null,
    "argumentDefinitions": (v0/*: any*/),
    "selections": (v1/*: any*/)
  },
  "operation": {
    "kind": "Operation",
    "name": "submitPrReviewMutation",
    "argumentDefinitions": (v0/*: any*/),
    "selections": (v1/*: any*/)
  },
  "params": {
    "operationKind": "mutation",
    "name": "submitPrReviewMutation",
    "id": null,
    "text": "mutation submitPrReviewMutation(\n  $input: SubmitPullRequestReviewInput!\n) {\n  submitPullRequestReview(input: $input) {\n    pullRequestReview {\n      id\n    }\n  }\n}\n",
    "metadata": {}
  }
};
})();
// prettier-ignore
(node/*: any*/).hash = 'c52752b3b2cde11e6c86d574ffa967a0';
module.exports = node;
