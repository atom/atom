/**
 * @flow
 */

/* eslint-disable */

'use strict';

/*::
import type { ReaderFragment } from 'relay-runtime';
import type { FragmentReference } from "relay-runtime";
declare export opaque type headRefForcePushedEventView_item$ref: FragmentReference;
declare export opaque type headRefForcePushedEventView_item$fragmentType: headRefForcePushedEventView_item$ref;
export type headRefForcePushedEventView_item = {|
  +actor: ?{|
    +avatarUrl: any,
    +login: string,
  |},
  +beforeCommit: ?{|
    +oid: any
  |},
  +afterCommit: ?{|
    +oid: any
  |},
  +createdAt: any,
  +$refType: headRefForcePushedEventView_item$ref,
|};
export type headRefForcePushedEventView_item$data = headRefForcePushedEventView_item;
export type headRefForcePushedEventView_item$key = {
  +$data?: headRefForcePushedEventView_item$data,
  +$fragmentRefs: headRefForcePushedEventView_item$ref,
};
*/


const node/*: ReaderFragment*/ = (function(){
var v0 = [
  {
    "kind": "ScalarField",
    "alias": null,
    "name": "oid",
    "args": null,
    "storageKey": null
  }
];
return {
  "kind": "Fragment",
  "name": "headRefForcePushedEventView_item",
  "type": "HeadRefForcePushedEvent",
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
      "name": "beforeCommit",
      "storageKey": null,
      "args": null,
      "concreteType": "Commit",
      "plural": false,
      "selections": (v0/*: any*/)
    },
    {
      "kind": "LinkedField",
      "alias": null,
      "name": "afterCommit",
      "storageKey": null,
      "args": null,
      "concreteType": "Commit",
      "plural": false,
      "selections": (v0/*: any*/)
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
})();
// prettier-ignore
(node/*: any*/).hash = 'fc403545674c57c1997c870805101ffb';
module.exports = node;
