import {nextID} from '../id-sequence';
import {createSpecBuilderClass, createUnionBuilderClass, createConnectionBuilderClass} from './base';

import {ReactionGroupBuilder} from './reaction-group';
import {UserBuilder} from './user';
import {CrossReferencedEventBuilder, IssueCommentBuilder} from './timeline';

export const IssueTimelineItemBuilder = createUnionBuilderClass('IssueTimelineItems', {
  beCrossReferencedEvent: CrossReferencedEventBuilder,
  beIssueComment: IssueCommentBuilder,
});

export const IssueBuilder = createSpecBuilderClass('Issue', {
  __typename: {default: 'Issue'},
  id: {default: nextID},
  title: {default: 'Something is wrong'},
  number: {default: 123},
  state: {default: 'OPEN'},
  bodyHTML: {default: '<h1>HI</h1>'},
  author: {linked: UserBuilder, default: null, nullable: true},
  reactionGroups: {linked: ReactionGroupBuilder, plural: true, singularName: 'reactionGroup'},
  viewerCanReact: {default: true},
  timelineItems: {linked: createConnectionBuilderClass('IssueTimelineItems', IssueTimelineItemBuilder)},
  url: {default: f => {
    const id = f.id || '1';
    return `https://github.com/atom/github/issue/${id}`;
  }},
},
'Node & Assignable & Closable & Comment & Updatable & UpdatableComment & Labelable & Lockable & Reactable & ' +
  'RepositoryNode & Subscribable & UniformResourceLocatable',
);

export function issueBuilder(...nodes) {
  return IssueBuilder.onFragmentQuery(nodes);
}
