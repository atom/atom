/**
 * @flow
 */

/* eslint-disable */

'use strict';

/*::
import type { ReaderFragment } from 'relay-runtime';
type crossReferencedEventView_item$ref = any;
import type { FragmentReference } from "relay-runtime";
declare export opaque type crossReferencedEventsView_nodes$ref: FragmentReference;
declare export opaque type crossReferencedEventsView_nodes$fragmentType: crossReferencedEventsView_nodes$ref;
export type crossReferencedEventsView_nodes = $ReadOnlyArray<{|
  +id: string,
  +referencedAt: any,
  +isCrossRepository: boolean,
  +actor: ?{|
    +login: string,
    +avatarUrl: any,
  |},
  +source: {|
    +__typename: string,
    +repository?: {|
      +name: string,
      +owner: {|
        +login: string
      |},
    |},
  |},
  +$fragmentRefs: crossReferencedEventView_item$ref,
  +$refType: crossReferencedEventsView_nodes$ref,
|}>;
export type crossReferencedEventsView_nodes$data = crossReferencedEventsView_nodes;
export type crossReferencedEventsView_nodes$key = $ReadOnlyArray<{
  +$data?: crossReferencedEventsView_nodes$data,
  +$fragmentRefs: crossReferencedEventsView_nodes$ref,
}>;
*/


const node/*: ReaderFragment*/ = (function(){
var v0 = {
  "kind": "ScalarField",
  "alias": null,
  "name": "login",
  "args": null,
  "storageKey": null
};
return {
  "kind": "Fragment",
  "name": "crossReferencedEventsView_nodes",
  "type": "CrossReferencedEvent",
  "metadata": {
    "plural": true
  },
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
      "name": "referencedAt",
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
      "name": "actor",
      "storageKey": null,
      "args": null,
      "concreteType": null,
      "plural": false,
      "selections": [
        (v0/*: any*/),
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
              "kind": "LinkedField",
              "alias": null,
              "name": "owner",
              "storageKey": null,
              "args": null,
              "concreteType": null,
              "plural": false,
              "selections": [
                (v0/*: any*/)
              ]
            }
          ]
        }
      ]
    },
    {
      "kind": "FragmentSpread",
      "name": "crossReferencedEventView_item",
      "args": null
    }
  ]
};
})();
// prettier-ignore
(node/*: any*/).hash = '5bbb7b39e10559bac4af2d6f9ff7a9e2';
module.exports = node;
