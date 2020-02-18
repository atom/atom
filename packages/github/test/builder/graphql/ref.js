import {createSpecBuilderClass, createConnectionBuilderClass, defer} from './base';
import {nextID} from '../id-sequence';

const PullRequestBuilder = defer('../pr', 'PullRequestBuilder');

export const RefBuilder = createSpecBuilderClass('Ref', {
  id: {default: nextID},
  prefix: {default: 'refs/heads/'},
  name: {default: 'master'},
  associatedPullRequests: {linked: createConnectionBuilderClass('PullRequest', PullRequestBuilder)},
}, 'Node');
