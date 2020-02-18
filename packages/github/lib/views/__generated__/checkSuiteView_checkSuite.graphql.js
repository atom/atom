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
declare export opaque type checkSuiteView_checkSuite$ref: FragmentReference;
declare export opaque type checkSuiteView_checkSuite$fragmentType: checkSuiteView_checkSuite$ref;
export type checkSuiteView_checkSuite = {|
  +app: ?{|
    +name: string
  |},
  +status: CheckStatusState,
  +conclusion: ?CheckConclusionState,
  +$refType: checkSuiteView_checkSuite$ref,
|};
export type checkSuiteView_checkSuite$data = checkSuiteView_checkSuite;
export type checkSuiteView_checkSuite$key = {
  +$data?: checkSuiteView_checkSuite$data,
  +$fragmentRefs: checkSuiteView_checkSuite$ref,
};
*/


const node/*: ReaderFragment*/ = {
  "kind": "Fragment",
  "name": "checkSuiteView_checkSuite",
  "type": "CheckSuite",
  "metadata": null,
  "argumentDefinitions": [],
  "selections": [
    {
      "kind": "LinkedField",
      "alias": null,
      "name": "app",
      "storageKey": null,
      "args": null,
      "concreteType": "App",
      "plural": false,
      "selections": [
        {
          "kind": "ScalarField",
          "alias": null,
          "name": "name",
          "args": null,
          "storageKey": null
        }
      ]
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
    }
  ]
};
// prettier-ignore
(node/*: any*/).hash = 'ab1475671a1bc4196d67bfa75ad41446';
module.exports = node;
