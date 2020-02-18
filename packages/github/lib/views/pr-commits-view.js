import React, {Fragment} from 'react';
import PropTypes from 'prop-types';
import {graphql, createPaginationContainer} from 'react-relay';
import {RelayConnectionPropType} from '../prop-types';
import PrCommitView from './pr-commit-view';

import {autobind, PAGE_SIZE} from '../helpers';

export class PrCommitsView extends React.Component {
  static propTypes = {
    relay: PropTypes.shape({
      hasMore: PropTypes.func.isRequired,
      loadMore: PropTypes.func.isRequired,
      isLoading: PropTypes.func.isRequired,
    }).isRequired,
    pullRequest: PropTypes.shape({
      commits: RelayConnectionPropType(
        PropTypes.shape({
          commit: PropTypes.shape({
            id: PropTypes.string.isRequired,
          }),
        }),
      ),
    }),
    onBranch: PropTypes.bool.isRequired,
    openCommit: PropTypes.func.isRequired,
  }

  constructor(props) {
    super(props);
    autobind(this, 'loadMore');
  }

  loadMore() {
    this.props.relay.loadMore(PAGE_SIZE, () => {
      this.forceUpdate();
    });
    this.forceUpdate();
  }

  render() {
    return (
      <Fragment>
        <div className="github-PrCommitsView-commitWrapper">
          {this.renderCommits()}
        </div>
        {this.renderLoadMore()}
      </Fragment>
    );
  }

  renderLoadMore() {
    if (!this.props.relay.hasMore()) {
      return null;
    }
    return <button className="github-PrCommitsView-load-more-button btn" onClick={this.loadMore}>Load more</button>;
  }

  renderCommits() {
    return this.props.pullRequest.commits.edges.map(edge => {
      const commit = edge.node.commit;
      return (
        <PrCommitView
          key={commit.id}
          item={commit}
          onBranch={this.props.onBranch}
          openCommit={this.props.openCommit}
        />);
    });
  }
}

export default createPaginationContainer(PrCommitsView, {
  pullRequest: graphql`
    fragment prCommitsView_pullRequest on PullRequest
    @argumentDefinitions(
      commitCount: {type: "Int!", defaultValue: 100},
      commitCursor: {type: "String"}
    ) {
      url
      commits(
        first: $commitCount, after: $commitCursor
      ) @connection(key: "prCommitsView_commits") {
        pageInfo { endCursor hasNextPage }
        edges {
          cursor
          node {
            commit {
              id
              ...prCommitView_item
            }
          }
        }
      }
    }
  `,
}, {
  direction: 'forward',
  getConnectionFromProps(props) {
    return props.pullRequest.commits;
  },
  getFragmentVariables(prevVars, totalCount) {
    return {
      ...prevVars,
      commitCount: totalCount,
    };
  },
  getVariables(props, {count, cursor}, fragmentVariables) {
    return {
      commitCount: count,
      commitCursor: cursor,
      url: props.pullRequest.url,
    };
  },
  query: graphql`
    query prCommitsViewQuery($commitCount: Int!, $commitCursor: String, $url: URI!) {
        resource(url: $url) {
          ... on PullRequest {
            ...prCommitsView_pullRequest @arguments(commitCount: $commitCount, commitCursor: $commitCursor)
          }
      }
    }
  `,
});
