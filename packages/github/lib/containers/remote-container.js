import React from 'react';
import PropTypes from 'prop-types';
import {QueryRenderer, graphql} from 'react-relay';

import {incrementCounter} from '../reporter-proxy';
import {RemotePropType, RemoteSetPropType, BranchSetPropType, RefresherPropType, EndpointPropType} from '../prop-types';
import RelayNetworkLayerManager from '../relay-network-layer-manager';
import {UNAUTHENTICATED, INSUFFICIENT} from '../shared/keytar-strategy';
import RemoteController from '../controllers/remote-controller';
import ObserveModel from '../views/observe-model';
import LoadingView from '../views/loading-view';
import QueryErrorView from '../views/query-error-view';
import GithubLoginView from '../views/github-login-view';

export default class RemoteContainer extends React.Component {
  static propTypes = {
    // Connection
    loginModel: PropTypes.object.isRequired,
    endpoint: EndpointPropType.isRequired,

    // Repository attributes
    refresher: RefresherPropType.isRequired,
    pushInProgress: PropTypes.bool.isRequired,
    workingDirectory: PropTypes.string,
    workspace: PropTypes.object.isRequired,
    remote: RemotePropType.isRequired,
    remotes: RemoteSetPropType.isRequired,
    branches: BranchSetPropType.isRequired,
    aheadCount: PropTypes.number,

    // Action methods
    onPushBranch: PropTypes.func.isRequired,
  }

  fetchToken = loginModel => {
    return loginModel.getToken(this.props.endpoint.getLoginAccount());
  }

  render() {
    return (
      <ObserveModel model={this.props.loginModel} fetchData={this.fetchToken}>
        {this.renderWithToken}
      </ObserveModel>
    );
  }

  renderWithToken = token => {
    if (token === null) {
      return <LoadingView />;
    }

    if (token instanceof Error) {
      return (
        <QueryErrorView
          error={token}
          retry={this.handleTokenRetry}
          login={this.handleLogin}
          logout={this.handleLogout}
        />
      );
    }

    if (token === UNAUTHENTICATED) {
      return <GithubLoginView onLogin={this.handleLogin} />;
    }

    if (token === INSUFFICIENT) {
      return (
        <GithubLoginView onLogin={this.handleLogin}>
          <p>
            Your token no longer has sufficient authorizations. Please re-authenticate and generate a new one.
          </p>
        </GithubLoginView>
      );
    }

    const environment = RelayNetworkLayerManager.getEnvironmentForHost(this.props.endpoint, token);
    const query = graphql`
      query remoteContainerQuery($owner: String!, $name: String!) {
        repository(owner: $owner, name: $name) {
          id
          defaultBranchRef {
            prefix
            name
          }
        }
      }
    `;
    const variables = {
      owner: this.props.remote.getOwner(),
      name: this.props.remote.getRepo(),
    };

    return (
      <QueryRenderer
        environment={environment}
        variables={variables}
        query={query}
        render={result => this.renderWithResult(result, token)}
      />
    );
  }

  renderWithResult({error, props, retry}, token) {
    this.props.refresher.setRetryCallback(this, retry);

    if (error) {
      return (
        <QueryErrorView
          error={error}
          login={this.handleLogin}
          retry={retry}
          logout={this.handleLogout}
        />
      );
    }

    if (props === null) {
      return <LoadingView />;
    }

    return (
      <RemoteController
        endpoint={this.props.endpoint}
        token={token}

        repository={props.repository}

        workingDirectory={this.props.workingDirectory}
        workspace={this.props.workspace}
        remote={this.props.remote}
        remotes={this.props.remotes}
        branches={this.props.branches}

        aheadCount={this.props.aheadCount}
        pushInProgress={this.props.pushInProgress}

        onPushBranch={this.props.onPushBranch}
      />
    );
  }

  handleLogin = token => {
    incrementCounter('github-login');
    this.props.loginModel.setToken(this.props.endpoint.getLoginAccount(), token);
  }

  handleLogout = () => {
    incrementCounter('github-logout');
    this.props.loginModel.removeToken(this.props.endpoint.getLoginAccount());
  }

  handleTokenRetry = () => this.props.loginModel.didUpdate();
}
