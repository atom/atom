/**
 * @flow
 */

/* eslint-disable */

'use strict';

/*::
import type { ReaderFragment } from 'relay-runtime';
type reviewSummariesAccumulator_pullRequest$ref = any;
type reviewThreadsAccumulator_pullRequest$ref = any;
import type { FragmentReference } from "relay-runtime";
declare export opaque type aggregatedReviewsContainer_pullRequest$ref: FragmentReference;
declare export opaque type aggregatedReviewsContainer_pullRequest$fragmentType: aggregatedReviewsContainer_pullRequest$ref;
export type aggregatedReviewsContainer_pullRequest = {|
  +id: string,
  +$fragmentRefs: reviewSummariesAccumulator_pullRequest$ref & reviewThreadsAccumulator_pullRequest$ref,
  +$refType: aggregatedReviewsContainer_pullRequest$ref,
|};
export type aggregatedReviewsContainer_pullRequest$data = aggregatedReviewsContainer_pullRequest;
export type aggregatedReviewsContainer_pullRequest$key = {
  +$data?: aggregatedReviewsContainer_pullRequest$data,
  +$fragmentRefs: aggregatedReviewsContainer_pullRequest$ref,
};
*/


const node/*: ReaderFragment*/ = {
  "kind": "Fragment",
  "name": "aggregatedReviewsContainer_pullRequest",
  "type": "PullRequest",
  "metadata": null,
  "argumentDefinitions": [
    {
      "kind": "LocalArgument",
      "name": "reviewCount",
      "type": "Int!",
      "defaultValue": null
    },
    {
      "kind": "LocalArgument",
      "name": "reviewCursor",
      "type": "String",
      "defaultValue": null
    },
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
      "name": "id",
      "args": null,
      "storageKey": null
    },
    {
      "kind": "FragmentSpread",
      "name": "reviewSummariesAccumulator_pullRequest",
      "args": [
        {
          "kind": "Variable",
          "name": "reviewCount",
          "variableName": "reviewCount"
        },
        {
          "kind": "Variable",
          "name": "reviewCursor",
          "variableName": "reviewCursor"
        }
      ]
    },
    {
      "kind": "FragmentSpread",
      "name": "reviewThreadsAccumulator_pullRequest",
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
        },
        {
          "kind": "Variable",
          "name": "threadCount",
          "variableName": "threadCount"
        },
        {
          "kind": "Variable",
          "name": "threadCursor",
          "variableName": "threadCursor"
        }
      ]
    }
  ]
};
// prettier-ignore
(node/*: any*/).hash = '830225d5b83d6c320e16cf824fe0cca6';
module.exports = node;
