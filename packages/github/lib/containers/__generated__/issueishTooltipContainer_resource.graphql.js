/**
 * @flow
 */

/* eslint-disable */

'use strict';

/*::
import type { ReaderFragment } from 'relay-runtime';
export type IssueState = "CLOSED" | "OPEN" | "%future added value";
export type PullRequestState = "CLOSED" | "MERGED" | "OPEN" | "%future added value";
import type { FragmentReference } from "relay-runtime";
declare export opaque type issueishTooltipContainer_resource$ref: FragmentReference;
declare export opaque type issueishTooltipContainer_resource$fragmentType: issueishTooltipContainer_resource$ref;
export type issueishTooltipContainer_resource = {|
  +__typename: "Issue",
  +state: IssueState,
  +number: number,
  +title: string,
  +repository: {|
    +name: string,
    +owner: {|
      +login: string
    |},
  |},
  +author: ?{|
    +login: string,
    +avatarUrl: any,
  |},
  +$refType: issueishTooltipContainer_resource$ref,
|} | {|
  +__typename: "PullRequest",
  +state: PullRequestState,
  +number: number,
  +title: string,
  +repository: {|
    +name: string,
    +owner: {|
      +login: string
    |},
  |},
  +author: ?{|
    +login: string,
    +avatarUrl: any,
  |},
  +$refType: issueishTooltipContainer_resource$ref,
|} | {|
  // This will never be '%other', but we need some
  // value in case none of the concrete values match.
  +__typename: "%other",
  +$refType: issueishTooltipContainer_resource$ref,
|};
export type issueishTooltipContainer_resource$data = issueishTooltipContainer_resource;
export type issueishTooltipContainer_resource$key = {
  +$data?: issueishTooltipContainer_resource$data,
  +$fragmentRefs: issueishTooltipContainer_resource$ref,
};
*/


const node/*: ReaderFragment*/ = (function(){
var v0 = {
  "kind": "ScalarField",
  "alias": null,
  "name": "login",
  "args": null,
  "storageKey": null
},
v1 = [
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
    "kind": "LinkedField",
    "alias": null,
    "name": "repository",
    "storageKey": null,
    "args": null,
    "concreteType": "Repository",
    "plural": false,
    "selections": [
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
  }
];
return {
  "kind": "Fragment",
  "name": "issueishTooltipContainer_resource",
  "type": "UniformResourceLocatable",
  "metadata": null,
  "argumentDefinitions": [],
  "selections": [
    {
      "kind": "ScalarField",
      "alias": null,
      "name": "__typename",
      "args": null,
      "storageKey": null
    },
    {
      "kind": "InlineFragment",
      "type": "Issue",
      "selections": (v1/*: any*/)
    },
    {
      "kind": "InlineFragment",
      "type": "PullRequest",
      "selections": (v1/*: any*/)
    }
  ]
};
})();
// prettier-ignore
(node/*: any*/).hash = '8980fc73c7ed3f632f0612ce14f2f0d1';
module.exports = node;
