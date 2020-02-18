import {createUnionBuilderClass} from './base';

import {PullRequestBuilder} from './pr';
import {IssueBuilder} from './issue';

export const IssueishBuilder = createUnionBuilderClass('Issueish', {
  beIssue: IssueBuilder,
  bePullRequest: PullRequestBuilder,
  default: 'beIssue',
});
