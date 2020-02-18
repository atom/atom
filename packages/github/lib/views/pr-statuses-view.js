import React from 'react';
import {createRefetchContainer, graphql} from 'react-relay';
import PropTypes from 'prop-types';
import {Emitter} from 'event-kit';

import {toSentence} from '../helpers';
import PullRequestStatusContextView from './pr-status-context-view';
import CheckSuiteView from './check-suite-view';
import CheckSuitesAccumulator from '../containers/accumulators/check-suites-accumulator';
import {
  buildStatusFromStatusContext,
  buildStatusFromCheckResult,
  combineBuildStatuses,
} from '../models/build-status';
import Octicon from '../atom/octicon';
import StatusDonutChart from './status-donut-chart';
import PeriodicRefresher from '../periodic-refresher';
import {RelayConnectionPropType} from '../prop-types';

export class BarePrStatusesView extends React.Component {
  static propTypes = {
    // Relay
    relay: PropTypes.shape({
      refetch: PropTypes.func.isRequired,
    }).isRequired,
    pullRequest: PropTypes.shape({
      id: PropTypes.string.isRequired,
      recentCommits: RelayConnectionPropType(
        PropTypes.shape({
          commit: PropTypes.shape({
            status: PropTypes.shape({
              state: PropTypes.string.isRequired,
              contexts: PropTypes.arrayOf(
                PropTypes.shape({
                  id: PropTypes.string.isRequired,
                }).isRequired,
              ).isRequired,
            }),
          }).isRequired,
        }).isRequired,
      ).isRequired,
    }).isRequired,

    // Control
    displayType: PropTypes.oneOf([
      'check', 'full',
    ]),

    // Action
    switchToIssueish: PropTypes.func.isRequired,
  }

  static defaultProps = {
    displayType: 'full',
  }

  static lastRefreshPerPr = new Map()

  static COMPLETED_REFRESH_TIMEOUT = 3 * 60 * 1000
  static PENDING_REFRESH_TIMEOUT = 30 * 1000
  static MINIMUM_REFRESH_INTERVAL = 15 * 1000

  constructor(props) {
    super(props);

    this.emitter = new Emitter();

    this.refresherOpts = {
      interval: this.createIntervalCallback([]),
      getCurrentId: () => this.props.pullRequest.id,
      refresh: this.refresh,
      minimumIntervalPerId: this.constructor.MINIMUM_REFRESH_INTERVAL,
    };
  }

  componentDidMount() {
    this.refresher = new PeriodicRefresher(this.constructor, this.refresherOpts);
    this.refresher.start();
  }

  componentWillUnmount() {
    this.refresher.destroy();
  }

  refresh = () => {
    this.props.relay.refetch({
      id: this.props.pullRequest.id,
    }, null, () => this.emitter.emit('did-refetch'), {force: true});
  }

  render() {
    const headCommit = this.getHeadCommit();
    return (
      <CheckSuitesAccumulator onDidRefetch={this.onDidRefetch} commit={headCommit}>
        {this.renderWithChecks}
      </CheckSuitesAccumulator>
    );
  }

  renderWithChecks = result => {
    for (const err of result.errors) {
      // eslint-disable-next-line no-console
      console.error(err);
    }

    if (!this.getHeadCommit().status && result.suites.length === 0) {
      return null;
    }

    this.refresherOpts.interval = this.createIntervalCallback(result.suites);

    if (this.props.displayType === 'full') {
      return this.renderAsFull(result);
    } else {
      return this.renderAsCheck(result);
    }
  }

  renderAsCheck({runsBySuite}) {
    const summaryStatus = this.getSummaryBuildStatus(runsBySuite);
    return <Octicon icon={summaryStatus.icon} className={`github-PrStatuses--${summaryStatus.classSuffix}`} />;
  }

  renderAsFull({suites, runsBySuite}) {
    const status = this.getHeadCommit().status;
    const contexts = status ? status.contexts : [];

    const summaryStatus = this.getSummaryBuildStatus(runsBySuite);
    const detailStatuses = this.getDetailBuildStatuses(runsBySuite);

    return (
      <div className="github-PrStatuses">
        <div className="github-PrStatuses-header">
          <div className="github-PrStatuses-donut-chart">
            {this.renderDonutChart(detailStatuses)}
          </div>
          <div className="github-PrStatuses-summary">
            {this.summarySentence(summaryStatus, detailStatuses)}
          </div>
        </div>
        <ul className="github-PrStatuses-list">
          {contexts.map(context => <PullRequestStatusContextView key={context.id} context={context} />)}
          {suites.map(suite => (
            <CheckSuiteView
              key={suite.id}
              checkSuite={suite}
              checkRuns={runsBySuite.get(suite)}
              switchToIssueish={this.props.switchToIssueish}
            />
          ))}
        </ul>
      </div>
    );
  }

  renderDonutChart(detailStatuses) {
    const counts = this.countsFromStatuses(detailStatuses);
    return <StatusDonutChart {...counts} />;
  }

  summarySentence(summaryStatus, detailStatuses) {
    if (this.isAllSucceeded(summaryStatus)) {
      return 'All checks succeeded';
    } else if (this.isAllFailed(detailStatuses)) {
      return 'All checks failed';
    } else {
      const noun = detailStatuses.length === 1 ? 'check' : 'checks';
      const parts = [];
      const {pending, failure, success} = this.countsFromStatuses(detailStatuses);

      if (pending > 0) {
        parts.push(`${pending} pending`);
      }
      if (failure > 0) {
        parts.push(`${failure} failing`);
      }
      if (success > 0) {
        parts.push(`${success} successful`);
      }
      return toSentence(parts) + ` ${noun}`;
    }
  }

  countsFromStatuses(statuses) {
    const counts = {
      pending: 0,
      failure: 0,
      success: 0,
      neutral: 0,
    };

    for (const buildStatus of statuses) {
      const count = counts[buildStatus.classSuffix];
      /* istanbul ignore else */
      if (count !== undefined) {
        counts[buildStatus.classSuffix] = count + 1;
      }
    }
    return counts;
  }

  getHeadCommit() {
    return this.props.pullRequest.recentCommits.edges[0].node.commit;
  }

  getSummaryBuildStatus(runsBySuite) {
    const contextStatus = buildStatusFromStatusContext(this.getHeadCommit().status || {});
    const checkRunStatuses = [];
    for (const [, runs] of runsBySuite) {
      for (const checkRun of runs) {
        checkRunStatuses.push(buildStatusFromCheckResult(checkRun));
      }
    }

    return combineBuildStatuses(contextStatus, ...checkRunStatuses);
  }

  getDetailBuildStatuses(runsBySuite) {
    const headCommit = this.getHeadCommit();

    const statuses = [];

    if (headCommit.status) {
      for (const context of headCommit.status.contexts) {
        statuses.push(buildStatusFromStatusContext(context));
      }
    }

    for (const [, checkRuns] of runsBySuite) {
      for (const checkRun of checkRuns) {
        statuses.push(buildStatusFromCheckResult(checkRun));
      }
    }

    return statuses;
  }

  createIntervalCallback(suites) {
    return () => {
      const statuses = [
        buildStatusFromStatusContext(this.getHeadCommit().status || {}),
        ...suites.map(buildStatusFromCheckResult),
      ];

      if (statuses.some(status => status.classSuffix === 'pending')) {
        return this.constructor.PENDING_REFRESH_TIMEOUT;
      } else {
        return this.constructor.COMPLETED_REFRESH_TIMEOUT;
      }
    };
  }

  isAllSucceeded(buildStatuses) {
    return buildStatuses.classSuffix === 'success';
  }

  isAllFailed(detailStatuses) {
    return detailStatuses.every(s => s.classSuffix === 'failure');
  }

  onDidRefetch = cb => this.emitter.on('did-refetch', cb)
}

export default createRefetchContainer(BarePrStatusesView, {
  pullRequest: graphql`
    fragment prStatusesView_pullRequest on PullRequest
    @argumentDefinitions(
      checkSuiteCount: {type: "Int!"}
      checkSuiteCursor: {type: "String"}
      checkRunCount: {type: "Int!"}
      checkRunCursor: {type: "String"}
    ) {
      id
      recentCommits: commits(last:1) {
        edges {
          node {
            commit {
              status {
                state
                contexts {
                  id
                  state
                  ...prStatusContextView_context
                }
              }

              ...checkSuitesAccumulator_commit @arguments(
                checkSuiteCount: $checkSuiteCount
                checkSuiteCursor: $checkSuiteCursor
                checkRunCount: $checkRunCount
                checkRunCursor: $checkRunCursor
              )
            }
          }
        }
      }
    }
  `,
}, graphql`
  query prStatusesViewRefetchQuery(
    $id: ID!
    $checkSuiteCount: Int!
    $checkSuiteCursor: String
    $checkRunCount: Int!
    $checkRunCursor: String
  ) {
    node(id: $id) {
      ... on PullRequest {
        ...prStatusesView_pullRequest @arguments(
          checkSuiteCount: $checkSuiteCount
          checkSuiteCursor: $checkSuiteCursor
          checkRunCount: $checkRunCount
          checkRunCursor: $checkRunCursor
        )
      }
    }
  }
`);
