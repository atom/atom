import {createSpecBuilderClass, createConnectionBuilderClass, createUnionBuilderClass} from './base';
import {nextID} from '../id-sequence';

import {RepositoryBuilder} from './repository';
import {UserBuilder} from './user';
import {ReactionGroupBuilder} from './reaction-group';
import {
  CommitBuilder,
  PullRequestCommitCommentThreadBuilder,
  CrossReferencedEventBuilder,
  HeadRefForcePushedEventBuilder,
  IssueCommentBuilder,
  MergedEventBuilder,
} from './timeline';

export const PullRequestCommitBuilder = createSpecBuilderClass('PullRequestCommit', {
  id: {default: nextID},
  commit: {linked: CommitBuilder},
}, 'Node & UniformResourceLocatable');

export const PullRequestTimelineItemsBuilder = createUnionBuilderClass('PullRequestTimelineItems', {
  bePullRequestCommit: PullRequestCommitBuilder,
  bePullRequestCommitCommentThread: PullRequestCommitCommentThreadBuilder,
  beCrossReferencedEvent: CrossReferencedEventBuilder,
  beHeadRefForcePushedEvent: HeadRefForcePushedEventBuilder,
  beIssueComment: IssueCommentBuilder,
  beMergedEvent: MergedEventBuilder,
  default: 'beIssueComment',
});

export const CommentBuilder = createSpecBuilderClass('PullRequestReviewComment', {
  __typename: {default: 'PullRequestReviewComment'},
  id: {default: nextID},
  path: {default: 'first.txt'},
  position: {default: 0, nullable: true},
  diffHunk: {default: '@ -1,4 +1,5 @@'},
  author: {linked: UserBuilder, default: null, nullable: true},
  reactionGroups: {linked: ReactionGroupBuilder, plural: true, singularName: 'reactionGroup'},
  url: {default: 'https://github.com/atom/github/pull/1829/files#r242224689'},
  createdAt: {default: '2018-12-27T17:51:17Z'},
  lastEditedAt: {default: null, nullable: true},
  body: {default: 'Lorem ipsum dolor sit amet, te urbanitas appellantur est.'},
  bodyHTML: {default: 'Lorem ipsum dolor sit amet, te urbanitas appellantur est.'},
  replyTo: {default: null, nullable: true},
  isMinimized: {default: false},
  minimizedReason: {default: null, nullable: true},
  state: {default: 'SUBMITTED'},
  viewerCanReact: {default: true},
  viewerCanMinimize: {default: true},
  viewerCanUpdate: {default: true},
  authorAssociation: {default: 'NONE'},
}, 'Node & Comment & Deletable & Updatable & UpdatableComment & Reactable & RepositoryNode');

export const CommentConnectionBuilder = createConnectionBuilderClass('PullRequestReviewComment', CommentBuilder);

export const ReviewThreadBuilder = createSpecBuilderClass('PullRequestReviewThread', {
  __typename: {default: 'PullRequestReviewThread'},
  id: {default: nextID},
  isResolved: {default: false},
  viewerCanResolve: {default: f => !f.isResolved},
  viewerCanUnresolve: {default: f => !!f.isResolved},
  resolvedBy: {linked: UserBuilder},
  comments: {linked: CommentConnectionBuilder},
}, 'Node');

export const ReviewBuilder = createSpecBuilderClass('PullRequestReview', {
  __typename: {default: 'PullRequestReview'},
  id: {default: nextID},
  submittedAt: {default: '2018-12-28T20:40:55Z'},
  lastEditedAt: {default: null, nullable: true},
  url: {default: 'https://github.com/atom/github/pull/1995#pullrequestreview-223120384'},
  body: {default: 'Lorem <b>ipsum</b> dolor sit amet, consectetur adipisicing elit'},
  bodyHTML: {default: 'Lorem <b>ipsum</b> dolor sit amet, consectetur adipisicing elit'},
  state: {default: 'COMMENTED'},
  author: {linked: UserBuilder, default: null, nullable: true},
  comments: {linked: CommentConnectionBuilder},
  viewerCanReact: {default: true},
  viewerCanUpdate: {default: true},
  reactionGroups: {linked: ReactionGroupBuilder, plural: true, singularName: 'reactionGroup'},
  authorAssociation: {default: 'NONE'},
}, 'Node & Comment & Deletable & Updatable & UpdatableComment & Reactable & RepositoryNode');

export const CommitConnectionBuilder = createConnectionBuilderClass('PullRequestCommit', CommentBuilder);

export const PullRequestBuilder = createSpecBuilderClass('PullRequest', {
  id: {default: nextID},
  __typename: {default: 'PullRequest'},
  number: {default: 123},
  title: {default: 'the title'},
  baseRefName: {default: 'base-ref'},
  headRefName: {default: 'head-ref'},
  headRefOid: {default: '0000000000000000000000000000000000000000'},
  isCrossRepository: {default: false},
  changedFiles: {default: 5},
  state: {default: 'OPEN'},
  bodyHTML: {default: '', nullable: true},
  createdAt: {default: '2019-01-01T10:00:00Z'},
  countedCommits: {linked: CommitConnectionBuilder},
  url: {default: f => {
    const ownerLogin = (f.repository && f.repository.owner && f.repository.owner.login) || 'aaa';
    const repoName = (f.repository && f.repository.name) || 'bbb';
    const number = f.number || 1;
    return `https://github.com/${ownerLogin}/${repoName}/pull/${number}`;
  }},
  author: {linked: UserBuilder, nullable: true, default: null},
  repository: {linked: RepositoryBuilder},
  headRepository: {linked: RepositoryBuilder, nullable: true},
  headRepositoryOwner: {linked: UserBuilder},
  commits: {linked: createConnectionBuilderClass('PullRequestCommit', PullRequestCommitBuilder)},
  recentCommits: {linked: createConnectionBuilderClass('PullRequestCommit', PullRequestCommitBuilder)},
  reviews: {linked: createConnectionBuilderClass('ReviewConnection', ReviewBuilder)},
  reviewThreads: {linked: createConnectionBuilderClass('ReviewThreadConnection', ReviewThreadBuilder)},
  timelineItems: {linked: createConnectionBuilderClass('PullRequestTimelineItems', PullRequestTimelineItemsBuilder)},
  reactionGroups: {linked: ReactionGroupBuilder, plural: true, singularName: 'reactionGroup'},
  viewerCanReact: {default: true},
},
'Node & Assignable & Closable & Comment & Updatable & UpdatableComment & Labelable & Lockable & Reactable & ' +
'RepositoryNode & Subscribable & UniformResourceLocatable',
);

export function reviewThreadBuilder(...nodes) {
  return ReviewThreadBuilder.onFragmentQuery(nodes);
}

export function pullRequestBuilder(...nodes) {
  return PullRequestBuilder.onFragmentQuery(nodes);
}
