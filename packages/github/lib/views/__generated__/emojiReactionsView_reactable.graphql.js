/**
 * @flow
 */

/* eslint-disable */

'use strict';

/*::
import type { ReaderFragment } from 'relay-runtime';
export type ReactionContent = "CONFUSED" | "EYES" | "HEART" | "HOORAY" | "LAUGH" | "ROCKET" | "THUMBS_DOWN" | "THUMBS_UP" | "%future added value";
import type { FragmentReference } from "relay-runtime";
declare export opaque type emojiReactionsView_reactable$ref: FragmentReference;
declare export opaque type emojiReactionsView_reactable$fragmentType: emojiReactionsView_reactable$ref;
export type emojiReactionsView_reactable = {|
  +id: string,
  +reactionGroups: ?$ReadOnlyArray<{|
    +content: ReactionContent,
    +viewerHasReacted: boolean,
    +users: {|
      +totalCount: number
    |},
  |}>,
  +viewerCanReact: boolean,
  +$refType: emojiReactionsView_reactable$ref,
|};
export type emojiReactionsView_reactable$data = emojiReactionsView_reactable;
export type emojiReactionsView_reactable$key = {
  +$data?: emojiReactionsView_reactable$data,
  +$fragmentRefs: emojiReactionsView_reactable$ref,
};
*/


const node/*: ReaderFragment*/ = {
  "kind": "Fragment",
  "name": "emojiReactionsView_reactable",
  "type": "Reactable",
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
      "kind": "LinkedField",
      "alias": null,
      "name": "reactionGroups",
      "storageKey": null,
      "args": null,
      "concreteType": "ReactionGroup",
      "plural": true,
      "selections": [
        {
          "kind": "ScalarField",
          "alias": null,
          "name": "content",
          "args": null,
          "storageKey": null
        },
        {
          "kind": "ScalarField",
          "alias": null,
          "name": "viewerHasReacted",
          "args": null,
          "storageKey": null
        },
        {
          "kind": "LinkedField",
          "alias": null,
          "name": "users",
          "storageKey": null,
          "args": null,
          "concreteType": "ReactingUserConnection",
          "plural": false,
          "selections": [
            {
              "kind": "ScalarField",
              "alias": null,
              "name": "totalCount",
              "args": null,
              "storageKey": null
            }
          ]
        }
      ]
    },
    {
      "kind": "ScalarField",
      "alias": null,
      "name": "viewerCanReact",
      "args": null,
      "storageKey": null
    }
  ]
};
// prettier-ignore
(node/*: any*/).hash = 'fde156007f42d841401632fce79875d5';
module.exports = node;
