/**
 * @flow
 */

/* eslint-disable */

'use strict';

/*::
import type { ReaderFragment } from 'relay-runtime';
import type { FragmentReference } from "relay-runtime";
declare export opaque type reviewsController_viewer$ref: FragmentReference;
declare export opaque type reviewsController_viewer$fragmentType: reviewsController_viewer$ref;
export type reviewsController_viewer = {|
  +id: string,
  +login: string,
  +avatarUrl: any,
  +$refType: reviewsController_viewer$ref,
|};
export type reviewsController_viewer$data = reviewsController_viewer;
export type reviewsController_viewer$key = {
  +$data?: reviewsController_viewer$data,
  +$fragmentRefs: reviewsController_viewer$ref,
};
*/


const node/*: ReaderFragment*/ = {
  "kind": "Fragment",
  "name": "reviewsController_viewer",
  "type": "User",
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
      "kind": "ScalarField",
      "alias": null,
      "name": "login",
      "args": null,
      "storageKey": null
    },
    {
      "kind": "ScalarField",
      "alias": null,
      "name": "avatarUrl",
      "args": null,
      "storageKey": null
    }
  ]
};
// prettier-ignore
(node/*: any*/).hash = 'e9e4cf88f2d8a809620a0f225d502896';
module.exports = node;
