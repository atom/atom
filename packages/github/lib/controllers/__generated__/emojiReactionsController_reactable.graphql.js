/**
 * @flow
 */

/* eslint-disable */

'use strict';

/*::
import type { ReaderFragment } from 'relay-runtime';
type emojiReactionsView_reactable$ref = any;
import type { FragmentReference } from "relay-runtime";
declare export opaque type emojiReactionsController_reactable$ref: FragmentReference;
declare export opaque type emojiReactionsController_reactable$fragmentType: emojiReactionsController_reactable$ref;
export type emojiReactionsController_reactable = {|
  +id: string,
  +$fragmentRefs: emojiReactionsView_reactable$ref,
  +$refType: emojiReactionsController_reactable$ref,
|};
export type emojiReactionsController_reactable$data = emojiReactionsController_reactable;
export type emojiReactionsController_reactable$key = {
  +$data?: emojiReactionsController_reactable$data,
  +$fragmentRefs: emojiReactionsController_reactable$ref,
};
*/


const node/*: ReaderFragment*/ = {
  "kind": "Fragment",
  "name": "emojiReactionsController_reactable",
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
      "kind": "FragmentSpread",
      "name": "emojiReactionsView_reactable",
      "args": null
    }
  ]
};
// prettier-ignore
(node/*: any*/).hash = 'cfdd39cd7aa02bce0bdcd52bc0154223';
module.exports = node;
