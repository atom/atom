/**
 * @flow
 */

/* eslint-disable */

'use strict';

/*::
import type { ReaderFragment } from 'relay-runtime';
import type { FragmentReference } from "relay-runtime";
declare export opaque type prDetailView_repository$ref: FragmentReference;
declare export opaque type prDetailView_repository$fragmentType: prDetailView_repository$ref;
export type prDetailView_repository = {|
  +id: string,
  +name: string,
  +owner: {|
    +login: string
  |},
  +$refType: prDetailView_repository$ref,
|};
export type prDetailView_repository$data = prDetailView_repository;
export type prDetailView_repository$key = {
  +$data?: prDetailView_repository$data,
  +$fragmentRefs: prDetailView_repository$ref,
};
*/


const node/*: ReaderFragment*/ = {
  "kind": "Fragment",
  "name": "prDetailView_repository",
  "type": "Repository",
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
(node/*: any*/).hash = '3f3d61ddd6afa1c9e0811c3b5be51bb0';
module.exports = node;
