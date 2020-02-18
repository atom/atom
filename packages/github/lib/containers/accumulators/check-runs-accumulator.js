import React from 'react';
import PropTypes from 'prop-types';
import {graphql, createPaginationContainer} from 'react-relay';

import {RelayConnectionPropType} from '../../prop-types';
import {PAGE_SIZE, PAGINATION_WAIT_TIME_MS} from '../../helpers';
import Accumulator from './accumulator';

export class BareCheckRunsAccumulator extends React.Component {
  static propTypes = {
    // Relay props
    relay: PropTypes.shape({
      hasMore: PropTypes.func.isRequired,
      loadMore: PropTypes.func.isRequired,
      isLoading: PropTypes.func.isRequired,
    }),
    checkSuite: PropTypes.shape({
      checkRuns: RelayConnectionPropType(
        PropTypes.object,
      ),
    }),

    // Render prop.
    children: PropTypes.func.isRequired,

    // Called when a refetch is triggered.
    onDidRefetch: PropTypes.func.isRequired,
  }

  render() {
    const resultBatch = this.props.checkSuite.checkRuns.edges.map(edge => edge.node);

    return (
      <Accumulator
        relay={this.props.relay}
        resultBatch={resultBatch}
        onDidRefetch={this.props.onDidRefetch}
        pageSize={PAGE_SIZE}
        waitTimeMs={PAGINATION_WAIT_TIME_MS}>
        {(error, checkRuns, loading) => this.props.children({error, checkRuns, loading})}
      </Accumulator>
    );
  }
}

export default createPaginationContainer(BareCheckRunsAccumulator, {
  checkSuite: graphql`
    fragment checkRunsAccumulator_checkSuite on CheckSuite
    @argumentDefinitions(
      checkRunCount: {type: "Int!"}
      checkRunCursor: {type: "String"}
    ) {
      id
      checkRuns(
        first: $checkRunCount
        after: $checkRunCursor
      ) @connection(key: "CheckRunsAccumulator_checkRuns") {
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

            ...checkRunView_checkRun
          }
        }
      }
    }
  `,
}, {
  direction: 'forward',
  /* istanbul ignore next */
  getConnectionFromProps(props) {
    return props.checkSuite.checkRuns;
  },
  /* istanbul ignore next */
  getFragmentVariables(prevVars, totalCount) {
    return {...prevVars, totalCount};
  },
  /* istanbul ignore next */
  getVariables(props, {count, cursor}) {
    return {
      id: props.checkSuite.id,
      checkRunCount: count,
      checkRunCursor: cursor,
    };
  },
  query: graphql`
    query checkRunsAccumulatorQuery(
      $id: ID!
      $checkRunCount: Int!
      $checkRunCursor: String
    ) {
      node(id: $id) {
        ... on CheckSuite {
          ...checkRunsAccumulator_checkSuite @arguments(
            checkRunCount: $checkRunCount
            checkRunCursor: $checkRunCursor
          )
        }
      }
    }
  `,
});
