import React, {Fragment} from 'react';
import PropTypes from 'prop-types';

import {IssueishPropType} from '../prop-types';
import Accordion from './accordion';
import Timeago from './timeago';
import StatusDonutChart from './status-donut-chart';
import CheckSuitesAccumulator from '../containers/accumulators/check-suites-accumulator';
import QueryErrorTile from './query-error-tile';
import Octicon from '../atom/octicon';

export default class IssueishListView extends React.Component {
  static propTypes = {
    title: PropTypes.string.isRequired,
    isLoading: PropTypes.bool.isRequired,
    total: PropTypes.number.isRequired,
    issueishes: PropTypes.arrayOf(IssueishPropType).isRequired,

    repository: PropTypes.shape({
      defaultBranchRef: PropTypes.shape({
        prefix: PropTypes.string.isRequired,
        name: PropTypes.string.isRequired,
      }),
    }),

    needReviewsButton: PropTypes.bool,
    onIssueishClick: PropTypes.func.isRequired,
    onMoreClick: PropTypes.func,
    openReviews: PropTypes.func.isRequired,
    openOnGitHub: PropTypes.func.isRequired,
    showActionsMenu: PropTypes.func.isRequired,

    emptyComponent: PropTypes.func,
    error: PropTypes.object,
  }

  render() {
    return (
      <Accordion
        leftTitle={this.props.title}
        isLoading={this.props.isLoading}
        results={this.props.issueishes}
        total={this.props.total}
        loadingComponent={this.renderLoadingTile}
        emptyComponent={this.renderEmptyTile}
        moreComponent={this.renderMoreTile}
        reviewsButton={this.renderReviewsButton}
        onClickItem={this.props.onIssueishClick}>
        {this.renderIssueish}
      </Accordion>
    );
  }

  renderReviewsButton = () => {
    if (!this.props.needReviewsButton || this.props.issueishes.length < 1) {
      return null;
    }
    return (
      <button
        className="btn btn-primary btn-sm github-IssueishList-openReviewsButton"
        onClick={this.openReviews}>
        See reviews
      </button>
    );
  }

  openReviews = e => {
    e.stopPropagation();
    this.props.openReviews(this.props.issueishes[0]);
  }

  renderIssueish = issueish => {
    return (
      <CheckSuitesAccumulator commit={issueish.getLatestCommit()}>
        {({runsBySuite}) => {
          issueish.setCheckRuns(runsBySuite);

          return (
            <Fragment>
              <img
                className="github-IssueishList-item github-IssueishList-item--avatar"
                src={issueish.getAuthorAvatarURL(32)}
                title={issueish.getAuthorLogin()}
                alt={issueish.getAuthorLogin()}
              />
              <span className="github-IssueishList-item github-IssueishList-item--title">
                {issueish.getTitle()}
              </span>
              <span className="github-IssueishList-item github-IssueishList-item--number">
                #{issueish.getNumber()}
              </span>
              {this.renderStatusSummary(issueish.getStatusCounts())}
              <Timeago
                time={issueish.getCreatedAt()}
                displayStyle="short"
                className="github-IssueishList-item github-IssueishList-item--age"
              />
              <Octicon icon="ellipses"
                className="github-IssueishList-item github-IssueishList-item--menu"
                onClick={event => this.showActionsMenu(event, issueish)}
              />
            </Fragment>
          );
        }}
      </CheckSuitesAccumulator>
    );
  }

  showActionsMenu(event, issueish) {
    event.preventDefault();
    event.stopPropagation();

    this.props.showActionsMenu(issueish);
  }

  renderStatusSummary(statusCounts) {
    if (['success', 'failure', 'pending'].every(kind => statusCounts[kind] === 0)) {
      return <Octicon className="github-IssueishList-item github-IssueishList-item--status" icon="dash" />;
    }

    if (statusCounts.success > 0 && statusCounts.failure === 0 && statusCounts.pending === 0) {
      return <Octicon className="github-IssueishList-item github-IssueishList-item--status" icon="check" />;
    }

    if (statusCounts.success === 0 && statusCounts.failure > 0 && statusCounts.pending === 0) {
      return <Octicon className="github-IssueishList-item github-IssueishList-item--status" icon="x" />;
    }

    return <StatusDonutChart {...statusCounts} className="github-IssueishList-item github-IssueishList-item--status" />;
  }

  renderLoadingTile = () => {
    return (
      <div className="github-IssueishList-loading">
        Loading
      </div>
    );
  }

  renderEmptyTile = () => {
    if (this.props.error) {
      return <QueryErrorTile error={this.props.error} />;
    }

    if (this.props.emptyComponent) {
      const EmptyComponent = this.props.emptyComponent;
      return <EmptyComponent />;
    }

    return null;
  }

  renderMoreTile = () => {
    /* eslint-disable jsx-a11y/anchor-is-valid */
    if (this.props.onMoreClick) {
      return (
        <div className="github-IssueishList-more">
          <a onClick={this.props.onMoreClick}>
            More...
          </a>
        </div>
      );
    }

    return null;
  }
}
