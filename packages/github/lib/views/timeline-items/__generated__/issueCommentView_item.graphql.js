/**
 * @flow
 */

/* eslint-disable */

'use strict';

/*::
import type { ReaderFragment } from 'relay-runtime';
import type { FragmentReference } from "relay-runtime";
declare export opaque type issueCommentView_item$ref: FragmentReference;
declare export opaque type issueCommentView_item$fragmentType: issueCommentView_item$ref;
export type issueCommentView_item = {|
  +author: ?{|
    +avatarUrl: any,
    +login: string,
  |},
  +bodyHTML: any,
  +createdAt: any,
  +url: any,
  +$refType: issueCommentView_item$ref,
|};
export type issueCommentView_item$data = issueCommentView_item;
export type issueCommentView_item$key = {
  +$data?: issueCommentView_item$data,
  +$fragmentRefs: issueCommentView_item$ref,
};
*/


const node/*: ReaderFragment*/ = {
  "kind": "Fragment",
  "name": "issueCommentView_item",
  "type": "IssueComment",
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
      "name": "url",
      "args": null,
      "storageKey": null
    }
  ]
};
// prettier-ignore
(node/*: any*/).hash = 'adc36c52f51de14256693ab9e4eb84bb';
module.exports = node;
