import {createSpecBuilderClass, createConnectionBuilderClass, defer} from './base';
import {nextID} from '../id-sequence';

import {UserBuilder} from './user';
const IssueishBuilder = defer('../issueish', 'IssueishBuilder');

export const CheckRunBuilder = createSpecBuilderClass('CheckRun', {
  __typename: {default: 'CheckRun'},
  id: {default: nextID},
  status: {default: 'COMPLETED'},
  conclusion: {default: 'SUCCESS', nullable: true},
  name: {default: 'the-check-run'},
  title: {default: null, nullable: true},
  summary: {default: null, nullable: true},
  permalink: {default: 'https://github.com/owner/repo/runs/12345'},
  detailsUrl: {default: 'https://pushbot.party/check-run/1234', nullable: true},
}, 'Node & UniformResourceLocatable');

export const CheckRunConnection = createConnectionBuilderClass('CheckRunConnection', CheckRunBuilder);

export const AppBuilder = createSpecBuilderClass('App', {
  name: {default: 'some-app'},
}, 'Node');

export const CheckSuiteBuilder = createSpecBuilderClass('CheckSuite', {
  __typename: {default: 'CheckSuite'},
  id: {default: nextID},
  app: {linked: AppBuilder, nullable: true},
  status: {default: 'COMPLETED'},
  conclusion: {default: 'SUCCESS', nullable: true},
  checkRuns: {linked: CheckRunConnection, nullable: true},
}, 'Node');

export const CheckSuiteConnection = createConnectionBuilderClass('CheckSuiteConnection', CheckSuiteBuilder);

export const StatusContextBuilder = createSpecBuilderClass('StatusContext', {
  id: {default: nextID},
  context: {default: 'the context name'},
  description: {default: null, nullable: true},
  state: {default: 'SUCCESS'},
  targetUrl: {default: null, nullable: true},
}, 'Node');

export const StatusBuilder = createSpecBuilderClass('Status', {
  id: {default: nextID},
  state: {default: 'SUCCESS'},
  contexts: {linked: StatusContextBuilder, plural: true, singularName: 'context'},
}, 'Node');

export const CommitBuilder = createSpecBuilderClass('Commit', {
  id: {default: nextID},
  author: {linked: UserBuilder, default: null, nullable: true},
  committer: {linked: UserBuilder},
  authoredByCommitter: {default: true},
  sha: {default: '0000000000000000000000000000000000000000'},
  oid: {default: '0000000000000000000000000000000000000000'},
  message: {default: 'Commit message'},
  messageHeadlineHTML: {default: '<h1>Commit message</h1>'},
  commitUrl: {default: f => {
    const sha = f.oid || f.sha || '0000000000000000000000000000000000000000';
    return `https://github.com/atom/github/commit/${sha}`;
  }},
  status: {linked: StatusBuilder, nullable: true},
  checkSuites: {linked: CheckSuiteConnection, nullable: true},
}, 'Node & GitObject & Subscribable & UniformResourceLocatable');

export const CommitCommentBuilder = createSpecBuilderClass('CommitComment', {
  id: {default: nextID},
  author: {linked: UserBuilder, default: null, nullable: true},
  commit: {linked: CommitBuilder},
  bodyHTML: {default: '<em>comment body</em>'},
  createdAt: {default: '2019-01-01T10:00:00Z'},
  path: {default: 'file.txt'},
  position: {default: 0, nullable: true},
}, 'Node & Comment & Deletable & Updatable & UpdatableComment & Reactable & RepositoryNode');

export const PullRequestCommitCommentThreadBuilder = createSpecBuilderClass('PullRequestCommitCommentThread', {
  commit: {linked: CommitBuilder},
  comments: {linked: createConnectionBuilderClass('CommitComment', CommitCommentBuilder)},
}, 'Node & RepositoryNode');

export const CrossReferencedEventBuilder = createSpecBuilderClass('CrossReferencedEvent', {
  id: {default: nextID},
  referencedAt: {default: '2019-01-01T10:00:00Z'},
  isCrossRepository: {default: false},
  actor: {linked: UserBuilder},
  source: {linked: IssueishBuilder},
}, 'Node & UniformResourceLocatable');

export const HeadRefForcePushedEventBuilder = createSpecBuilderClass('HeadRefForcePushedEvent', {
  actor: {linked: UserBuilder},
  beforeCommit: {linked: CommitBuilder},
  afterCommit: {linked: CommitBuilder},
  createdAt: {default: '2019-01-01T10:00:00Z'},
}, 'Node');

export const IssueCommentBuilder = createSpecBuilderClass('IssueComment', {
  author: {linked: UserBuilder, default: null, nullable: true},
  bodyHTML: {default: '<em>issue comment</em>'},
  createdAt: {default: '2019-01-01T10:00:00Z'},
  url: {default: 'https://github.com/atom/github/issue/123'},
}, 'Node & Comment & Deletable & Updatable & UpdatableComment & Reactable & RepositoryNode');

export const MergedEventBuilder = createSpecBuilderClass('MergedEvent', {
  actor: {linked: UserBuilder},
  commit: {linked: CommitBuilder},
  mergeRefName: {default: 'master'},
  createdAt: {default: '2019-01-01T10:00:00Z'},
}, 'Node & UniformResourceLocatable');

export function commitBuilder(...nodes) {
  return CommitBuilder.onFragmentQuery(nodes);
}

export function contextBuilder(...nodes) {
  return StatusContextBuilder.onFragmentQuery(nodes);
}

export function checkSuiteBuilder(...nodes) {
  return CheckSuiteBuilder.onFragmentQuery(nodes);
}

export function checkRunBuilder(...nodes) {
  return CheckRunBuilder.onFragmentQuery(nodes);
}
