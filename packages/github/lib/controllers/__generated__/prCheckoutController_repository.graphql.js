/**
 * @flow
 */

/* eslint-disable */

'use strict';

/*::
import type { ReaderFragment } from 'relay-runtime';
import type { FragmentReference } from "relay-runtime";
declare export opaque type prCheckoutController_repository$ref: FragmentReference;
declare export opaque type prCheckoutController_repository$fragmentType: prCheckoutController_repository$ref;
export type prCheckoutController_repository = {|
  +name: string,
  +owner: {|
    +login: string
  |},
  +$refType: prCheckoutController_repository$ref,
|};
export type prCheckoutController_repository$data = prCheckoutController_repository;
export type prCheckoutController_repository$key = {
  +$data?: prCheckoutController_repository$data,
  +$fragmentRefs: prCheckoutController_repository$ref,
};
*/


const node/*: ReaderFragment*/ = {
  "kind": "Fragment",
  "name": "prCheckoutController_repository",
  "type": "Repository",
  "metadata": null,
  "argumentDefinitions": [],
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
};
// prettier-ignore
(node/*: any*/).hash = 'b2212745240c03ff8fc7cb13dfc63183';
module.exports = node;
