import React from 'react';
import {graphql, createRefetchContainer} from 'react-relay';
import PropTypes from 'prop-types';
import cx from 'classnames';

import IssueTimelineController from '../controllers/issue-timeline-controller';
import EmojiReactionsController from '../controllers/emoji-reactions-controller';
import Octicon from '../atom/octicon';
import IssueishBadge from '../views/issueish-badge';
import GithubDotcomMarkdown from '../views/github-dotcom-markdown';
import PeriodicRefresher from '../periodic-refresher';
import {addEvent} from '../reporter-proxy';
import {GHOST_USER} from '../helpers';

export class BareIssueDetailView extends React.Component {
  static propTypes = {
    // Relay response
    relay: PropTypes.shape({
      refetch: PropTypes.func.isRequired,
    }),
    switchToIssueish: PropTypes.func.isRequired,
    repository: PropTypes.shape({
      id: PropTypes.string.isRequired,
      name: PropTypes.string.isRequired,
      owner: PropTypes.shape({
        login: PropTypes.string,
      }),
    }),
    issue: PropTypes.shape({
      __typename: PropTypes.string.isRequired,
      id: PropTypes.string.isRequired,
      title: PropTypes.string,
      url: PropTypes.string.isRequired,
      bodyHTML: PropTypes.string,
      number: PropTypes.number,
      state: PropTypes.oneOf([
        'OPEN', 'CLOSED',
      ]).isRequired,
      author: PropTypes.shape({
        login: PropTypes.string.isRequired,
        avatarUrl: PropTypes.string.isRequired,
        url: PropTypes.string.isRequired,
      }).isRequired,
      reactionGroups: PropTypes.arrayOf(
        PropTypes.shape({
          content: PropTypes.string.isRequired,
          users: PropTypes.shape({
            totalCount: PropTypes.number.isRequired,
          }).isRequired,
        }),
      ).isRequired,
    }).isRequired,

    // Atom environment
    tooltips: PropTypes.object.isRequired,

    // Action methods
    reportRelayError: PropTypes.func.isRequired,
  }

  state = {
    refreshing: false,
  }

  componentDidMount() {
    this.refresher = new PeriodicRefresher(BareIssueDetailView, {
      interval: () => 5 * 60 * 1000,
      getCurrentId: () => this.props.issue.id,
      refresh: this.refresh,
      minimumIntervalPerId: 2 * 60 * 1000,
    });
    // auto-refresh disabled for now until pagination is handled
    // this.refresher.start();
  }

  componentWillUnmount() {
    this.refresher.destroy();
  }

  renderIssueBody(issue) {
    return (
      <div className="github-IssueishDetailView-issueBody">
        <GithubDotcomMarkdown
          html={issue.bodyHTML || '<em>No description provided.</em>'}
          switchToIssueish={this.props.switchToIssueish}
        />
        <EmojiReactionsController
          reactable={issue}
          tooltips={this.props.tooltips}
          reportRelayError={this.props.reportRelayError}
        />
        <IssueTimelineController
          issue={issue}
          switchToIssueish={this.props.switchToIssueish}
        />
      </div>
    );
  }

  render() {
    const repo = this.props.repository;
    const issue = this.props.issue;
    const author = issue.author || GHOST_USER;

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
                <a className="github-IssueishDetailView-title" href={issue.url}>{issue.title}</a>
              </div>
              <div className="github-IssueishDetailView-headerRow">
                <IssueishBadge className="github-IssueishDetailView-headerBadge"
                  type={issue.__typename}
                  state={issue.state}
                />
                <Octicon
                  icon="repo-sync"
                  className={cx('github-IssueishDetailView-headerRefreshButton', {refreshing: this.state.refreshing})}
                  onClick={this.handleRefreshClick}
                />
                <a className="github-IssueishDetailView-headerLink"
                  title="open on GitHub.com"
                  href={issue.url} onClick={this.recordOpenInBrowserEvent}>
                  {repo.owner.login}/{repo.name}#{issue.number}
                </a>
              </div>
            </div>
          </header>

          {this.renderIssueBody(issue)}

          <footer className="github-IssueishDetailView-footer">
            <a className="github-IssueishDetailView-footerLink icon icon-mark-github"
              href={issue.url}>{repo.owner.login}/{repo.name}#{issue.number}
            </a>
          </footer>

        </div>
      </div>
    );
  }

  handleRefreshClick = e => {
    e.preventDefault();
    this.refresher.refreshNow(true);
  }

  recordOpenInBrowserEvent = () => {
    addEvent('open-issue-in-browser', {package: 'github', component: this.constructor.name});
  }

  refresh = () => {
    if (this.state.refreshing) {
      return;
    }

    this.setState({refreshing: true});
    this.props.relay.refetch({
      repoId: this.props.repository.id,
      issueishId: this.props.issue.id,
      timelineCount: 100,
      timelineCursor: null,
    }, null, err => {
      if (err) {
        this.props.reportRelayError('Unable to refresh issue details', err);
      }
      this.setState({refreshing: false});
    }, {force: true});
  }
}

export default createRefetchContainer(BareIssueDetailView, {
  repository: graphql`
    fragment issueDetailView_repository on Repository {
      id
      name
      owner {
        login
      }
    }
  `,

  issue: graphql`
    fragment issueDetailView_issue on Issue
    @argumentDefinitions(
      timelineCount: {type: "Int!"},
      timelineCursor: {type: "String"},
    ) {
      id
      __typename
      url
      state
      number
      title
      bodyHTML
      author {
        login
        avatarUrl
        url
      }

      ...issueTimelineController_issue @arguments(timelineCount: $timelineCount, timelineCursor: $timelineCursor)
      ...emojiReactionsView_reactable
    }
  `,
}, graphql`
  query issueDetailViewRefetchQuery
  (
    $repoId: ID!,
    $issueishId: ID!,
    $timelineCount: Int!,
    $timelineCursor: String,
  ) {
    repository: node(id: $repoId) {
      ...issueDetailView_repository
    }

    issue: node(id: $issueishId) {
      ...issueDetailView_issue @arguments(
        timelineCount: $timelineCount,
        timelineCursor: $timelineCursor,
      )
    }
  }
`);
