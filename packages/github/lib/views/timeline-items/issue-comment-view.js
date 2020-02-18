import React from 'react';
import {graphql, createFragmentContainer} from 'react-relay';
import PropTypes from 'prop-types';

import Octicon from '../../atom/octicon';
import Timeago from '../timeago';
import GithubDotcomMarkdown from '../github-dotcom-markdown';
import {GHOST_USER} from '../../helpers';

export class BareIssueCommentView extends React.Component {
  static propTypes = {
    switchToIssueish: PropTypes.func.isRequired,
    item: PropTypes.shape({
      author: PropTypes.shape({
        avatarUrl: PropTypes.string.isRequired,
        login: PropTypes.string.isRequired,
      }),
      bodyHTML: PropTypes.string.isRequired,
      createdAt: PropTypes.string.isRequired,
      url: PropTypes.string.isRequired,
    }).isRequired,
  }

  render() {
    const comment = this.props.item;
    const author = comment.author || GHOST_USER;

    return (
      <div className="issue timeline-item">
        <div className="info-row">
          <Octicon className="pre-timeline-item-icon" icon="comment" />
          <img className="author-avatar" src={author.avatarUrl}
            alt={author.login} title={author.login}
          />
          <span className="comment-message-header">
            {author.login} commented
            {' '}<a href={comment.url}><Timeago time={comment.createdAt} /></a>
          </span>
        </div>
        <GithubDotcomMarkdown html={comment.bodyHTML} switchToIssueish={this.props.switchToIssueish} />
      </div>
    );
  }
}

export default createFragmentContainer(BareIssueCommentView, {
  item: graphql`
    fragment issueCommentView_item on IssueComment {
      author {
        avatarUrl login
      }
      bodyHTML createdAt url
    }
  `,
});
