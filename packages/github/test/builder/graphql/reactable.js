import {createUnionBuilderClass} from './base';

import {IssueBuilder} from './issue';
import {PullRequestBuilder, CommentBuilder, ReviewBuilder} from './pr';

export const ReactableBuilder = createUnionBuilderClass('Reactable', {
  beIssue: IssueBuilder,
  bePullRequest: PullRequestBuilder,
  bePullRequestReviewComment: CommentBuilder,
  beReview: ReviewBuilder,
  default: 'beIssue',
});
