/**
 * @flow
 */

/* eslint-disable */

'use strict';

/*::
import type { ReaderFragment } from 'relay-runtime';
type prCheckoutController_repository$ref = any;
import type { FragmentReference } from "relay-runtime";
declare export opaque type reviewsController_repository$ref: FragmentReference;
declare export opaque type reviewsController_repository$fragmentType: reviewsController_repository$ref;
export type reviewsController_repository = {|
  +$fragmentRefs: prCheckoutController_repository$ref,
  +$refType: reviewsController_repository$ref,
|};
export type reviewsController_repository$data = reviewsController_repository;
export type reviewsController_repository$key = {
  +$data?: reviewsController_repository$data,
  +$fragmentRefs: reviewsController_repository$ref,
};
*/


const node/*: ReaderFragment*/ = {
  "kind": "Fragment",
  "name": "reviewsController_repository",
  "type": "Repository",
  "metadata": null,
  "argumentDefinitions": [],
  "selections": [
    {
      "kind": "FragmentSpread",
      "name": "prCheckoutController_repository",
      "args": null
    }
  ]
};
// prettier-ignore
(node/*: any*/).hash = '1e0016aed6db6035651ff6213eb38ff6';
module.exports = node;
