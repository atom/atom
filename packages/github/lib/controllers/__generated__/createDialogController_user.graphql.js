/**
 * @flow
 */

/* eslint-disable */

'use strict';

/*::
import type { ReaderFragment } from 'relay-runtime';
type repositoryHomeSelectionView_user$ref = any;
import type { FragmentReference } from "relay-runtime";
declare export opaque type createDialogController_user$ref: FragmentReference;
declare export opaque type createDialogController_user$fragmentType: createDialogController_user$ref;
export type createDialogController_user = {|
  +id: string,
  +$fragmentRefs: repositoryHomeSelectionView_user$ref,
  +$refType: createDialogController_user$ref,
|};
export type createDialogController_user$data = createDialogController_user;
export type createDialogController_user$key = {
  +$data?: createDialogController_user$data,
  +$fragmentRefs: createDialogController_user$ref,
};
*/


const node/*: ReaderFragment*/ = {
  "kind": "Fragment",
  "name": "createDialogController_user",
  "type": "User",
  "metadata": null,
  "argumentDefinitions": [
    {
      "kind": "LocalArgument",
      "name": "organizationCount",
      "type": "Int!",
      "defaultValue": null
    },
    {
      "kind": "LocalArgument",
      "name": "organizationCursor",
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
      "name": "repositoryHomeSelectionView_user",
      "args": [
        {
          "kind": "Variable",
          "name": "organizationCount",
          "variableName": "organizationCount"
        },
        {
          "kind": "Variable",
          "name": "organizationCursor",
          "variableName": "organizationCursor"
        }
      ]
    }
  ]
};
// prettier-ignore
(node/*: any*/).hash = '729f5d41fc5444c5f12632127f89ed21';
module.exports = node;
