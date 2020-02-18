/**
 * @flow
 */

/* eslint-disable */

'use strict';

/*::
import type { ReaderFragment } from 'relay-runtime';
import type { FragmentReference } from "relay-runtime";
declare export opaque type commitView_commit$ref: FragmentReference;
declare export opaque type commitView_commit$fragmentType: commitView_commit$ref;
export type commitView_commit = {|
  +author: ?{|
    +name: ?string,
    +avatarUrl: any,
    +user: ?{|
      +login: string
    |},
  |},
  +committer: ?{|
    +name: ?string,
    +avatarUrl: any,
    +user: ?{|
      +login: string
    |},
  |},
  +authoredByCommitter: boolean,
  +sha: any,
  +message: string,
  +messageHeadlineHTML: any,
  +commitUrl: any,
  +$refType: commitView_commit$ref,
|};
export type commitView_commit$data = commitView_commit;
export type commitView_commit$key = {
  +$data?: commitView_commit$data,
  +$fragmentRefs: commitView_commit$ref,
};
*/


const node/*: ReaderFragment*/ = (function(){
var v0 = [
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
    "name": "avatarUrl",
    "args": null,
    "storageKey": null
  },
  {
    "kind": "LinkedField",
    "alias": null,
    "name": "user",
    "storageKey": null,
    "args": null,
    "concreteType": "User",
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
];
return {
  "kind": "Fragment",
  "name": "commitView_commit",
  "type": "Commit",
  "metadata": null,
  "argumentDefinitions": [],
  "selections": [
    {
      "kind": "LinkedField",
      "alias": null,
      "name": "author",
      "storageKey": null,
      "args": null,
      "concreteType": "GitActor",
      "plural": false,
      "selections": (v0/*: any*/)
    },
    {
      "kind": "LinkedField",
      "alias": null,
      "name": "committer",
      "storageKey": null,
      "args": null,
      "concreteType": "GitActor",
      "plural": false,
      "selections": (v0/*: any*/)
    },
    {
      "kind": "ScalarField",
      "alias": null,
      "name": "authoredByCommitter",
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
      "name": "message",
      "args": null,
      "storageKey": null
    },
    {
      "kind": "ScalarField",
      "alias": null,
      "name": "messageHeadlineHTML",
      "args": null,
      "storageKey": null
    },
    {
      "kind": "ScalarField",
      "alias": null,
      "name": "commitUrl",
      "args": null,
      "storageKey": null
    }
  ]
};
})();
// prettier-ignore
(node/*: any*/).hash = '9d2823ee95f39173f656043ddfc8d47c';
module.exports = node;
