import React from 'react';
import PropTypes from 'prop-types';

import Octicon from '../atom/octicon';

export default class OfflineView extends React.Component {
  static propTypes = {
    retry: PropTypes.func.isRequired,
  }

  componentDidMount() {
    window.addEventListener('online', this.props.retry);
  }

  componentWillUnmount() {
    window.removeEventListener('online', this.props.retry);
  }

  render() {
    return (
      <div className="github-Offline github-Message">
        <div className="github-Message-wrapper">
          <Octicon className="github-Offline-logo" icon="alignment-unalign" />
          <h1 className="github-Message-title">Offline</h1>
          <p className="github-Message-description">
            You don't seem to be connected to the Internet. When you're back online, we'll try again.
          </p>
          <p className="github-Message-action">
            <button className="github-Message-button btn" onClick={this.props.retry}>Retry</button>
          </p>
        </div>
      </div>
    );
  }
}
