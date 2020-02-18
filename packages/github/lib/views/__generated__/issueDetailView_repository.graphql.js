/**
 * @flow
 */

/* eslint-disable */

'use strict';

/*::
import type { ReaderFragment } from 'relay-runtime';
import type { FragmentReference } from "relay-runtime";
declare export opaque type issueDetailView_repository$ref: FragmentReference;
declare export opaque type issueDetailView_repository$fragmentType: issueDetailView_repository$ref;
export type issueDetailView_repository = {|
  +id: string,
  +name: string,
  +owner: {|
    +login: string
  |},
  +$refType: issueDetailView_repository$ref,
|};
export type issueDetailView_repository$data = issueDetailView_repository;
export type issueDetailView_repository$key = {
  +$data?: issueDetailView_repository$data,
  +$fragmentRefs: issueDetailView_repository$ref,
};
*/


const node/*: ReaderFragment*/ = {
  "kind": "Fragment",
  "name": "issueDetailView_repository",
  "type": "Repository",
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
  ]
};
// prettier-ignore
(node/*: any*/).hash = '295a60f53b25b6fdb07a1539cda447f2';
module.exports = node;
