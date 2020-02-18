import React, {Fragment} from 'react';
import {graphql, createFragmentContainer} from 'react-relay';
import PropTypes from 'prop-types';

import Octicon from '../../atom/octicon';
import Timeago from '../../views/timeago';

export class BareMergedEventView extends React.Component {
  static propTypes = {
    item: PropTypes.shape({
      actor: PropTypes.shape({
        avatarUrl: PropTypes.string.isRequired,
        login: PropTypes.string.isRequired,
      }),
      commit: PropTypes.shape({
        oid: PropTypes.string.isRequired,
      }),
      mergeRefName: PropTypes.string.isRequired,
      createdAt: PropTypes.string.isRequired,
    }).isRequired,
  }

  render() {
    const {actor, mergeRefName, createdAt} = this.props.item;
    return (
      <div className="merged-event">
        <Octicon className="pre-timeline-item-icon" icon="git-merge" />
        {actor && <img className="author-avatar" src={actor.avatarUrl} alt={actor.login} title={actor.login} />}
        <span className="merged-event-header">
          <span className="username">{actor ? actor.login : 'someone'}</span> merged{' '}
          {this.renderCommit()} into
          {' '}<span className="merge-ref">{mergeRefName}</span> on <Timeago time={createdAt} />
        </span>
      </div>
    );
  }

  renderCommit() {
    const {commit} = this.props.item;
    if (!commit) {
      return 'a commit';
    }

    return (
      <Fragment>
        commit <span className="sha">{commit.oid.slice(0, 8)}</span>
      </Fragment>
    );
  }
}

export default createFragmentContainer(BareMergedEventView, {
  item: graphql`
    fragment mergedEventView_item on MergedEvent {
      actor {
        avatarUrl login
      }
      commit { oid }
      mergeRefName
      createdAt
    }
  `,
});
