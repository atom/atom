/**
 * @flow
 */

/* eslint-disable */

'use strict';

/*::
import type { ReaderFragment } from 'relay-runtime';
import type { FragmentReference } from "relay-runtime";
declare export opaque type prCommitView_item$ref: FragmentReference;
declare export opaque type prCommitView_item$fragmentType: prCommitView_item$ref;
export type prCommitView_item = {|
  +committer: ?{|
    +avatarUrl: any,
    +name: ?string,
    +date: ?any,
  |},
  +messageHeadline: string,
  +messageBody: string,
  +shortSha: string,
  +sha: any,
  +url: any,
  +$refType: prCommitView_item$ref,
|};
export type prCommitView_item$data = prCommitView_item;
export type prCommitView_item$key = {
  +$data?: prCommitView_item$data,
  +$fragmentRefs: prCommitView_item$ref,
};
*/


const node/*: ReaderFragment*/ = {
  "kind": "Fragment",
  "name": "prCommitView_item",
  "type": "Commit",
  "metadata": null,
  "argumentDefinitions": [],
  "selections": [
    {
      "kind": "LinkedField",
      "alias": null,
      "name": "committer",
      "storageKey": null,
      "args": null,
      "concreteType": "GitActor",
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
          "name": "name",
          "args": null,
          "storageKey": null
        },
        {
          "kind": "ScalarField",
          "alias": null,
          "name": "date",
          "args": null,
          "storageKey": null
        }
      ]
    },
    {
      "kind": "ScalarField",
      "alias": null,
      "name": "messageHeadline",
      "args": null,
      "storageKey": null
    },
    {
      "kind": "ScalarField",
      "alias": null,
      "name": "messageBody",
      "args": null,
      "storageKey": null
    },
    {
      "kind": "ScalarField",
      "alias": "shortSha",
      "name": "abbreviatedOid",
      "args": null,
      "storageKey": null
    },
    {
      "kind": "ScalarField",
      "alias": "sha",
      "name": "oid",
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
(node/*: any*/).hash = '2bd193bec5d758f465d9428ff3cd8a09';
module.exports = node;
