import React from 'react';
import path from 'path';
import PropTypes from 'prop-types';
import {createFragmentContainer, graphql} from 'react-relay';

import {RemoteSetPropType, BranchSetPropType, EndpointPropType, WorkdirContextPoolPropType} from '../prop-types';
import ReviewsView from '../views/reviews-view';
import PullRequestCheckoutController from '../controllers/pr-checkout-controller';
import addReviewMutation from '../mutations/add-pr-review';
import addReviewCommentMutation from '../mutations/add-pr-review-comment';
import submitReviewMutation from '../mutations/submit-pr-review';
import deleteReviewMutation from '../mutations/delete-pr-review';
import resolveReviewThreadMutation from '../mutations/resolve-review-thread';
import unresolveReviewThreadMutation from '../mutations/unresolve-review-thread';
import updatePrReviewCommentMutation from '../mutations/update-pr-review-comment';
import updatePrReviewSummaryMutation from '../mutations/update-pr-review-summary';
import IssueishDetailItem from '../items/issueish-detail-item';
import {addEvent} from '../reporter-proxy';

// Milliseconds to update highlightedThreadIDs
const FLASH_DELAY = 1500;

export class BareReviewsController extends React.Component {
  static propTypes = {
    // Relay results
    relay: PropTypes.shape({
      environment: PropTypes.object.isRequired,
    }).isRequired,
    viewer: PropTypes.shape({
      id: PropTypes.string.isRequired,
    }).isRequired,
    repository: PropTypes.object.isRequired,
    pullRequest: PropTypes.shape({
      id: PropTypes.string.isRequired,
    }).isRequired,
    summaries: PropTypes.array.isRequired,
    commentThreads: PropTypes.arrayOf(PropTypes.shape({
      thread: PropTypes.object.isRequired,
      comments: PropTypes.arrayOf(PropTypes.object).isRequired,
    })),
    refetch: PropTypes.func.isRequired,

    // Package models
    workdirContextPool: WorkdirContextPoolPropType.isRequired,
    localRepository: PropTypes.object.isRequired,
    isAbsent: PropTypes.bool.isRequired,
    isLoading: PropTypes.bool.isRequired,
    isPresent: PropTypes.bool.isRequired,
    isMerging: PropTypes.bool.isRequired,
    isRebasing: PropTypes.bool.isRequired,
    branches: BranchSetPropType.isRequired,
    remotes: RemoteSetPropType.isRequired,
    multiFilePatch: PropTypes.object.isRequired,
    initThreadID: PropTypes.string,

    // Connection properties
    endpoint: EndpointPropType.isRequired,

    // URL parameters
    owner: PropTypes.string.isRequired,
    repo: PropTypes.string.isRequired,
    number: PropTypes.number.isRequired,
    workdir: PropTypes.string.isRequired,

    // Atom environment
    workspace: PropTypes.object.isRequired,
    config: PropTypes.object.isRequired,
    commands: PropTypes.object.isRequired,
    tooltips: PropTypes.object.isRequired,
    confirm: PropTypes.func.isRequired,

    // Action methods
    reportRelayError: PropTypes.func.isRequired,
  }

  constructor(props) {
    super(props);

    this.state = {
      contextLines: 4,
      postingToThreadID: null,
      scrollToThreadID: this.props.initThreadID,
      summarySectionOpen: true,
      commentSectionOpen: true,
      threadIDsOpen: new Set(
        this.props.initThreadID ? [this.props.initThreadID] : [],
      ),
      highlightedThreadIDs: new Set(),
    };
  }

  componentDidMount() {
    const {scrollToThreadID} = this.state;
    if (scrollToThreadID) {
      this.highlightThread(scrollToThreadID);
    }
  }

  componentDidUpdate(prevProps) {
    const {initThreadID} = this.props;
    if (initThreadID && initThreadID !== prevProps.initThreadID) {
      this.setState(prev => {
        prev.threadIDsOpen.add(initThreadID);
        this.highlightThread(initThreadID);
        return {commentSectionOpen: true, scrollToThreadID: initThreadID};
      });
    }
  }

  render() {
    return (
      <PullRequestCheckoutController
        repository={this.props.repository}
        pullRequest={this.props.pullRequest}

        localRepository={this.props.localRepository}
        isAbsent={this.props.isAbsent}
        isLoading={this.props.isLoading}
        isPresent={this.props.isPresent}
        isMerging={this.props.isMerging}
        isRebasing={this.props.isRebasing}
        branches={this.props.branches}
        remotes={this.props.remotes}>

        {checkoutOp => (
          <ReviewsView
            checkoutOp={checkoutOp}
            contextLines={this.state.contextLines}
            postingToThreadID={this.state.postingToThreadID}
            summarySectionOpen={this.state.summarySectionOpen}
            commentSectionOpen={this.state.commentSectionOpen}
            threadIDsOpen={this.state.threadIDsOpen}
            highlightedThreadIDs={this.state.highlightedThreadIDs}
            scrollToThreadID={this.state.scrollToThreadID}

            moreContext={this.moreContext}
            lessContext={this.lessContext}
            openFile={this.openFile}
            openDiff={this.openDiff}
            openPR={this.openPR}
            openIssueish={this.openIssueish}
            showSummaries={this.showSummaries}
            hideSummaries={this.hideSummaries}
            showComments={this.showComments}
            hideComments={this.hideComments}
            showThreadID={this.showThreadID}
            hideThreadID={this.hideThreadID}
            resolveThread={this.resolveThread}
            unresolveThread={this.unresolveThread}
            addSingleComment={this.addSingleComment}
            updateComment={this.updateComment}
            updateSummary={this.updateSummary}
            {...this.props}
          />
        )}

      </PullRequestCheckoutController>
    );
  }

  openFile = async (filePath, lineNumber) => {
    await this.props.workspace.open(
      path.join(this.props.workdir, filePath), {
        initialLine: lineNumber - 1,
        initialColumn: 0,
        pending: true,
      });
    addEvent('reviews-dock-open-file', {package: 'github'});
  }

  openDiff = async (filePath, lineNumber) => {
    const item = await this.getPRDetailItem();
    item.openFilesTab({
      changedFilePath: filePath,
      changedFilePosition: lineNumber,
    });
    addEvent('reviews-dock-open-diff', {package: 'github', component: this.constructor.name});
  }

  openPR = async () => {
    await this.getPRDetailItem();
    addEvent('reviews-dock-open-pr', {package: 'github', component: this.constructor.name});
  }

  getPRDetailItem = () => {
    return this.props.workspace.open(
      IssueishDetailItem.buildURI({
        host: this.props.endpoint.getHost(),
        owner: this.props.owner,
        repo: this.props.repo,
        number: this.props.number,
        workdir: this.props.workdir,
      }), {
        pending: true,
        searchAllPanes: true,
      },
    );
  }

  moreContext = () => {
    this.setState(prev => ({contextLines: prev.contextLines + 1}));
    addEvent('reviews-dock-show-more-context', {package: 'github'});
  }

  lessContext = () => {
    this.setState(prev => ({contextLines: Math.max(prev.contextLines - 1, 1)}));
    addEvent('reviews-dock-show-less-context', {package: 'github'});
  }

  openIssueish = async (owner, repo, number) => {
    const host = this.props.endpoint.getHost();

    const homeRepository = await this.props.localRepository.hasGitHubRemote(host, owner, repo)
      ? this.props.localRepository
      : (await this.props.workdirContextPool.getMatchingContext(host, owner, repo)).getRepository();

    const uri = IssueishDetailItem.buildURI({
      host, owner, repo, number, workdir: homeRepository.getWorkingDirectoryPath(),
    });
    return this.props.workspace.open(uri, {pending: true, searchAllPanes: true});
  }

  showSummaries = () => new Promise(resolve => this.setState({summarySectionOpen: true}, resolve));

  hideSummaries = () => new Promise(resolve => this.setState({summarySectionOpen: false}, resolve));

  showComments = () => new Promise(resolve => this.setState({commentSectionOpen: true}, resolve));

  hideComments = () => new Promise(resolve => this.setState({commentSectionOpen: false}, resolve));

  showThreadID = commentID => new Promise(resolve => this.setState(state => {
    state.threadIDsOpen.add(commentID);
    return {};
  }, resolve));

  hideThreadID = commentID => new Promise(resolve => this.setState(state => {
    state.threadIDsOpen.delete(commentID);
    return {};
  }, resolve));

  highlightThread = threadID => {
    this.setState(state => {
      state.highlightedThreadIDs.add(threadID);
      return {};
    }, () => {
      setTimeout(() => this.setState(state => {
        state.highlightedThreadIDs.delete(threadID);
        if (state.scrollToThreadID === threadID) {
          return {scrollToThreadID: null};
        }
        return {};
      }), FLASH_DELAY);
    });
  }

  resolveThread = async thread => {
    if (thread.viewerCanResolve) {
      // optimistically hide the thread to avoid jankiness;
      // if the operation fails, the onError callback will revert it.
      this.hideThreadID(thread.id);
      try {
        await resolveReviewThreadMutation(this.props.relay.environment, {
          threadID: thread.id,
          viewerID: this.props.viewer.id,
          viewerLogin: this.props.viewer.login,
        });
        this.highlightThread(thread.id);
        addEvent('resolve-comment-thread', {package: 'github'});
      } catch (err) {
        this.showThreadID(thread.id);
        this.props.reportRelayError('Unable to resolve the comment thread', err);
      }
    }
  }

  unresolveThread = async thread => {
    if (thread.viewerCanUnresolve) {
      try {
        await unresolveReviewThreadMutation(this.props.relay.environment, {
          threadID: thread.id,
          viewerID: this.props.viewer.id,
          viewerLogin: this.props.viewer.login,
        });
        this.highlightThread(thread.id);
        addEvent('unresolve-comment-thread', {package: 'github'});
      } catch (err) {
        this.props.reportRelayError('Unable to unresolve the comment thread', err);
      }
    }
  }

  addSingleComment = async (commentBody, threadID, replyToID, commentPath, position, callbacks = {}) => {
    let pendingReviewID = null;
    try {
      this.setState({postingToThreadID: threadID});

      const reviewResult = await addReviewMutation(this.props.relay.environment, {
        pullRequestID: this.props.pullRequest.id,
        viewerID: this.props.viewer.id,
      });
      const reviewID = reviewResult.addPullRequestReview.reviewEdge.node.id;
      pendingReviewID = reviewID;

      const commentPromise = addReviewCommentMutation(this.props.relay.environment, {
        body: commentBody,
        inReplyTo: replyToID,
        reviewID,
        threadID,
        viewerID: this.props.viewer.id,
        path: commentPath,
        position,
      });
      if (callbacks.didSubmitComment) {
        callbacks.didSubmitComment();
      }
      await commentPromise;
      pendingReviewID = null;

      await submitReviewMutation(this.props.relay.environment, {
        event: 'COMMENT',
        reviewID,
      });
      addEvent('add-single-comment', {package: 'github'});
    } catch (error) {
      if (callbacks.didFailComment) {
        callbacks.didFailComment();
      }

      if (pendingReviewID !== null) {
        try {
          await deleteReviewMutation(this.props.relay.environment, {
            reviewID: pendingReviewID,
            pullRequestID: this.props.pullRequest.id,
          });
        } catch (e) {
          /* istanbul ignore else */
          if (error.errors && e.errors) {
            error.errors.push(...e.errors);
          } else {
            // eslint-disable-next-line no-console
            console.warn('Unable to delete pending review', e);
          }
        }
      }

      this.props.reportRelayError('Unable to submit your comment', error);
    } finally {
      this.setState({postingToThreadID: null});
    }
  }

  updateComment = async (commentId, commentBody) => {
    try {
      await updatePrReviewCommentMutation(this.props.relay.environment, {
        commentId,
        commentBody,
      });
      addEvent('update-review-comment', {package: 'github'});
    } catch (error) {
      this.props.reportRelayError('Unable to update comment', error);
      throw error;
    }
  }

  updateSummary = async (reviewId, reviewBody) => {
    try {
      await updatePrReviewSummaryMutation(this.props.relay.environment, {
        reviewId,
        reviewBody,
      });
      addEvent('update-review-summary', {package: 'github'});
    } catch (error) {
      this.props.reportRelayError('Unable to update review summary', error);
      throw error;
    }
  }
}

export default createFragmentContainer(BareReviewsController, {
  viewer: graphql`
    fragment reviewsController_viewer on User {
      id
      login
      avatarUrl
    }
  `,
  repository: graphql`
    fragment reviewsController_repository on Repository {
      ...prCheckoutController_repository
    }
  `,
  pullRequest: graphql`
    fragment reviewsController_pullRequest on PullRequest {
      id
      ...prCheckoutController_pullRequest
    }
  `,
});
