/**
 * @flow
 */

/* eslint-disable */

'use strict';

/*::
import type { ReaderFragment } from 'relay-runtime';
type emojiReactionsView_reactable$ref = any;
type issueTimelineController_issue$ref = any;
export type IssueState = "CLOSED" | "OPEN" | "%future added value";
import type { FragmentReference } from "relay-runtime";
declare export opaque type issueDetailView_issue$ref: FragmentReference;
declare export opaque type issueDetailView_issue$fragmentType: issueDetailView_issue$ref;
export type issueDetailView_issue = {|
  +id: string,
  +url: any,
  +state: IssueState,
  +number: number,
  +title: string,
  +bodyHTML: any,
  +author: ?{|
    +login: string,
    +avatarUrl: any,
    +url: any,
  |},
  +__typename: "Issue",
  +$fragmentRefs: issueTimelineController_issue$ref & emojiReactionsView_reactable$ref,
  +$refType: issueDetailView_issue$ref,
|};
export type issueDetailView_issue$data = issueDetailView_issue;
export type issueDetailView_issue$key = {
  +$data?: issueDetailView_issue$data,
  +$fragmentRefs: issueDetailView_issue$ref,
};
*/


const node/*: ReaderFragment*/ = (function(){
var v0 = {
  "kind": "ScalarField",
  "alias": null,
  "name": "url",
  "args": null,
  "storageKey": null
};
return {
  "kind": "Fragment",
  "name": "issueDetailView_issue",
  "type": "Issue",
  "metadata": null,
  "argumentDefinitions": [
    {
      "kind": "LocalArgument",
      "name": "timelineCount",
      "type": "Int!",
      "defaultValue": null
    },
    {
      "kind": "LocalArgument",
      "name": "timelineCursor",
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
      "kind": "ScalarField",
      "alias": null,
      "name": "__typename",
      "args": null,
      "storageKey": null
    },
    (v0/*: any*/),
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
      "name": "bodyHTML",
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
        {
          "kind": "ScalarField",
          "alias": null,
          "name": "login",
          "args": null,
          "storageKey": null
        },
        {
          "kind": "ScalarField",
          "alias": null,
          "name": "avatarUrl",
          "args": null,
          "storageKey": null
        },
        (v0/*: any*/)
      ]
    },
    {
      "kind": "FragmentSpread",
      "name": "issueTimelineController_issue",
      "args": [
        {
          "kind": "Variable",
          "name": "timelineCount",
          "variableName": "timelineCount"
        },
        {
          "kind": "Variable",
          "name": "timelineCursor",
          "variableName": "timelineCursor"
        }
      ]
    },
    {
      "kind": "FragmentSpread",
      "name": "emojiReactionsView_reactable",
      "args": null
    }
  ]
};
})();
// prettier-ignore
(node/*: any*/).hash = 'f7adc2e75c1d55df78481fd359bf7180';
module.exports = node;
