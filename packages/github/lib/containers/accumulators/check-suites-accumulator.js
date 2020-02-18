import React from 'react';
import PropTypes from 'prop-types';
import {graphql, createPaginationContainer} from 'react-relay';
import {Disposable} from 'event-kit';

import {PAGE_SIZE, PAGINATION_WAIT_TIME_MS} from '../../helpers';
import {RelayConnectionPropType} from '../../prop-types';
import CheckRunsAccumulator from './check-runs-accumulator';
import Accumulator from './accumulator';

export class BareCheckSuitesAccumulator extends React.Component {
  static propTypes = {
    // Relay
    relay: PropTypes.shape({
      hasMore: PropTypes.func.isRequired,
      loadMore: PropTypes.func.isRequired,
      isLoading: PropTypes.func.isRequired,
    }).isRequired,
    commit: PropTypes.shape({
      checkSuites: RelayConnectionPropType(
        PropTypes.object,
      ),
    }).isRequired,

    // Render prop. Called with (array of errors, array of check suites, map of runs per suite, loading)
    children: PropTypes.func.isRequired,

    // Subscribe to an event that will fire just after a Relay refetch container completes a refetch.
    onDidRefetch: PropTypes.func,
  }

  static defaultProps = {
    onDidRefetch: /* istanbul ignore next */ () => new Disposable(),
  }

  render() {
    const resultBatch = this.props.commit.checkSuites.edges.map(edge => edge.node);

    return (
      <Accumulator
        relay={this.props.relay}
        resultBatch={resultBatch}
        onDidRefetch={this.props.onDidRefetch}
        pageSize={PAGE_SIZE}
        waitTimeMs={PAGINATION_WAIT_TIME_MS}>
        {this.renderCheckSuites}
      </Accumulator>
    );
  }

  renderCheckSuites = (err, suites, loading) => {
    if (err) {
      return this.props.children({
        errors: [err],
        suites,
        runsBySuite: new Map(),
        loading,
      });
    }

    return this.renderCheckSuite({errors: [], suites, runsBySuite: new Map(), loading}, suites);
  }

  renderCheckSuite(payload, suites) {
    if (suites.length === 0) {
      return this.props.children(payload);
    }

    const [suite] = suites;
    return (
      <CheckRunsAccumulator
        onDidRefetch={this.props.onDidRefetch}
        checkSuite={suite}>
        {({error, checkRuns, loading: runsLoading}) => {
          if (error) {
            payload.errors.push(error);
          }

          payload.runsBySuite.set(suite, checkRuns);
          payload.loading = payload.loading || runsLoading;
          return this.renderCheckSuite(payload, suites.slice(1));
        }}
      </CheckRunsAccumulator>
    );
  }
}

export default createPaginationContainer(BareCheckSuitesAccumulator, {
  commit: graphql`
    fragment checkSuitesAccumulator_commit on Commit
    @argumentDefinitions(
      checkSuiteCount: {type: "Int!"}
      checkSuiteCursor: {type: "String"}
      checkRunCount: {type: "Int!"}
      checkRunCursor: {type: "String"}
    ) {
      id
      checkSuites(
        first: $checkSuiteCount
        after: $checkSuiteCursor
      ) @connection(key: "CheckSuiteAccumulator_checkSuites") {
        pageInfo {
          hasNextPage
          endCursor
        }

        edges {
          cursor
          node {
            id
            status
            conclusion

            ...checkSuiteView_checkSuite
            ...checkRunsAccumulator_checkSuite @arguments(
              checkRunCount: $checkRunCount
              checkRunCursor: $checkRunCursor
            )
          }
        }
      }
    }
  `,
}, {
  direction: 'forward',
  /* istanbul ignore next */
  getConnectionFromProps(props) {
    return props.commit.checkSuites;
  },
  /* istanbul ignore next */
  getFragmentVariables(prevVars, totalCount) {
    return {...prevVars, totalCount};
  },
  /* istanbul ignore next */
  getVariables(props, {count, cursor}, fragmentVariables) {
    return {
      id: props.commit.id,
      checkSuiteCount: count,
      checkSuiteCursor: cursor,
      checkRunCount: fragmentVariables.checkRunCount,
    };
  },
  query: graphql`
    query checkSuitesAccumulatorQuery(
      $id: ID!
      $checkSuiteCount: Int!
      $checkSuiteCursor: String
      $checkRunCount: Int!
    ) {
      node(id: $id) {
        ... on Commit {
          ...checkSuitesAccumulator_commit @arguments(
            checkSuiteCount: $checkSuiteCount
            checkSuiteCursor: $checkSuiteCursor
            checkRunCount: $checkRunCount
          )
        }
      }
    }
  `,
});
