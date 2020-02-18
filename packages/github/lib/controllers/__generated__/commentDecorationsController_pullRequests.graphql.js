/**
 * @flow
 */

/* eslint-disable */

'use strict';

/*::
import type { ReaderFragment } from 'relay-runtime';
import type { FragmentReference } from "relay-runtime";
declare export opaque type commentDecorationsController_pullRequests$ref: FragmentReference;
declare export opaque type commentDecorationsController_pullRequests$fragmentType: commentDecorationsController_pullRequests$ref;
export type commentDecorationsController_pullRequests = $ReadOnlyArray<{|
  +number: number,
  +headRefName: string,
  +headRefOid: any,
  +headRepository: ?{|
    +name: string,
    +owner: {|
      +login: string
    |},
  |},
  +repository: {|
    +name: string,
    +owner: {|
      +login: string
    |},
  |},
  +$refType: commentDecorationsController_pullRequests$ref,
|}>;
export type commentDecorationsController_pullRequests$data = commentDecorationsController_pullRequests;
export type commentDecorationsController_pullRequests$key = $ReadOnlyArray<{
  +$data?: commentDecorationsController_pullRequests$data,
  +$fragmentRefs: commentDecorationsController_pullRequests$ref,
}>;
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
];
return {
  "kind": "Fragment",
  "name": "commentDecorationsController_pullRequests",
  "type": "PullRequest",
  "metadata": {
    "plural": true
  },
  "argumentDefinitions": [],
  "selections": [
    {
      "kind": "ScalarField",
      "alias": null,
      "name": "number",
      "args": null,
      "storageKey": null
    },
    {
      "kind": "ScalarField",
      "alias": null,
      "name": "headRefName",
      "args": null,
      "storageKey": null
    },
    {
      "kind": "ScalarField",
      "alias": null,
      "name": "headRefOid",
      "args": null,
      "storageKey": null
    },
    {
      "kind": "LinkedField",
      "alias": null,
      "name": "headRepository",
      "storageKey": null,
      "args": null,
      "concreteType": "Repository",
      "plural": false,
      "selections": (v0/*: any*/)
    },
    {
      "kind": "LinkedField",
      "alias": null,
      "name": "repository",
      "storageKey": null,
      "args": null,
      "concreteType": "Repository",
      "plural": false,
      "selections": (v0/*: any*/)
    }
  ]
};
})();
// prettier-ignore
(node/*: any*/).hash = '62f96ccd13dfc2649112a7b4afaf4ba2';
module.exports = node;
