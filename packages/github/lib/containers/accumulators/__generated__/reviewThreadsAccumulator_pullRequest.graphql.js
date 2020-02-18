/**
 * @flow
 */

/* eslint-disable */

'use strict';

/*::
import type { ReaderFragment } from 'relay-runtime';
type reviewCommentsAccumulator_reviewThread$ref = any;
import type { FragmentReference } from "relay-runtime";
declare export opaque type reviewThreadsAccumulator_pullRequest$ref: FragmentReference;
declare export opaque type reviewThreadsAccumulator_pullRequest$fragmentType: reviewThreadsAccumulator_pullRequest$ref;
export type reviewThreadsAccumulator_pullRequest = {|
  +url: any,
  +reviewThreads: {|
    +pageInfo: {|
      +hasNextPage: boolean,
      +endCursor: ?string,
    |},
    +edges: ?$ReadOnlyArray<?{|
      +cursor: string,
      +node: ?{|
        +id: string,
        +isResolved: boolean,
        +resolvedBy: ?{|
          +login: string
        |},
        +viewerCanResolve: boolean,
        +viewerCanUnresolve: boolean,
        +$fragmentRefs: reviewCommentsAccumulator_reviewThread$ref,
      |},
    |}>,
  |},
  +$refType: reviewThreadsAccumulator_pullRequest$ref,
|};
export type reviewThreadsAccumulator_pullRequest$data = reviewThreadsAccumulator_pullRequest;
export type reviewThreadsAccumulator_pullRequest$key = {
  +$data?: reviewThreadsAccumulator_pullRequest$data,
  +$fragmentRefs: reviewThreadsAccumulator_pullRequest$ref,
};
*/


const node/*: ReaderFragment*/ = {
  "kind": "Fragment",
  "name": "reviewThreadsAccumulator_pullRequest",
  "type": "PullRequest",
  "metadata": {
    "connection": [
      {
        "count": "threadCount",
        "cursor": "threadCursor",
        "direction": "forward",
        "path": [
          "reviewThreads"
        ]
      }
    ]
  },
  "argumentDefinitions": [
    {
      "kind": "LocalArgument",
      "name": "threadCount",
      "type": "Int!",
      "defaultValue": null
    },
    {
      "kind": "LocalArgument",
      "name": "threadCursor",
      "type": "String",
      "defaultValue": null
    },
    {
      "kind": "LocalArgument",
      "name": "commentCount",
      "type": "Int!",
      "defaultValue": null
    },
    {
      "kind": "LocalArgument",
      "name": "commentCursor",
      "type": "String",
      "defaultValue": null
    }
  ],
  "selections": [
    {
      "kind": "ScalarField",
      "alias": null,
      "name": "url",
      "args": null,
      "storageKey": null
    },
    {
      "kind": "LinkedField",
      "alias": "reviewThreads",
      "name": "__ReviewThreadsAccumulator_reviewThreads_connection",
      "storageKey": null,
      "args": null,
      "concreteType": "PullRequestReviewThreadConnection",
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
          "concreteType": "PullRequestReviewThreadEdge",
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
              "concreteType": "PullRequestReviewThread",
              "plural": false,
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
                  "name": "isResolved",
                  "args": null,
                  "storageKey": null
                },
                {
                  "kind": "LinkedField",
                  "alias": null,
                  "name": "resolvedBy",
                  "storageKey": null,
                  "args": null,
                  "concreteType": "User",
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
                },
                {
                  "kind": "ScalarField",
                  "alias": null,
                  "name": "viewerCanResolve",
                  "args": null,
                  "storageKey": null
                },
                {
                  "kind": "ScalarField",
                  "alias": null,
                  "name": "viewerCanUnresolve",
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
                  "name": "reviewCommentsAccumulator_reviewThread",
                  "args": [
                    {
                      "kind": "Variable",
                      "name": "commentCount",
                      "variableName": "commentCount"
                    },
                    {
                      "kind": "Variable",
                      "name": "commentCursor",
                      "variableName": "commentCursor"
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
// prettier-ignore
(node/*: any*/).hash = '15785e7c291c2dc79dbf6e534bcb7e76';
module.exports = node;
