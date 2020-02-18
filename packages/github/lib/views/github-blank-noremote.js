/* istanbul ignore file */

import React from 'react';
import PropTypes from 'prop-types';

export default function GitHubBlankNoRemote(props) {
  return (
    <div className="github-Local-NoRemotes github-Blank">
      <div className="github-Blank-LargeIcon icon icon-mark-github" />
      <p className="github-Blank-context">This repository has no remotes on GitHub.</p>
      <p className="github-Blank-option github-Blank-option--explained">
        <button className="github-Blank-actionBtn btn icon icon-globe" onClick={props.openBoundPublishDialog}>
          Publish on GitHub...
        </button>
      </p>
      <p className="github-Blank-explanation">
        Create a new GitHub repository and configure this git repository configured to push there.
      </p>
    </div>
  );
}

GitHubBlankNoRemote.propTypes = {
  openBoundPublishDialog: PropTypes.func.isRequired,
};
