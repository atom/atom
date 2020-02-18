/**
 * @flow
 */

/* eslint-disable */

'use strict';

/*::
import type { ReaderFragment } from 'relay-runtime';
export type CheckConclusionState = "ACTION_REQUIRED" | "CANCELLED" | "FAILURE" | "NEUTRAL" | "SUCCESS" | "TIMED_OUT" | "%future added value";
export type CheckStatusState = "COMPLETED" | "IN_PROGRESS" | "QUEUED" | "REQUESTED" | "%future added value";
import type { FragmentReference } from "relay-runtime";
declare export opaque type checkRunView_checkRun$ref: FragmentReference;
declare export opaque type checkRunView_checkRun$fragmentType: checkRunView_checkRun$ref;
export type checkRunView_checkRun = {|
  +name: string,
  +status: CheckStatusState,
  +conclusion: ?CheckConclusionState,
  +title: ?string,
  +summary: ?string,
  +permalink: any,
  +detailsUrl: ?any,
  +$refType: checkRunView_checkRun$ref,
|};
export type checkRunView_checkRun$data = checkRunView_checkRun;
export type checkRunView_checkRun$key = {
  +$data?: checkRunView_checkRun$data,
  +$fragmentRefs: checkRunView_checkRun$ref,
};
*/


const node/*: ReaderFragment*/ = {
  "kind": "Fragment",
  "name": "checkRunView_checkRun",
  "type": "CheckRun",
  "metadata": null,
  "argumentDefinitions": [],
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
      "name": "status",
      "args": null,
      "storageKey": null
    },
    {
      "kind": "ScalarField",
      "alias": null,
      "name": "conclusion",
      "args": null,
      "storageKey": null
    },
    {
      "kind": "ScalarField",
      "alias": null,
      "name": "title",
      "args": null,
      "storageKey": null
    },
    {
      "kind": "ScalarField",
      "alias": null,
      "name": "summary",
      "args": null,
      "storageKey": null
    },
    {
      "kind": "ScalarField",
      "alias": null,
      "name": "permalink",
      "args": null,
      "storageKey": null
    },
    {
      "kind": "ScalarField",
      "alias": null,
      "name": "detailsUrl",
      "args": null,
      "storageKey": null
    }
  ]
};
// prettier-ignore
(node/*: any*/).hash = '7135f882a3513e65b0a52393a0cc8b40';
module.exports = node;
