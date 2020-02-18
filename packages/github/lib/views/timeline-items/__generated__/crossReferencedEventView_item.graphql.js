/**
 * @flow
 */

/* eslint-disable */

'use strict';

/*::
import type { ReaderFragment } from 'relay-runtime';
export type IssueState = "CLOSED" | "OPEN" | "%future added value";
export type PullRequestState = "CLOSED" | "MERGED" | "OPEN" | "%future added value";
import type { FragmentReference } from "relay-runtime";
declare export opaque type crossReferencedEventView_item$ref: FragmentReference;
declare export opaque type crossReferencedEventView_item$fragmentType: crossReferencedEventView_item$ref;
export type crossReferencedEventView_item = {|
  +id: string,
  +isCrossRepository: boolean,
  +source: {|
    +__typename: string,
    +repository?: {|
      +name: string,
      +isPrivate: boolean,
      +owner: {|
        +login: string
      |},
    |},
    +number?: number,
    +title?: string,
    +url?: any,
    +issueState?: IssueState,
    +prState?: PullRequestState,
  |},
  +$refType: crossReferencedEventView_item$ref,
|};
export type crossReferencedEventView_item$data = crossReferencedEventView_item;
export type crossReferencedEventView_item$key = {
  +$data?: crossReferencedEventView_item$data,
  +$fragmentRefs: crossReferencedEventView_item$ref,
};
*/


const node/*: ReaderFragment*/ = (function(){
var v0 = {
  "kind": "ScalarField",
  "alias": null,
  "name": "number",
  "args": null,
  "storageKey": null
},
v1 = {
  "kind": "ScalarField",
  "alias": null,
  "name": "title",
  "args": null,
  "storageKey": null
},
v2 = {
  "kind": "ScalarField",
  "alias": null,
  "name": "url",
  "args": null,
  "storageKey": null
};
return {
  "kind": "Fragment",
  "name": "crossReferencedEventView_item",
  "type": "CrossReferencedEvent",
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
      "name": "isCrossRepository",
      "args": null,
      "storageKey": null
    },
    {
      "kind": "LinkedField",
      "alias": null,
      "name": "source",
      "storageKey": null,
      "args": null,
      "concreteType": null,
      "plural": false,
      "selections": [
        {
          "kind": "ScalarField",
          "alias": null,
          "name": "__typename",
          "args": null,
          "storageKey": null
        },
        {
          "kind": "LinkedField",
          "alias": null,
          "name": "repository",
          "storageKey": null,
          "args": null,
          "concreteType": "Repository",
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
              "kind": "ScalarField",
              "alias": null,
              "name": "isPrivate",
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
        },
        {
          "kind": "InlineFragment",
          "type": "Issue",
          "selections": [
            (v0/*: any*/),
            (v1/*: any*/),
            (v2/*: any*/),
            {
              "kind": "ScalarField",
              "alias": "issueState",
              "name": "state",
              "args": null,
              "storageKey": null
            }
          ]
        },
        {
          "kind": "InlineFragment",
          "type": "PullRequest",
          "selections": [
            (v0/*: any*/),
            (v1/*: any*/),
            (v2/*: any*/),
            {
              "kind": "ScalarField",
              "alias": "prState",
              "name": "state",
              "args": null,
              "storageKey": null
            }
          ]
        }
      ]
    }
  ]
};
})();
// prettier-ignore
(node/*: any*/).hash = 'b90b8c9f0acee56516e7413263cf7f51';
module.exports = node;
