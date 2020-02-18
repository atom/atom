import React, {Fragment} from 'react';
import PropTypes from 'prop-types';
import {graphql, createFragmentContainer} from 'react-relay';

import Octicon from '../atom/octicon';
import CheckRunView from './check-run-view';
import {buildStatusFromCheckResult} from '../models/build-status';

export class BareCheckSuiteView extends React.Component {
  static propTypes = {
    // Relay
    checkSuite: PropTypes.shape({
      app: PropTypes.shape({
        name: PropTypes.string.isRequired,
      }),
      status: PropTypes.oneOf([
        'QUEUED', 'IN_PROGRESS', 'COMPLETED', 'REQUESTED',
      ]).isRequired,
      conclusion: PropTypes.oneOf([
        'ACTION_REQUIRED', 'TIMED_OUT', 'CANCELLED', 'FAILURE', 'SUCCESS', 'NEUTRAL',
      ]),
    }).isRequired,
    checkRuns: PropTypes.arrayOf(
      PropTypes.shape({id: PropTypes.string.isRequired}),
    ).isRequired,

    // Actions
    switchToIssueish: PropTypes.func.isRequired,
  };

  render() {
    const {icon, classSuffix} = buildStatusFromCheckResult(this.props.checkSuite);

    return (
      <Fragment>
        <li className="github-PrStatuses-list-item">
          <span className="github-PrStatuses-list-item-icon">
            <Octicon icon={icon} className={`github-PrStatuses--${classSuffix}`} />
          </span>
          {this.props.checkSuite.app && (
            <span className="github-PrStatuses-list-item-context">
              <strong>{this.props.checkSuite.app.name}</strong>
            </span>
          )}
        </li>
        {this.props.checkRuns.map(run => (
          <CheckRunView key={run.id} checkRun={run} switchToIssueish={this.props.switchToIssueish} />
        ))}
      </Fragment>
    );
  }
}

export default createFragmentContainer(BareCheckSuiteView, {
  checkSuite: graphql`
    fragment checkSuiteView_checkSuite on CheckSuite {
      app {
        name
      }
      status
      conclusion
    }
  `,
});
