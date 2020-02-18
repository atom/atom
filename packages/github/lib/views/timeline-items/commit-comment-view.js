import React from 'react';
import {graphql, createFragmentContainer} from 'react-relay';
import PropTypes from 'prop-types';

import Octicon from '../../atom/octicon';
import Timeago from '../timeago';
import GithubDotcomMarkdown from '../github-dotcom-markdown';
import {GHOST_USER} from '../../helpers';

export class BareCommitCommentView extends React.Component {
  static propTypes = {
    item: PropTypes.object.isRequired,
    isReply: PropTypes.bool.isRequired,
    switchToIssueish: PropTypes.func.isRequired,
  }

  render() {
    const comment = this.props.item;
    const author = comment.author || GHOST_USER;

    return (
      <div className="issue">
        <div className="info-row">
          {this.props.isReply ? null : <Octicon className="pre-timeline-item-icon" icon="comment" />}
          <img className="author-avatar"
            src={author.avatarUrl} alt={author.login} title={author.login}
          />
          {this.renderHeader(comment, author)}
        </div>
        <GithubDotcomMarkdown html={comment.bodyHTML} switchToIssueish={this.props.switchToIssueish} />
      </div>
    );
  }

  renderHeader(comment, author) {
    if (this.props.isReply) {
      return (
        <span className="comment-message-header">
          {author.login} replied <Timeago time={comment.createdAt} />
        </span>
      );
    } else {
      return (
        <span className="comment-message-header">
          {author.login} commented {this.renderPath()} in
          {' '}{comment.commit.oid.substr(0, 7)} <Timeago time={comment.createdAt} />
        </span>
      );
    }
  }

  renderPath() {
    if (this.props.item.path) {
      return <span>on <code>{this.props.item.path}</code></span>;
    } else {
      return null;
    }
  }
}

export default createFragmentContainer(BareCommitCommentView, {
  item: graphql`
    fragment commitCommentView_item on CommitComment {
      author {
        login avatarUrl
      }
      commit { oid }
      bodyHTML createdAt path position
    }
  `,
});
