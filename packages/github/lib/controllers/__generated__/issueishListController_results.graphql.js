/**
 * @flow
 */

/* eslint-disable */

'use strict';

/*::
import type { ReaderFragment } from 'relay-runtime';
type checkSuitesAccumulator_commit$ref = any;
export type StatusState = "ERROR" | "EXPECTED" | "FAILURE" | "PENDING" | "SUCCESS" | "%future added value";
import type { FragmentReference } from "relay-runtime";
declare export opaque type issueishListController_results$ref: FragmentReference;
declare export opaque type issueishListController_results$fragmentType: issueishListController_results$ref;
export type issueishListController_results = $ReadOnlyArray<{|
  +number: number,
  +title: string,
  +url: any,
  +author: ?{|
    +login: string,
    +avatarUrl: any,
  |},
  +createdAt: any,
  +headRefName: string,
  +repository: {|
    +id: string,
    +name: string,
    +owner: {|
      +login: string
    |},
  |},
  +commits: {|
    +nodes: ?$ReadOnlyArray<?{|
      +commit: {|
        +status: ?{|
          +contexts: $ReadOnlyArray<{|
            +id: string,
            +state: StatusState,
          |}>
        |},
        +$fragmentRefs: checkSuitesAccumulator_commit$ref,
      |}
    |}>
  |},
  +$refType: issueishListController_results$ref,
|}>;
export type issueishListController_results$data = issueishListController_results;
export type issueishListController_results$key = $ReadOnlyArray<{
  +$data?: issueishListController_results$data,
  +$fragmentRefs: issueishListController_results$ref,
}>;
*/


const node/*: ReaderFragment*/ = (function(){
var v0 = {
  "kind": "ScalarField",
  "alias": null,
  "name": "login",
  "args": null,
  "storageKey": null
},
v1 = {
  "kind": "ScalarField",
  "alias": null,
  "name": "id",
  "args": null,
  "storageKey": null
};
return {
  "kind": "Fragment",
  "name": "issueishListController_results",
  "type": "PullRequest",
  "metadata": {
    "plural": true
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
      "name": "title",
      "args": null,
      "storageKey": null
    },
    {
      "kind": "ScalarField",
      "alias": null,
      "name": "url",
      "args": null,
      "storageKey": null
    },
    {
      "kind": "LinkedField",
      "alias": null,
      "name": "author",
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
      "kind": "ScalarField",
      "alias": null,
      "name": "createdAt",
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
      "kind": "LinkedField",
      "alias": null,
      "name": "repository",
      "storageKey": null,
      "args": null,
      "concreteType": "Repository",
      "plural": false,
      "selections": [
        (v1/*: any*/),
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
    },
    {
      "kind": "LinkedField",
      "alias": null,
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
          "name": "nodes",
          "storageKey": null,
          "args": null,
          "concreteType": "PullRequestCommit",
          "plural": true,
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
                    {
                      "kind": "LinkedField",
                      "alias": null,
                      "name": "contexts",
                      "storageKey": null,
                      "args": null,
                      "concreteType": "StatusContext",
                      "plural": true,
                      "selections": [
                        (v1/*: any*/),
                        {
                          "kind": "ScalarField",
                          "alias": null,
                          "name": "state",
                          "args": null,
                          "storageKey": null
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
};
})();
// prettier-ignore
(node/*: any*/).hash = 'af31b5400d8cce5026fc1bb3fc42dc91';
module.exports = node;
