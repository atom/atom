import React from 'react';
import PropTypes from 'prop-types';
import {shell} from 'electron';

import {RemotePropType, RemoteSetPropType, BranchSetPropType, EndpointPropType} from '../prop-types';
import Search from '../models/search';
import IssueishSearchContainer from '../containers/issueish-search-container';
import CurrentPullRequestContainer from '../containers/current-pull-request-container';
import IssueishDetailItem from '../items/issueish-detail-item';
import ReviewsItem from '../items/reviews-item';
import {addEvent} from '../reporter-proxy';

export default class IssueishSearchesController extends React.Component {
  static propTypes = {
    // Relay payload
    repository: PropTypes.shape({
      id: PropTypes.string.isRequired,
      defaultBranchRef: PropTypes.shape({
        prefix: PropTypes.string.isRequired,
        name: PropTypes.string.isRequired,
      }),
    }),

    // Connection
    endpoint: EndpointPropType.isRequired,
    token: PropTypes.string.isRequired,

    // Atom environment
    workspace: PropTypes.object.isRequired,

    // Repository model attributes
    workingDirectory: PropTypes.string,
    remote: RemotePropType.isRequired,
    remotes: RemoteSetPropType.isRequired,
    branches: BranchSetPropType.isRequired,
    aheadCount: PropTypes.number,
    pushInProgress: PropTypes.bool.isRequired,

    // Actions
    onCreatePr: PropTypes.func.isRequired,
  }

  state = {};

  static getDerivedStateFromProps(props) {
    return {
      searches: [
        Search.inRemote(props.remote, 'Open pull requests', 'type:pr state:open'),
      ],
    };
  }

  render() {
    return (
      <div className="github-IssueishSearch">
        <CurrentPullRequestContainer
          repository={this.props.repository}
          token={this.props.token}
          endpoint={this.props.endpoint}
          remote={this.props.remote}
          remotes={this.props.remotes}
          branches={this.props.branches}
          aheadCount={this.props.aheadCount}
          pushInProgress={this.props.pushInProgress}
          workspace={this.props.workspace}
          workingDirectory={this.props.workingDirectory}
          onOpenIssueish={this.onOpenIssueish}
          onOpenReviews={this.onOpenReviews}
          onCreatePr={this.props.onCreatePr}
        />
        {this.state.searches.map(search => (
          <IssueishSearchContainer
            key={search.getName()}

            token={this.props.token}
            endpoint={this.props.endpoint}
            search={search}

            onOpenIssueish={this.onOpenIssueish}
            onOpenSearch={this.onOpenSearch}
            onOpenReviews={this.onOpenReviews}
          />
        ))}
      </div>
    );
  }

  onOpenReviews = issueish => {
    const uri = ReviewsItem.buildURI({
      host: this.props.endpoint.getHost(),
      owner: this.props.remote.getOwner(),
      repo: this.props.remote.getRepo(),
      number: issueish.getNumber(),
      workdir: this.props.workingDirectory,
    });
    return this.props.workspace.open(uri).then(() => {
      addEvent('open-reviews-tab', {package: 'github', from: this.constructor.name});
    });
  }

  onOpenIssueish = issueish => {
    return this.props.workspace.open(
      IssueishDetailItem.buildURI({
        host: this.props.endpoint.getHost(),
        owner: this.props.remote.getOwner(),
        repo: this.props.remote.getRepo(),
        number: issueish.getNumber(),
        workdir: this.props.workingDirectory,
      }),
      {pending: true, searchAllPanes: true},
    ).then(() => {
      addEvent('open-issueish-in-pane', {package: 'github', from: 'issueish-list'});
    });
  }

  onOpenSearch = search => {
    const searchURL = search.getWebURL(this.props.remote);

    return new Promise((resolve, reject) => {
      shell.openExternal(searchURL, {}, err => {
        if (err) { reject(err); } else { resolve(); }
      });
    });
  }
}
