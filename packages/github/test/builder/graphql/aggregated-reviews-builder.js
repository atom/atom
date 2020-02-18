import {pullRequestBuilder, reviewThreadBuilder} from './pr';

import summariesQuery from '../../../lib/containers/accumulators/__generated__/reviewSummariesAccumulator_pullRequest.graphql.js';
import threadsQuery from '../../../lib/containers/accumulators/__generated__/reviewThreadsAccumulator_pullRequest.graphql.js';
import commentsQuery from '../../../lib/containers/accumulators/__generated__/reviewCommentsAccumulator_reviewThread.graphql.js';

class AggregatedReviewsBuilder {
  constructor() {
    this._reviewSummaryBuilder = pullRequestBuilder(summariesQuery);
    this._reviewThreadsBuilder = pullRequestBuilder(threadsQuery);
    this._commentsBuilders = [];

    this._summaryBlocks = [];
    this._threadBlocks = [];

    this._errors = [];
    this._loading = false;
  }

  addError(err) {
    this._errors.push(err);
    return this;
  }

  loading(_loading) {
    this._loading = _loading;
    return this;
  }

  addReviewSummary(block = () => {}) {
    this._summaryBlocks.push(block);
    return this;
  }

  addReviewThread(block = () => {}) {
    let threadBlock = () => {};
    const commentBlocks = [];

    const subBuilder = {
      thread(block0 = () => {}) {
        threadBlock = block0;
        return subBuilder;
      },

      addComment(block0 = () => {}) {
        commentBlocks.push(block0);
        return subBuilder;
      },
    };
    block(subBuilder);

    const commentBuilder = reviewThreadBuilder(commentsQuery);
    commentBuilder.comments(conn => {
      for (const block0 of commentBlocks) {
        conn.addEdge(e => e.node(block0));
      }
    });

    this._threadBlocks.push(threadBlock);
    this._commentsBuilders.push(commentBuilder);

    return this;
  }

  build() {
    this._reviewSummaryBuilder.reviews(conn => {
      for (const block of this._summaryBlocks) {
        conn.addEdge(e => e.node(block));
      }
    });
    const summariesPullRequest = this._reviewSummaryBuilder.build();
    const summaries = summariesPullRequest.reviews.edges.map(e => e.node);

    this._reviewThreadsBuilder.reviewThreads(conn => {
      for (const block of this._threadBlocks) {
        conn.addEdge(e => e.node(block));
      }
    });
    const threadsPullRequest = this._reviewThreadsBuilder.build();

    const commentThreads = threadsPullRequest.reviewThreads.edges.map((e, i) => {
      const thread = e.node;
      const commentsReviewThread = this._commentsBuilders[i].build();
      const comments = commentsReviewThread.comments.edges.map(e0 => e0.node);
      return {thread, comments};
    });

    return {
      errors: this._errors,
      loading: this._loading,
      summaries,
      commentThreads,
    };
  }
}

export function aggregatedReviewsBuilder() {
  return new AggregatedReviewsBuilder();
}
