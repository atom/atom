/**
 * @flow
 */

/* eslint-disable */

'use strict';

/*::
import type { ReaderFragment } from 'relay-runtime';
import type { FragmentReference } from "relay-runtime";
declare export opaque type prCheckoutController_pullRequest$ref: FragmentReference;
declare export opaque type prCheckoutController_pullRequest$fragmentType: prCheckoutController_pullRequest$ref;
export type prCheckoutController_pullRequest = {|
  +number: number,
  +headRefName: string,
  +headRepository: ?{|
    +name: string,
    +url: any,
    +sshUrl: any,
    +owner: {|
      +login: string
    |},
  |},
  +$refType: prCheckoutController_pullRequest$ref,
|};
export type prCheckoutController_pullRequest$data = prCheckoutController_pullRequest;
export type prCheckoutController_pullRequest$key = {
  +$data?: prCheckoutController_pullRequest$data,
  +$fragmentRefs: prCheckoutController_pullRequest$ref,
};
*/


const node/*: ReaderFragment*/ = {
  "kind": "Fragment",
  "name": "prCheckoutController_pullRequest",
  "type": "PullRequest",
  "metadata": null,
  "argumentDefinitions": [],
  "selections": [
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
      "name": "headRefName",
      "args": null,
      "storageKey": null
    },
    {
      "kind": "LinkedField",
      "alias": null,
      "name": "headRepository",
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
          "kind": "ScalarField",
          "alias": null,
          "name": "url",
          "args": null,
          "storageKey": null
        },
        {
          "kind": "ScalarField",
          "alias": null,
          "name": "sshUrl",
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
};
// prettier-ignore
(node/*: any*/).hash = '66e001f389a2c4f74c1369cf69b31268';
module.exports = node;
