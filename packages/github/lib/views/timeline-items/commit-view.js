import React from 'react';
import {graphql, createFragmentContainer} from 'react-relay';
import PropTypes from 'prop-types';

import Octicon from '../../atom/octicon';

export class BareCommitView extends React.Component {
  static propTypes = {
    commit: PropTypes.object.isRequired,
    onBranch: PropTypes.bool.isRequired,
    openCommit: PropTypes.func.isRequired,
  }

  authoredByCommitter(commit) {
    if (commit.authoredByCommitter) {
      return true;
    }
    // If you commit on GitHub online the committer details would be:
    //
    //    name: "GitHub"
    //    email: "noreply@github.com"
    //    user: null
    //
    if (commit.committer.email === 'noreply@github.com') {
      return true;
    }
    if (commit.committer.name === 'GitHub' && commit.committer.user === null) {
      return true;
    }

    return false;
  }

  openCommitDetailItem = () => this.props.openCommit({sha: this.props.commit.sha})

  renderCommitter(commit) {
    if (!this.authoredByCommitter(commit)) {
      return (
        <img
          className="author-avatar" alt="author's avatar" src={commit.committer.avatarUrl}
          title={commit.committer.user ? commit.committer.user.login : commit.committer.name}
        />
      );
    } else {
      return null;
    }
  }

  render() {
    const commit = this.props.commit;
    return (
      <div className="commit">
        <Octicon className="pre-timeline-item-icon" icon="git-commit" />
        <span className="commit-author">
          <img
            className="author-avatar" alt="author's avatar" src={commit.author.avatarUrl}
            title={commit.author.user ? commit.author.user.login : commit.author.name}
          />
          {this.renderCommitter(commit)}
        </span>
        <p className="commit-message-headline">
          {this.props.onBranch
            ? (
              <button
                className="open-commit-detail-button"
                title={commit.message}
                dangerouslySetInnerHTML={{__html: commit.messageHeadlineHTML}}
                onClick={this.openCommitDetailItem}
              />
            )
            : (
              <span
                title={commit.message}
                dangerouslySetInnerHTML={{__html: commit.messageHeadlineHTML}}
              />
            )
          }
        </p>
        <a className="commit-sha" href={commit.commitUrl}>{commit.sha.slice(0, 8)}</a>
      </div>
    );
  }
}

export default createFragmentContainer(BareCommitView, {
  commit: graphql`
    fragment commitView_commit on Commit {
      author {
        name avatarUrl
        user {
          login
        }
      }
      committer {
        name avatarUrl
        user {
          login
        }
      }
      authoredByCommitter
      sha:oid message messageHeadlineHTML commitUrl
    }
  `,
});
