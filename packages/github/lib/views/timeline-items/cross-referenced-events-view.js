import React from 'react';
import {graphql, createFragmentContainer} from 'react-relay';
import PropTypes from 'prop-types';

import Octicon from '../../atom/octicon';
import Timeago from '../../views/timeago';
import CrossReferencedEventView from './cross-referenced-event-view';

export class BareCrossReferencedEventsView extends React.Component {
  static propTypes = {
    nodes: PropTypes.arrayOf(
      PropTypes.shape({
        id: PropTypes.string.isRequired,
        referencedAt: PropTypes.string.isRequired,
        isCrossRepository: PropTypes.bool.isRequired,
        actor: PropTypes.shape({
          avatarUrl: PropTypes.string.isRequired,
          login: PropTypes.string.isRequired,
        }),
        source: PropTypes.shape({
          __typename: PropTypes.oneOf(['Issue', 'PullRequest']).isRequired,
          repository: PropTypes.shape({
            name: PropTypes.string.isRequired,
            owner: PropTypes.shape({
              login: PropTypes.string.isRequired,
            }).isRequired,
          }).isRequired,
        }).isRequired,
      }).isRequired,
    ).isRequired,
  }

  render() {
    return (
      <div className="timeline-item cross-referenced-events">
        <div className="info-row">
          <Octicon className="pre-timeline-item-icon" icon="bookmark" />
          <span className="cross-referenced-event-header">
            {this.renderSummary()}
          </span>
        </div>
        {this.renderEvents()}
      </div>
    );
  }

  renderSummary() {
    const first = this.props.nodes[0];
    if (this.props.nodes.length > 1) {
      return <span>This was referenced <Timeago time={first.referencedAt} /></span>;
    } else {
      const type = {
        PullRequest: 'a pull request',
        Issue: 'an issue',
      }[first.source.__typename];
      let xrefClause = '';
      if (first.isCrossRepository) {
        const repo = first.source.repository;
        xrefClause = (
          <span>in <strong>{repo.owner.login}/{repo.name}</strong></span>
        );
      }
      return (
        <span>
          <img className="author-avatar" src={first.actor.avatarUrl}
            alt={first.actor.login} title={first.actor.login}
          />
          <strong>{first.actor.login}</strong> referenced this from {type} {xrefClause}
          <Timeago time={first.referencedAt} />
        </span>
      );
    }
  }

  renderEvents() {
    return this.props.nodes.map(node => {
      return <CrossReferencedEventView key={node.id} item={node} />;
    });
  }
}


export default createFragmentContainer(BareCrossReferencedEventsView, {
  nodes: graphql`
    fragment crossReferencedEventsView_nodes on CrossReferencedEvent @relay(plural: true) {
      id referencedAt isCrossRepository
      actor { login avatarUrl }
      source {
        __typename
        ... on RepositoryNode {
          repository {
            name owner { login }
          }
        }
      }
      ...crossReferencedEventView_item
    }
  `,
});
