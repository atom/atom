/**
 * @flow
 */

/* eslint-disable */

'use strict';

/*::
import type { ReaderFragment } from 'relay-runtime';
import type { FragmentReference } from "relay-runtime";
declare export opaque type commitCommentView_item$ref: FragmentReference;
declare export opaque type commitCommentView_item$fragmentType: commitCommentView_item$ref;
export type commitCommentView_item = {|
  +author: ?{|
    +login: string,
    +avatarUrl: any,
  |},
  +commit: ?{|
    +oid: any
  |},
  +bodyHTML: any,
  +createdAt: any,
  +path: ?string,
  +position: ?number,
  +$refType: commitCommentView_item$ref,
|};
export type commitCommentView_item$data = commitCommentView_item;
export type commitCommentView_item$key = {
  +$data?: commitCommentView_item$data,
  +$fragmentRefs: commitCommentView_item$ref,
};
*/


const node/*: ReaderFragment*/ = {
  "kind": "Fragment",
  "name": "commitCommentView_item",
  "type": "CommitComment",
  "metadata": null,
  "argumentDefinitions": [],
  "selections": [
    {
      "kind": "LinkedField",
      "alias": null,
      "name": "author",
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
        },
        {
          "kind": "ScalarField",
          "alias": null,
          "name": "avatarUrl",
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
      "name": "bodyHTML",
      "args": null,
      "storageKey": null
    },
    {
      "kind": "ScalarField",
      "alias": null,
      "name": "createdAt",
      "args": null,
      "storageKey": null
    },
    {
      "kind": "ScalarField",
      "alias": null,
      "name": "path",
      "args": null,
      "storageKey": null
    },
    {
      "kind": "ScalarField",
      "alias": null,
      "name": "position",
      "args": null,
      "storageKey": null
    }
  ]
};
// prettier-ignore
(node/*: any*/).hash = 'f3e868b343fe8d6fee958d5339b554dc';
module.exports = node;
