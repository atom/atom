/**
 * @flow
 */

/* eslint-disable */

'use strict';

/*::
import type { ReaderFragment } from 'relay-runtime';
import type { FragmentReference } from "relay-runtime";
declare export opaque type mergedEventView_item$ref: FragmentReference;
declare export opaque type mergedEventView_item$fragmentType: mergedEventView_item$ref;
export type mergedEventView_item = {|
  +actor: ?{|
    +avatarUrl: any,
    +login: string,
  |},
  +commit: ?{|
    +oid: any
  |},
  +mergeRefName: string,
  +createdAt: any,
  +$refType: mergedEventView_item$ref,
|};
export type mergedEventView_item$data = mergedEventView_item;
export type mergedEventView_item$key = {
  +$data?: mergedEventView_item$data,
  +$fragmentRefs: mergedEventView_item$ref,
};
*/


const node/*: ReaderFragment*/ = {
  "kind": "Fragment",
  "name": "mergedEventView_item",
  "type": "MergedEvent",
  "metadata": null,
  "argumentDefinitions": [],
  "selections": [
    {
      "kind": "LinkedField",
      "alias": null,
      "name": "actor",
      "storageKey": null,
      "args": null,
      "concreteType": null,
      "plural": false,
      "selections": [
        {
          "kind": "ScalarField",
          "alias": null,
          "name": "avatarUrl",
          "args": null,
          "storageKey": null
        },
        {
          "kind": "ScalarField",
          "alias": null,
          "name": "login",
          "args": null,
          "storageKey": null
        }
      ]
    },
    {
      "kind": "LinkedField",
      "alias": null,
      "name": "commit",
      "storageKey": null,
      "args": null,
      "concreteType": "Commit",
      "plural": false,
      "selections": [
        {
          "kind": "ScalarField",
          "alias": null,
          "name": "oid",
          "args": null,
          "storageKey": null
        }
      ]
    },
    {
      "kind": "ScalarField",
      "alias": null,
      "name": "mergeRefName",
      "args": null,
      "storageKey": null
    },
    {
      "kind": "ScalarField",
      "alias": null,
      "name": "createdAt",
      "args": null,
      "storageKey": null
    }
  ]
};
// prettier-ignore
(node/*: any*/).hash = 'd265decf08c14d96c2ec47fd5852a956';
module.exports = node;
