/**
 * @flow
 */

/* eslint-disable */

'use strict';

/*::
import type { ReaderFragment } from 'relay-runtime';
export type StatusState = "ERROR" | "EXPECTED" | "FAILURE" | "PENDING" | "SUCCESS" | "%future added value";
import type { FragmentReference } from "relay-runtime";
declare export opaque type prStatusContextView_context$ref: FragmentReference;
declare export opaque type prStatusContextView_context$fragmentType: prStatusContextView_context$ref;
export type prStatusContextView_context = {|
  +context: string,
  +description: ?string,
  +state: StatusState,
  +targetUrl: ?any,
  +$refType: prStatusContextView_context$ref,
|};
export type prStatusContextView_context$data = prStatusContextView_context;
export type prStatusContextView_context$key = {
  +$data?: prStatusContextView_context$data,
  +$fragmentRefs: prStatusContextView_context$ref,
};
*/


const node/*: ReaderFragment*/ = {
  "kind": "Fragment",
  "name": "prStatusContextView_context",
  "type": "StatusContext",
  "metadata": null,
  "argumentDefinitions": [],
  "selections": [
    {
      "kind": "ScalarField",
      "alias": null,
      "name": "context",
      "args": null,
      "storageKey": null
    },
    {
      "kind": "ScalarField",
      "alias": null,
      "name": "description",
      "args": null,
      "storageKey": null
    },
    {
      "kind": "ScalarField",
      "alias": null,
      "name": "state",
      "args": null,
      "storageKey": null
    },
    {
      "kind": "ScalarField",
      "alias": null,
      "name": "targetUrl",
      "args": null,
      "storageKey": null
    }
  ]
};
// prettier-ignore
(node/*: any*/).hash = 'e729074e494e07b59b4a177416eb7a3c';
module.exports = node;
