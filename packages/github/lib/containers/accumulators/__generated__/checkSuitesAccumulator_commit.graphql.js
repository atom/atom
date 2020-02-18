/**
 * @flow
 */

/* eslint-disable */

'use strict';

/*::
import type { ReaderFragment } from 'relay-runtime';
type checkRunsAccumulator_checkSuite$ref = any;
type checkSuiteView_checkSuite$ref = any;
export type CheckConclusionState = "ACTION_REQUIRED" | "CANCELLED" | "FAILURE" | "NEUTRAL" | "SUCCESS" | "TIMED_OUT" | "%future added value";
export type CheckStatusState = "COMPLETED" | "IN_PROGRESS" | "QUEUED" | "REQUESTED" | "%future added value";
import type { FragmentReference } from "relay-runtime";
declare export opaque type checkSuitesAccumulator_commit$ref: FragmentReference;
declare export opaque type checkSuitesAccumulator_commit$fragmentType: checkSuitesAccumulator_commit$ref;
export type checkSuitesAccumulator_commit = {|
  +id: string,
  +checkSuites: ?{|
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
        +$fragmentRefs: checkSuiteView_checkSuite$ref & checkRunsAccumulator_checkSuite$ref,
      |},
    |}>,
  |},
  +$refType: checkSuitesAccumulator_commit$ref,
|};
export type checkSuitesAccumulator_commit$data = checkSuitesAccumulator_commit;
export type checkSuitesAccumulator_commit$key = {
  +$data?: checkSuitesAccumulator_commit$data,
  +$fragmentRefs: checkSuitesAccumulator_commit$ref,
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
  "name": "checkSuitesAccumulator_commit",
  "type": "Commit",
  "metadata": {
    "connection": [
      {
        "count": "checkSuiteCount",
        "cursor": "checkSuiteCursor",
        "direction": "forward",
        "path": [
          "checkSuites"
        ]
      }
    ]
  },
  "argumentDefinitions": [
    {
      "kind": "LocalArgument",
      "name": "checkSuiteCount",
      "type": "Int!",
      "defaultValue": null
    },
    {
      "kind": "LocalArgument",
      "name": "checkSuiteCursor",
      "type": "String",
      "defaultValue": null
    },
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
      "alias": "checkSuites",
      "name": "__CheckSuiteAccumulator_checkSuites_connection",
      "storageKey": null,
      "args": null,
      "concreteType": "CheckSuiteConnection",
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
          "concreteType": "CheckSuiteEdge",
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
              "concreteType": "CheckSuite",
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
                  "name": "checkSuiteView_checkSuite",
                  "args": null
                },
                {
                  "kind": "FragmentSpread",
                  "name": "checkRunsAccumulator_checkSuite",
                  "args": [
                    {
                      "kind": "Variable",
                      "name": "checkRunCount",
                      "variableName": "checkRunCount"
                    },
                    {
                      "kind": "Variable",
                      "name": "checkRunCursor",
                      "variableName": "checkRunCursor"
                    }
                  ]
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
(node/*: any*/).hash = '582abc8127f0f2f19fb0a6a531af5e06';
module.exports = node;
