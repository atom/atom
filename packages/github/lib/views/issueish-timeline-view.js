import React from 'react';
import PropTypes from 'prop-types';

import {RelayConnectionPropType} from '../prop-types';
import {autobind} from '../helpers';
import Octicon from '../atom/octicon';
import CommitsView from './timeline-items/commits-view.js';
import IssueCommentView from './timeline-items/issue-comment-view.js';
import MergedEventView from './timeline-items/merged-event-view.js';
import HeadRefForcePushedEventView from './timeline-items/head-ref-force-pushed-event-view.js';
import CrossReferencedEventsView from './timeline-items/cross-referenced-events-view.js';
import CommitCommentThreadView from './timeline-items/commit-comment-thread-view';

export function collectionRenderer(Component, styleAsTimelineItem = true) {
  return class GroupedComponent extends React.Component {
    static displayName = `Grouped(${Component.render ? Component.render.displayName : Component.displayName})`

    static propTypes = {
      nodes: PropTypes.array.isRequired,
      issueish: PropTypes.object.isRequired,
      switchToIssueish: PropTypes.func.isRequired,
    }

    static getFragment(fragName, ...args) {
      const frag = fragName === 'nodes' ? 'item' : fragName;
      return Component.getFragment(frag, ...args);
    }

    constructor(props) {
      super(props);
      autobind(this, 'renderNode');
    }

    render() {
      return <div className={styleAsTimelineItem ? 'timeline-item' : ''}>{this.props.nodes.map(this.renderNode)}</div>;
    }

    renderNode(node, i) {
      return (
        <Component
          key={i}
          item={node}
          issueish={this.props.issueish}
          switchToIssueish={this.props.switchToIssueish}
        />
      );
    }
  };
}

const timelineItems = {
  PullRequestCommit: CommitsView,
  PullRequestCommitCommentThread: collectionRenderer(CommitCommentThreadView, false),
  IssueComment: collectionRenderer(IssueCommentView, false),
  MergedEvent: collectionRenderer(MergedEventView),
  HeadRefForcePushedEvent: collectionRenderer(HeadRefForcePushedEventView),
  CrossReferencedEvent: CrossReferencedEventsView,
};

const TimelineConnectionPropType = RelayConnectionPropType(
  PropTypes.shape({
    __typename: PropTypes.string.isRequired,
  }),
).isRequired;

export default class IssueishTimelineView extends React.Component {
  static propTypes = {
    switchToIssueish: PropTypes.func.isRequired,
    relay: PropTypes.shape({
      hasMore: PropTypes.func.isRequired,
      loadMore: PropTypes.func.isRequired,
      isLoading: PropTypes.func.isRequired,
    }).isRequired,
    issue: PropTypes.shape({
      timelineItems: TimelineConnectionPropType,
    }),
    pullRequest: PropTypes.shape({
      timelineItems: TimelineConnectionPropType,
    }),
    onBranch: PropTypes.bool,
    openCommit: PropTypes.func,
  }

  static defaultProps = {
    onBranch: false,
    openCommit: () => {},
  }

  constructor(props) {
    super(props);
    autobind(this, 'loadMore');
  }

  loadMore() {
    this.props.relay.loadMore(10, () => {
      this.forceUpdate();
    });
    this.forceUpdate();
  }

  render() {
    const issueish = this.props.issue || this.props.pullRequest;
    const groupedEdges = this.groupEdges(issueish.timelineItems.edges);
    return (
      <div className="github-PrTimeline">
        {groupedEdges.map(({type, edges}) => {
          const Component = timelineItems[type];
          const propsForCommits = {
            onBranch: this.props.onBranch,
            openCommit: this.props.openCommit,
          };
          if (Component) {
            return (
              <Component
                key={`${type}-${edges[0].cursor}`}
                nodes={edges.map(e => e.node)}
                issueish={issueish}
                switchToIssueish={this.props.switchToIssueish}
                {...(Component === CommitsView && propsForCommits)}
              />
            );
          } else {
            // eslint-disable-next-line no-console
            console.warn(`unrecognized timeline event type: ${type}`);
            return null;
          }
        })}
        {this.renderLoadMore()}
      </div>
    );
  }

  renderLoadMore() {
    if (!this.props.relay.hasMore()) {
      return null;
    }

    return (
      <div className="github-PrTimeline-loadMore">
        <button className="github-PrTimeline-loadMoreButton btn" onClick={this.loadMore}>
          {this.props.relay.isLoading() ? <Octicon icon="ellipsis" /> : 'Load More'}
        </button>
      </div>
    );
  }

  groupEdges(edges) {
    let currentGroup;
    const groupedEdges = [];
    let lastEdgeType;
    edges.forEach(({node, cursor}) => {
      const currentEdgeType = node.__typename;
      if (currentEdgeType === lastEdgeType) {
        currentGroup.edges.push({node, cursor});
      } else {
        currentGroup = {
          type: currentEdgeType,
          edges: [{node, cursor}],
        };
        groupedEdges.push(currentGroup);
      }
      lastEdgeType = currentEdgeType;
    });
    return groupedEdges;
  }
}
