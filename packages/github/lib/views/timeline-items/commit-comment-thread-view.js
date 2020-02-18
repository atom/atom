import React from 'react';
import {graphql, createFragmentContainer} from 'react-relay';
import PropTypes from 'prop-types';

import CommitCommentView from './commit-comment-view';

export class BareCommitCommentThreadView extends React.Component {
  static propTypes = {
    item: PropTypes.shape({
      commit: PropTypes.shape({
        oid: PropTypes.string.isRequired,
      }).isRequired,
      comments: PropTypes.shape({
        edges: PropTypes.arrayOf(
          PropTypes.shape({
            node: PropTypes.object.isRequired,
          }).isRequired,
        ).isRequired,
      }).isRequired,
    }).isRequired,
    switchToIssueish: PropTypes.func.isRequired,
  }

  render() {
    const {item} = this.props;
    return (
      <div className="commit-comment-thread timeline-item">
        {item.comments.edges.map((edge, i) => (
          <CommitCommentView
            isReply={i !== 0}
            key={edge.node.id}
            item={edge.node}
            switchToIssueish={this.props.switchToIssueish}
          />
        ))}
      </div>
    );
  }
}


export default createFragmentContainer(BareCommitCommentThreadView, {
  item: graphql`
    fragment commitCommentThreadView_item on PullRequestCommitCommentThread {
      commit { oid }
      comments(first: 100) {
        edges {
          node {
            id
            ...commitCommentView_item
          }
        }
      }
    }
  `,
});
