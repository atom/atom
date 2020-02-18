/**
 * @flow
 */

/* eslint-disable */

'use strict';

/*::
import type { ReaderFragment } from 'relay-runtime';
type checkRunView_checkRun$ref = any;
export type CheckConclusionState = "ACTION_REQUIRED" | "CANCELLED" | "FAILURE" | "NEUTRAL" | "SUCCESS" | "TIMED_OUT" | "%future added value";
export type CheckStatusState = "COMPLETED" | "IN_PROGRESS" | "QUEUED" | "REQUESTED" | "%future added value";
import type { FragmentReference } from "relay-runtime";
declare export opaque type checkRunsAccumulator_checkSuite$ref: FragmentReference;
declare export opaque type checkRunsAccumulator_checkSuite$fragmentType: checkRunsAccumulator_checkSuite$ref;
export type checkRunsAccumulator_checkSuite = {|
  +id: string,
  +checkRuns: ?{|
    +pageInfo: {|
      +hasNextPage: boolean,
      +endCursor: ?string,
    |},
    +edges: ?$ReadOnlyArray<?{|
      +cursor: string,
      +node: ?{|
        +id: string,
        +status: CheckStatusState,
        +conclusion: ?CheckConclusionState,
        +$fragmentRefs: checkRunView_checkRun$ref,
      |},
    |}>,
  |},
  +$refType: checkRunsAccumulator_checkSuite$ref,
|};
export type checkRunsAccumulator_checkSuite$data = checkRunsAccumulator_checkSuite;
export type checkRunsAccumulator_checkSuite$key = {
  +$data?: checkRunsAccumulator_checkSuite$data,
  +$fragmentRefs: checkRunsAccumulator_checkSuite$ref,
};
*/


const node/*: ReaderFragment*/ = (function(){
var v0 = {
  "kind": "ScalarField",
  "alias": null,
  "name": "id",
  "args": null,
  "storageKey": null
};
return {
  "kind": "Fragment",
  "name": "checkRunsAccumulator_checkSuite",
  "type": "CheckSuite",
  "metadata": {
    "connection": [
      {
        "count": "checkRunCount",
        "cursor": "checkRunCursor",
        "direction": "forward",
        "path": [
          "checkRuns"
        ]
      }
    ]
  },
  "argumentDefinitions": [
    {
      "kind": "LocalArgument",
      "name": "checkRunCount",
      "type": "Int!",
      "defaultValue": null
    },
    {
      "kind": "LocalArgument",
      "name": "checkRunCursor",
      "type": "String",
      "defaultValue": null
    }
  ],
  "selections": [
    (v0/*: any*/),
    {
      "kind": "LinkedField",
      "alias": "checkRuns",
      "name": "__CheckRunsAccumulator_checkRuns_connection",
      "storageKey": null,
      "args": null,
      "concreteType": "CheckRunConnection",
      "plural": false,
      "selections": [
        {
          "kind": "LinkedField",
          "alias": null,
          "name": "pageInfo",
          "storageKey": null,
          "args": null,
          "concreteType": "PageInfo",
          "plural": false,
          "selections": [
            {
              "kind": "ScalarField",
              "alias": null,
              "name": "hasNextPage",
              "args": null,
              "storageKey": null
            },
            {
              "kind": "ScalarField",
              "alias": null,
              "name": "endCursor",
              "args": null,
              "storageKey": null
            }
          ]
        },
        {
          "kind": "LinkedField",
          "alias": null,
          "name": "edges",
          "storageKey": null,
          "args": null,
          "concreteType": "CheckRunEdge",
          "plural": true,
          "selections": [
            {
              "kind": "ScalarField",
              "alias": null,
              "name": "cursor",
              "args": null,
              "storageKey": null
            },
            {
              "kind": "LinkedField",
              "alias": null,
              "name": "node",
              "storageKey": null,
              "args": null,
              "concreteType": "CheckRun",
              "plural": false,
              "selections": [
                (v0/*: any*/),
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
                  "name": "__typename",
                  "args": null,
                  "storageKey": null
                },
                {
                  "kind": "FragmentSpread",
                  "name": "checkRunView_checkRun",
                  "args": null
                }
              ]
            }
          ]
        }
      ]
    }
  ]
};
})();
// prettier-ignore
(node/*: any*/).hash = '4a47da672423daae903769141008d468';
module.exports = node;
