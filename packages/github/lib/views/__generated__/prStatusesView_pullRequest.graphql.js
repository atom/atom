/**
 * @flow
 */

/* eslint-disable */

'use strict';

/*::
import type { ReaderFragment } from 'relay-runtime';
type checkSuitesAccumulator_commit$ref = any;
type prStatusContextView_context$ref = any;
export type StatusState = "ERROR" | "EXPECTED" | "FAILURE" | "PENDING" | "SUCCESS" | "%future added value";
import type { FragmentReference } from "relay-runtime";
declare export opaque type prStatusesView_pullRequest$ref: FragmentReference;
declare export opaque type prStatusesView_pullRequest$fragmentType: prStatusesView_pullRequest$ref;
export type prStatusesView_pullRequest = {|
  +id: string,
  +recentCommits: {|
    +edges: ?$ReadOnlyArray<?{|
      +node: ?{|
        +commit: {|
          +status: ?{|
            +state: StatusState,
            +contexts: $ReadOnlyArray<{|
              +id: string,
              +state: StatusState,
              +$fragmentRefs: prStatusContextView_context$ref,
            |}>,
          |},
          +$fragmentRefs: checkSuitesAccumulator_commit$ref,
        |}
      |}
    |}>
  |},
  +$refType: prStatusesView_pullRequest$ref,
|};
export type prStatusesView_pullRequest$data = prStatusesView_pullRequest;
export type prStatusesView_pullRequest$key = {
  +$data?: prStatusesView_pullRequest$data,
  +$fragmentRefs: prStatusesView_pullRequest$ref,
};
*/


const node/*: ReaderFragment*/ = (function(){
var v0 = {
  "kind": "ScalarField",
  "alias": null,
  "name": "id",
  "args": null,
  "storageKey": null
},
v1 = {
  "kind": "ScalarField",
  "alias": null,
  "name": "state",
  "args": null,
  "storageKey": null
};
return {
  "kind": "Fragment",
  "name": "prStatusesView_pullRequest",
  "type": "PullRequest",
  "metadata": null,
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
      "alias": "recentCommits",
      "name": "commits",
      "storageKey": "commits(last:1)",
      "args": [
        {
          "kind": "Literal",
          "name": "last",
          "value": 1
        }
      ],
      "concreteType": "PullRequestCommitConnection",
      "plural": false,
      "selections": [
        {
          "kind": "LinkedField",
          "alias": null,
          "name": "edges",
          "storageKey": null,
          "args": null,
          "concreteType": "PullRequestCommitEdge",
          "plural": true,
          "selections": [
            {
              "kind": "LinkedField",
              "alias": null,
              "name": "node",
              "storageKey": null,
              "args": null,
              "concreteType": "PullRequestCommit",
              "plural": false,
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
                      "kind": "LinkedField",
                      "alias": null,
                      "name": "status",
                      "storageKey": null,
                      "args": null,
                      "concreteType": "Status",
                      "plural": false,
                      "selections": [
                        (v1/*: any*/),
                        {
                          "kind": "LinkedField",
                          "alias": null,
                          "name": "contexts",
                          "storageKey": null,
                          "args": null,
                          "concreteType": "StatusContext",
                          "plural": true,
                          "selections": [
                            (v0/*: any*/),
                            (v1/*: any*/),
                            {
                              "kind": "FragmentSpread",
                              "name": "prStatusContextView_context",
                              "args": null
                            }
                          ]
                        }
                      ]
                    },
                    {
                      "kind": "FragmentSpread",
                      "name": "checkSuitesAccumulator_commit",
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
                        },
                        {
                          "kind": "Variable",
                          "name": "checkSuiteCount",
                          "variableName": "checkSuiteCount"
                        },
                        {
                          "kind": "Variable",
                          "name": "checkSuiteCursor",
                          "variableName": "checkSuiteCursor"
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
    }
  ]
};
})();
// prettier-ignore
(node/*: any*/).hash = 'e21e2ef5e505a4a8e895bf13cb4202ab';
module.exports = node;
