import React from 'react';
import PropTypes from 'prop-types';

import GithubLoginView from './github-login-view';
import ErrorView from './error-view';
import OfflineView from './offline-view';

export default class QueryErrorView extends React.Component {
  static propTypes = {
    error: PropTypes.shape({
      name: PropTypes.string.isRequired,
      message: PropTypes.string.isRequired,
      stack: PropTypes.string.isRequired,
      response: PropTypes.shape({
        status: PropTypes.number.isRequired,
      }),
      responseText: PropTypes.string,
      errors: PropTypes.arrayOf(PropTypes.shape({
        message: PropTypes.string.isRequired,
      })),
    }).isRequired,
    login: PropTypes.func.isRequired,
    retry: PropTypes.func,
    logout: PropTypes.func,
  }

  render() {
    const e = this.props.error;

    if (e.response) {
      switch (e.response.status) {
      case 401: return this.render401();
      case 200:
        // Do the default
        break;
      default: return this.renderUnknown(e.response, e.responseText);
      }
    }

    if (e.errors) {
      return this.renderGraphQLErrors(e.errors);
    }

    if (e.network) {
      return this.renderNetworkError();
    }

    return (
      <ErrorView
        title={e.message}
        descriptions={[e.stack]}
        preformatted={true}
        {...this.errorViewProps()}
      />
    );
  }

  renderGraphQLErrors(errors) {
    return (
      <ErrorView
        title="Query errors reported"
        descriptions={errors.map(e => e.message)}
        {...this.errorViewProps()}
      />
    );
  }

  renderNetworkError() {
    return <OfflineView retry={this.props.retry} />;
  }

  render401() {
    return (
      <div className="github-GithubLoginView-Container">
        <GithubLoginView onLogin={this.props.login}>
          <p>
            The API endpoint returned a unauthorized error. Please try to re-authenticate with the endpoint.
          </p>
        </GithubLoginView>
      </div>
    );
  }

  renderUnknown(response, text) {
    return (
      <ErrorView
        title={`Received an error response: ${response.status}`}
        descriptions={[text]}
        preformatted={true}
        {...this.errorViewProps()}
      />
    );
  }

  errorViewProps() {
    return {
      retry: this.props.retry,
      logout: this.props.logout,
    };
  }
}
