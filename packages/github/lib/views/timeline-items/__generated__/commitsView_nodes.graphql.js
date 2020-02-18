/**
 * @flow
 */

/* eslint-disable */

'use strict';

/*::
import type { ReaderFragment } from 'relay-runtime';
type commitView_commit$ref = any;
import type { FragmentReference } from "relay-runtime";
declare export opaque type commitsView_nodes$ref: FragmentReference;
declare export opaque type commitsView_nodes$fragmentType: commitsView_nodes$ref;
export type commitsView_nodes = $ReadOnlyArray<{|
  +commit: {|
    +id: string,
    +author: ?{|
      +name: ?string,
      +user: ?{|
        +login: string
      |},
    |},
    +$fragmentRefs: commitView_commit$ref,
  |},
  +$refType: commitsView_nodes$ref,
|}>;
export type commitsView_nodes$data = commitsView_nodes;
export type commitsView_nodes$key = $ReadOnlyArray<{
  +$data?: commitsView_nodes$data,
  +$fragmentRefs: commitsView_nodes$ref,
}>;
*/


const node/*: ReaderFragment*/ = {
  "kind": "Fragment",
  "name": "commitsView_nodes",
  "type": "PullRequestCommit",
  "metadata": {
    "plural": true
  },
  "argumentDefinitions": [],
  "selections": [
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
          "name": "id",
          "args": null,
          "storageKey": null
        },
        {
          "kind": "LinkedField",
          "alias": null,
          "name": "author",
          "storageKey": null,
          "args": null,
          "concreteType": "GitActor",
          "plural": false,
          "selections": [
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
          ]
        },
        {
          "kind": "FragmentSpread",
          "name": "commitView_commit",
          "args": null
        }
      ]
    }
  ]
};
// prettier-ignore
(node/*: any*/).hash = '5b2734f1e64af2ad2c9803201a0082f3';
module.exports = node;
