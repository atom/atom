import React from 'react';
import {createFragmentContainer, graphql} from 'react-relay';
import PropTypes from 'prop-types';
import cx from 'classnames';

import Octicon from '../atom/octicon';
import {GHOST_USER} from '../helpers';

const typeAndStateToIcon = {
  Issue: {
    OPEN: 'issue-opened',
    CLOSED: 'issue-closed',
  },
  PullRequest: {
    OPEN: 'git-pull-request',
    CLOSED: 'git-pull-request',
    MERGED: 'git-merge',
  },
};

export class BareIssueishTooltipContainer extends React.Component {
  static propTypes = {
    resource: PropTypes.shape({
      issue: PropTypes.shape({}),
      pullRequest: PropTypes.shape({}),
    }).isRequired,
  }

  render() {
    const resource = this.props.resource;
    const author = resource.author || GHOST_USER;

    const {repository, state, number, title, __typename} = resource;
    const icons = typeAndStateToIcon[__typename] || {};
    const icon = icons[state] || '';
    return (
      <div className="github-IssueishTooltip">
        <div className="issueish-avatar-and-title">
          <img className="author-avatar" src={author.avatarUrl} title={author.login}
            alt={author.login}
          />
          <h3 className="issueish-title">{title}</h3>
        </div>
        <div className="issueish-badge-and-link">
          <span className={cx('issueish-badge', 'badge', state.toLowerCase())}>
            <Octicon icon={icon} />
            {state.toLowerCase()}
          </span>
          <span className="issueish-link">
            {repository.owner.login}/{repository.name}#{number}
          </span>
        </div>
      </div>
    );
  }
}

export default createFragmentContainer(BareIssueishTooltipContainer, {
  resource: graphql`
    fragment issueishTooltipContainer_resource on UniformResourceLocatable {
      __typename

      ... on Issue {
        state number title
        repository { name owner { login } }
        author { login avatarUrl }
      }
      ... on PullRequest {
        state number title
        repository { name owner { login } }
        author { login avatarUrl }
      }
    }
  `,
});
