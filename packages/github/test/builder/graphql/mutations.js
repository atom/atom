import {createSpecBuilderClass} from './base';

import {CommentBuilder, ReviewBuilder, ReviewThreadBuilder} from './pr';
import {ReactableBuilder} from './reactable';
import {RepositoryBuilder} from './repository';

const ReviewEdgeBuilder = createSpecBuilderClass('PullRequestReviewEdge', {
  node: {linked: ReviewBuilder},
});

const CommentEdgeBuilder = createSpecBuilderClass('PullRequestReviewCommentEdge', {
  node: {linked: CommentBuilder},
});

export const AddPullRequestReviewPayloadBuilder = createSpecBuilderClass('AddPullRequestReviewPayload', {
  reviewEdge: {linked: ReviewEdgeBuilder},
});

export const AddPullRequestReviewCommentPayloadBuilder = createSpecBuilderClass('AddPullRequestReviewCommentPayload', {
  commentEdge: {linked: CommentEdgeBuilder},
});

export const UpdatePullRequestReviewCommentPayloadBuilder = createSpecBuilderClass('UpdatePullRequestReviewCommentPayload', {
  pullRequestReviewComment: {linked: CommentBuilder},
});

export const SubmitPullRequestReviewPayloadBuilder = createSpecBuilderClass('SubmitPullRequestReviewPayload', {
  pullRequestReview: {linked: ReviewBuilder},
});

export const UpdatePullRequestReviewPayloadBuilder = createSpecBuilderClass('UpdatePullRequestReviewPayload', {
  pullRequestReview: {linked: ReviewBuilder},
});

export const DeletePullRequestReviewPayloadBuilder = createSpecBuilderClass('DeletePullRequestReviewPayload', {
  pullRequestReview: {linked: ReviewBuilder, nullable: true},
});

export const ResolveReviewThreadPayloadBuilder = createSpecBuilderClass('ResolveReviewThreadPayload', {
  thread: {linked: ReviewThreadBuilder},
});

export const UnresolveReviewThreadPayloadBuilder = createSpecBuilderClass('UnresolveReviewThreadPayload', {
  thread: {linked: ReviewThreadBuilder},
});

export const AddReactionPayloadBuilder = createSpecBuilderClass('AddReactionPayload', {
  subject: {linked: ReactableBuilder},
});

export const RemoveReactionPayloadBuilder = createSpecBuilderClass('RemoveReactionPayload', {
  subject: {linked: ReactableBuilder},
});

export const CreateRepositoryPayloadBuilder = createSpecBuilderClass('CreateRepositoryPayload', {
  repository: {linked: RepositoryBuilder},
});
