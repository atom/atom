import React from 'react';
import PropTypes from 'prop-types';
import {graphql, createFragmentContainer} from 'react-relay';

import Octicon from '../atom/octicon';
import GithubDotcomMarkdown from './github-dotcom-markdown';
import {buildStatusFromCheckResult} from '../models/build-status';

export class BareCheckRunView extends React.Component {
  static propTypes = {
    // Relay
    checkRun: PropTypes.shape({
      name: PropTypes.string.isRequired,
      status: PropTypes.oneOf([
        'QUEUED', 'IN_PROGRESS', 'COMPLETED', 'REQUESTED',
      ]).isRequired,
      conclusion: PropTypes.oneOf([
        'ACTION_REQUIRED', 'TIMED_OUT', 'CANCELLED', 'FAILURE', 'SUCCESS', 'NEUTRAL',
      ]),
      title: PropTypes.string,
      detailsUrl: PropTypes.string,
    }).isRequired,

    // Actions
    switchToIssueish: PropTypes.func.isRequired,
  }

  render() {
    const {checkRun} = this.props;
    const {icon, classSuffix} = buildStatusFromCheckResult(checkRun);

    return (
      <li className="github-PrStatuses-list-item github-PrStatuses-list-item--checkRun">
        <span className="github-PrStatuses-list-item-icon">
          <Octicon icon={icon} className={`github-PrStatuses--${classSuffix}`} />
        </span>
        <a className="github-PrStatuses-list-item-name" href={checkRun.permalink}>{checkRun.name}</a>
        <div className="github-PrStatuses-list-item-context">
          {checkRun.title && <span className="github-PrStatuses-list-item-title">{checkRun.title}</span>}
          {checkRun.summary && (
            <GithubDotcomMarkdown
              className="github-PrStatuses-list-item-summary"
              switchToIssueish={this.props.switchToIssueish}
              markdown={checkRun.summary}
            />
          )}
        </div>
        {checkRun.detailsUrl && (
          <a className="github-PrStatuses-list-item-details-link" href={checkRun.detailsUrl}>
            Details
          </a>
        )}
      </li>
    );
  }
}

export default createFragmentContainer(BareCheckRunView, {
  checkRun: graphql`
    fragment checkRunView_checkRun on CheckRun {
      name
      status
      conclusion
      title
      summary
      permalink
      detailsUrl
    }
  `,
});
