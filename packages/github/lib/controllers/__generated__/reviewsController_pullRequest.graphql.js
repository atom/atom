/**
 * @flow
 */

/* eslint-disable */

'use strict';

/*::
import type { ReaderFragment } from 'relay-runtime';
type prCheckoutController_pullRequest$ref = any;
import type { FragmentReference } from "relay-runtime";
declare export opaque type reviewsController_pullRequest$ref: FragmentReference;
declare export opaque type reviewsController_pullRequest$fragmentType: reviewsController_pullRequest$ref;
export type reviewsController_pullRequest = {|
  +id: string,
  +$fragmentRefs: prCheckoutController_pullRequest$ref,
  +$refType: reviewsController_pullRequest$ref,
|};
export type reviewsController_pullRequest$data = reviewsController_pullRequest;
export type reviewsController_pullRequest$key = {
  +$data?: reviewsController_pullRequest$data,
  +$fragmentRefs: reviewsController_pullRequest$ref,
};
*/


const node/*: ReaderFragment*/ = {
  "kind": "Fragment",
  "name": "reviewsController_pullRequest",
  "type": "PullRequest",
  "metadata": null,
  "argumentDefinitions": [],
  "selections": [
    {
      "kind": "ScalarField",
      "alias": null,
      "name": "id",
      "args": null,
      "storageKey": null
    },
    {
      "kind": "FragmentSpread",
      "name": "prCheckoutController_pullRequest",
      "args": null
    }
  ]
};
// prettier-ignore
(node/*: any*/).hash = '9d67f9908ab4ed776af5f1ee14f61ccb';
module.exports = node;
