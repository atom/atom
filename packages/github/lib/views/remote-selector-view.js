import React from 'react';
import PropTypes from 'prop-types';

import {RemoteSetPropType, BranchPropType} from '../prop-types';

export default class RemoteSelectorView extends React.Component {
  static propTypes = {
    remotes: RemoteSetPropType.isRequired,
    currentBranch: BranchPropType.isRequired,
    selectRemote: PropTypes.func.isRequired,
  }

  render() {
    const {remotes, currentBranch, selectRemote} = this.props;
    // todo: ask Ash how to test this before merging.
    return (
      <div className="github-RemoteSelector">
        <div className="github-GitHub-LargeIcon icon icon-mirror" />
        <h1>Select a Remote</h1>
        <div className="initialize-repo-description">
          <span>This repository has multiple remotes hosted at GitHub.com.
          Select a remote to see pull requests associated
          with the <strong>{currentBranch.getName()}</strong> branch:</span>
        </div>

        <ul>
          {Array.from(remotes, remote => (
            <li key={remote.getName()}>
              <button className="btn btn-primary" onClick={e => selectRemote(e, remote)}>
                {remote.getName()} ({remote.getOwner()}/{remote.getRepo()})
              </button>
            </li>
          ))}
        </ul>
      </div>
    );
  }
}
