import React from 'react';
import {graphql, createRefetchContainer} from 'react-relay';
import PropTypes from 'prop-types';
import cx from 'classnames';
import {Tab, Tabs, TabList, TabPanel} from 'react-tabs';

import {EnableableOperationPropType, ItemTypePropType, EndpointPropType, RefHolderPropType} from '../prop-types';
import {addEvent} from '../reporter-proxy';
import PeriodicRefresher from '../periodic-refresher';
import Octicon from '../atom/octicon';
import PullRequestChangedFilesContainer from '../containers/pr-changed-files-container';
import {checkoutStates} from '../controllers/pr-checkout-controller';
import PullRequestTimelineController from '../controllers/pr-timeline-controller';
import EmojiReactionsController from '../controllers/emoji-reactions-controller';
import GithubDotcomMarkdown from '../views/github-dotcom-markdown';
import IssueishBadge from '../views/issueish-badge';
import CheckoutButton from './checkout-button';
import PullRequestCommitsView from '../views/pr-commits-view';
import PullRequestStatusesView from '../views/pr-statuses-view';
import ReviewsFooterView from '../views/reviews-footer-view';
import {PAGE_SIZE, GHOST_USER} from '../helpers';

export class BarePullRequestDetailView extends React.Component {
  static propTypes = {
    // Relay response
    relay: PropTypes.shape({
      refetch: PropTypes.func.isRequired,
    }),
    repository: PropTypes.shape({
      id: PropTypes.string.isRequired,
      name: PropTypes.string.isRequired,
      owner: PropTypes.shape({
        login: PropTypes.string,
      }),
    }),
    pullRequest: PropTypes.shape({
      __typename: PropTypes.string.isRequired,
      id: PropTypes.string.isRequired,
      title: PropTypes.string,
      countedCommits: PropTypes.shape({
        totalCount: PropTypes.number.isRequired,
      }).isRequired,
      isCrossRepository: PropTypes.bool,
      changedFiles: PropTypes.number.isRequired,
      url: PropTypes.string.isRequired,
      bodyHTML: PropTypes.string,
      number: PropTypes.number,
      state: PropTypes.oneOf([
        'OPEN', 'CLOSED', 'MERGED',
      ]).isRequired,
      author: PropTypes.shape({
        login: PropTypes.string.isRequired,
        avatarUrl: PropTypes.string.isRequired,
        url: PropTypes.string.isRequired,
      }),
    }).isRequired,

    // Local model objects
    localRepository: PropTypes.object.isRequired,
    checkoutOp: EnableableOperationPropType.isRequired,
    workdirPath: PropTypes.string,

    // Review comment threads
    reviewCommentsLoading: PropTypes.bool.isRequired,
    reviewCommentsTotalCount: PropTypes.number.isRequired,
    reviewCommentsResolvedCount: PropTypes.number.isRequired,
    reviewCommentThreads: PropTypes.arrayOf(PropTypes.shape({
      thread: PropTypes.object.isRequired,
      comments: PropTypes.arrayOf(PropTypes.object).isRequired,
    })).isRequired,

    // Connection information
    endpoint: EndpointPropType.isRequired,
    token: PropTypes.string.isRequired,

    // Atom environment
    workspace: PropTypes.object.isRequired,
    commands: PropTypes.object.isRequired,
    keymaps: PropTypes.object.isRequired,
    tooltips: PropTypes.object.isRequired,
    config: PropTypes.object.isRequired,

    // Action functions
    openCommit: PropTypes.func.isRequired,
    openReviews: PropTypes.func.isRequired,
    switchToIssueish: PropTypes.func.isRequired,
    destroy: PropTypes.func.isRequired,
    reportRelayError: PropTypes.func.isRequired,

    // Item context
    itemType: ItemTypePropType.isRequired,
    refEditor: RefHolderPropType.isRequired,

    // Tab management
    initChangedFilePath: PropTypes.string,
    initChangedFilePosition: PropTypes.number,
    selectedTab: PropTypes.number.isRequired,
    onTabSelected: PropTypes.func.isRequired,
    onOpenFilesTab: PropTypes.func.isRequired,
  }

  state = {
    refreshing: false,
  }

  componentDidMount() {
    this.refresher = new PeriodicRefresher(BarePullRequestDetailView, {
      interval: () => 5 * 60 * 1000,
      getCurrentId: () => this.props.pullRequest.id,
      refresh: this.refresh,
      minimumIntervalPerId: 2 * 60 * 1000,
    });
    // auto-refresh disabled for now until pagination is handled
    // this.refresher.start();
  }

  componentWillUnmount() {
    this.refresher.destroy();
  }

  renderPrMetadata(pullRequest, repo) {
    const author = this.getAuthor(pullRequest);

    return (
      <span className="github-IssueishDetailView-meta">
        <code className="github-IssueishDetailView-baseRefName">{pullRequest.isCrossRepository ?
          `${repo.owner.login}/${pullRequest.baseRefName}` : pullRequest.baseRefName}</code>{' ‹ '}
        <code className="github-IssueishDetailView-headRefName">{pullRequest.isCrossRepository ?
          `${author.login}/${pullRequest.headRefName}` : pullRequest.headRefName}</code>
      </span>
    );
  }

  renderPullRequestBody(pullRequest) {
    const onBranch = this.props.checkoutOp.why() === checkoutStates.CURRENT;

    return (
      <Tabs selectedIndex={this.props.selectedTab} onSelect={this.onTabSelected}>
        <TabList className="github-tablist">
          <Tab className="github-tab">
            <Octicon icon="info" className="github-tab-icon" />Overview</Tab>
          <Tab className="github-tab">
            <Octicon icon="checklist" className="github-tab-icon" />
            Build Status
          </Tab>
          <Tab className="github-tab">
            <Octicon icon="git-commit"
              className="github-tab-icon"
            />
              Commits
            <span className="github-tab-count">
              {pullRequest.countedCommits.totalCount}
            </span>
          </Tab>
          <Tab className="github-tab">
            <Octicon icon="diff"
              className="github-tab-icon"
            />Files
            <span className="github-tab-count">{pullRequest.changedFiles}</span>
          </Tab>
        </TabList>
        {/* 'Reviews' tab to be added in the future. */}

        {/* overview */}
        <TabPanel>
          <div className="github-IssueishDetailView-overview">
            <GithubDotcomMarkdown
              html={pullRequest.bodyHTML || '<em>No description provided.</em>'}
              switchToIssueish={this.props.switchToIssueish}
            />
            <EmojiReactionsController
              reactable={pullRequest}
              tooltips={this.props.tooltips}
              reportRelayError={this.props.reportRelayError}
            />
            <PullRequestTimelineController
              onBranch={onBranch}
              openCommit={this.props.openCommit}
              pullRequest={pullRequest}
              switchToIssueish={this.props.switchToIssueish}
            />
          </div>
        </TabPanel>

        {/* build status */}
        <TabPanel>
          <div className="github-IssueishDetailView-buildStatus">
            <PullRequestStatusesView
              pullRequest={pullRequest}
              displayType="full"
              switchToIssueish={this.props.switchToIssueish}
            />
          </div>
        </TabPanel>

        {/* commits */}
        <TabPanel>
          <PullRequestCommitsView pullRequest={pullRequest} onBranch={onBranch} openCommit={this.props.openCommit} />
        </TabPanel>

        {/* files changed */}
        <TabPanel className="github-IssueishDetailView-filesChanged">
          <PullRequestChangedFilesContainer
            localRepository={this.props.localRepository}

            owner={this.props.repository.owner.login}
            repo={this.props.repository.name}
            number={pullRequest.number}
            endpoint={this.props.endpoint}
            token={this.props.token}

            reviewCommentsLoading={this.props.reviewCommentsLoading}
            reviewCommentThreads={this.props.reviewCommentThreads}

            workspace={this.props.workspace}
            commands={this.props.commands}
            keymaps={this.props.keymaps}
            tooltips={this.props.tooltips}
            config={this.props.config}
            workdirPath={this.props.workdirPath}

            itemType={this.props.itemType}
            refEditor={this.props.refEditor}
            destroy={this.props.destroy}

            shouldRefetch={this.state.refreshing}
            switchToIssueish={this.props.switchToIssueish}

            pullRequest={this.props.pullRequest}

            initChangedFilePath={this.props.initChangedFilePath}
            initChangedFilePosition={this.props.initChangedFilePosition}
            onOpenFilesTab={this.props.onOpenFilesTab}
          />
        </TabPanel>
      </Tabs>
    );
  }

  render() {
    const repo = this.props.repository;
    const pullRequest = this.props.pullRequest;
    const author = this.getAuthor(pullRequest);

    return (
      <div className="github-IssueishDetailView native-key-bindings">
        <div className="github-IssueishDetailView-container">

          <header className="github-IssueishDetailView-header">
            <div className="github-IssueishDetailView-headerColumn">
              <a className="github-IssueishDetailView-avatar" href={author.url}>
                <img className="github-IssueishDetailView-avatarImage"
                  src={author.avatarUrl}
                  title={author.login}
                  alt={author.login}
                />
              </a>
            </div>

            <div className="github-IssueishDetailView-headerColumn is-flexible">
              <div className="github-IssueishDetailView-headerRow is-fullwidth">
                <a className="github-IssueishDetailView-title" href={pullRequest.url}>{pullRequest.title}</a>
              </div>
              <div className="github-IssueishDetailView-headerRow">
                <IssueishBadge className="github-IssueishDetailView-headerBadge"
                  type={pullRequest.__typename}
                  state={pullRequest.state}
                />
                <Octicon
                  icon="repo-sync"
                  className={cx('github-IssueishDetailView-headerRefreshButton', {refreshing: this.state.refreshing})}
                  onClick={this.handleRefreshClick}
                />
                <a className="github-IssueishDetailView-headerLink"
                  title="open on GitHub.com"
                  href={pullRequest.url} onClick={this.recordOpenInBrowserEvent}>
                  {repo.owner.login}/{repo.name}#{pullRequest.number}
                </a>
                <span className="github-IssueishDetailView-headerStatus">
                  <PullRequestStatusesView
                    pullRequest={pullRequest}
                    displayType="check"
                    switchToIssueish={this.props.switchToIssueish}
                  />
                </span>
              </div>
              <div className="github-IssueishDetailView-headerRow">
                {this.renderPrMetadata(pullRequest, repo)}
              </div>
            </div>

            <div className="github-IssueishDetailView-headerColumn">
              <CheckoutButton
                checkoutOp={this.props.checkoutOp}
                classNamePrefix="github-IssueishDetailView-checkoutButton--"
                classNames={['github-IssueishDetailView-checkoutButton']}
              />
            </div>
          </header>

          {this.renderPullRequestBody(pullRequest)}

          <ReviewsFooterView
            commentsResolved={this.props.reviewCommentsResolvedCount}
            totalComments={this.props.reviewCommentsTotalCount}
            openReviews={this.props.openReviews}
            pullRequestURL={`${this.props.pullRequest.url}/files`}
          />
        </div>
      </div>
    );
  }

  handleRefreshClick = e => {
    e.preventDefault();
    this.refresher.refreshNow(true);
  }

  recordOpenInBrowserEvent = () => {
    addEvent('open-pull-request-in-browser', {package: 'github', component: this.constructor.name});
  }

  onTabSelected = index => {
    this.props.onTabSelected(index);
    const eventName = [
      'open-pr-tab-overview',
      'open-pr-tab-build-status',
      'open-pr-tab-commits',
      'open-pr-tab-files-changed',
    ][index];
    addEvent(eventName, {package: 'github', component: this.constructor.name});
  }

  refresh = () => {
    if (this.state.refreshing) {
      return;
    }

    this.setState({refreshing: true});
    this.props.relay.refetch({
      repoId: this.props.repository.id,
      issueishId: this.props.pullRequest.id,
      timelineCount: PAGE_SIZE,
      timelineCursor: null,
      commitCount: PAGE_SIZE,
      commitCursor: null,
    }, null, err => {
      if (err) {
        this.props.reportRelayError('Unable to refresh pull request details', err);
      }
      this.setState({refreshing: false});
    }, {force: true});
  }

  getAuthor(pullRequest) {
    return pullRequest.author || GHOST_USER;
  }
}

export default createRefetchContainer(BarePullRequestDetailView, {
  repository: graphql`
    fragment prDetailView_repository on Repository {
      id
      name
      owner {
        login
      }
    }
  `,

  pullRequest: graphql`
    fragment prDetailView_pullRequest on PullRequest
    @argumentDefinitions(
      timelineCount: {type: "Int!"}
      timelineCursor: {type: "String"}
      commitCount: {type: "Int!"}
      commitCursor: {type: "String"}
      checkSuiteCount: {type: "Int!"}
      checkSuiteCursor: {type: "String"}
      checkRunCount: {type: "Int!"}
      checkRunCursor: {type: "String"}
    ) {
      id
      __typename
      url
      isCrossRepository
      changedFiles
      state
      number
      title
      bodyHTML
      baseRefName
      headRefName
      countedCommits: commits {
        totalCount
      }
      author {
        login
        avatarUrl
        url
      }

      ...prCommitsView_pullRequest @arguments(commitCount: $commitCount, commitCursor: $commitCursor)
      ...prStatusesView_pullRequest @arguments(
        checkSuiteCount: $checkSuiteCount
        checkSuiteCursor: $checkSuiteCursor
        checkRunCount: $checkRunCount
        checkRunCursor: $checkRunCursor
      )
      ...prTimelineController_pullRequest @arguments(timelineCount: $timelineCount, timelineCursor: $timelineCursor)
      ...emojiReactionsController_reactable
    }
  `,
}, graphql`
  query prDetailViewRefetchQuery
  (
    $repoId: ID!
    $issueishId: ID!
    $timelineCount: Int!
    $timelineCursor: String
    $commitCount: Int!
    $commitCursor: String
    $checkSuiteCount: Int!
    $checkSuiteCursor: String
    $checkRunCount: Int!
    $checkRunCursor: String
  ) {
    repository: node(id: $repoId) {
      ...prDetailView_repository
    }

    pullRequest: node(id: $issueishId) {
      ...prDetailView_pullRequest @arguments(
        timelineCount: $timelineCount
        timelineCursor: $timelineCursor
        commitCount: $commitCount
        commitCursor: $commitCursor
        checkSuiteCount: $checkSuiteCount
        checkSuiteCursor: $checkSuiteCursor
        checkRunCount: $checkRunCount
        checkRunCursor: $checkRunCursor
      )
    }
  }
`);
