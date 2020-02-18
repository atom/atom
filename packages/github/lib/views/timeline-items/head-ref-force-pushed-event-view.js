import React from 'react';
import {graphql, createFragmentContainer} from 'react-relay';
import PropTypes from 'prop-types';

import Octicon from '../../atom/octicon';
import Timeago from '../timeago';

export class BareHeadRefForcePushedEventView extends React.Component {
  static propTypes = {
    item: PropTypes.shape({
      actor: PropTypes.shape({
        avatarUrl: PropTypes.string.isRequired,
        login: PropTypes.string.isRequired,
      }),
      beforeCommit: PropTypes.shape({
        oid: PropTypes.string.isRequired,
      }),
      afterCommit: PropTypes.shape({
        oid: PropTypes.string.isRequired,
      }),
      createdAt: PropTypes.string.isRequired,
    }).isRequired,
    issueish: PropTypes.shape({
      headRefName: PropTypes.string.isRequired,
      headRepositoryOwner: PropTypes.shape({
        login: PropTypes.string.isRequired,
      }),
      repository: PropTypes.shape({
        owner: PropTypes.shape({
          login: PropTypes.string.isRequired,
        }).isRequired,
      }).isRequired,
    }).isRequired,
  }

  render() {
    const {actor, beforeCommit, afterCommit, createdAt} = this.props.item;
    const {headRefName, headRepositoryOwner, repository} = this.props.issueish;
    const branchPrefix = headRepositoryOwner.login !== repository.owner.login ? `${headRepositoryOwner.login}:` : '';
    return (
      <div className="head-ref-force-pushed-event">
        <Octicon className="pre-timeline-item-icon" icon="repo-force-push" />
        {actor && <img className="author-avatar" src={actor.avatarUrl} alt={actor.login} title={actor.login} />}
        <span className="head-ref-force-pushed-event-header">
          <span className="username">{actor ? actor.login : 'someone'}</span> force-pushed
          the {branchPrefix + headRefName} branch
          from {this.renderCommit(beforeCommit, 'an old commit')} to
          {' '}{this.renderCommit(afterCommit, 'a new commit')} at <Timeago time={createdAt} />
        </span>
      </div>
    );
  }

  renderCommit(commit, description) {
    if (!commit) {
      return description;
    }

    return <span className="sha">{commit.oid.slice(0, 8)}</span>;
  }
}

export default createFragmentContainer(BareHeadRefForcePushedEventView, {
  issueish: graphql`
    fragment headRefForcePushedEventView_issueish on PullRequest {
      headRefName
      headRepositoryOwner { login }
      repository { owner { login } }
    }
  `,

  item: graphql`
    fragment headRefForcePushedEventView_item on HeadRefForcePushedEvent {
      actor { avatarUrl login }
      beforeCommit { oid }
      afterCommit { oid }
      createdAt
    }
  `,
});
