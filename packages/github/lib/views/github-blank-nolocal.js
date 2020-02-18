/* istanbul ignore file */

import React from 'react';
import PropTypes from 'prop-types';

export default function GitHubBlankNoLocal(props) {
  return (
    <div className="github-NoLocal github-Blank">
      <div className="github-Blank-LargeIcon icon icon-mark-github" />
      <h1 className="github-Blank-banner">Welcome</h1>
      <p className="github-Blank-context">How would you like to get started today?</p>
      <p className="github-Blank-option">
        <button className="github-Blank-actionBtn btn icon icon-repo-create" onClick={props.openCreateDialog}>
          Create a new GitHub repository...
        </button>
      </p>
      <p className="github-Blank-option">
        <button className="github-Blank-actionBtn btn icon icon-repo-clone" onClick={props.openCloneDialog}>
          Clone an existing GitHub repository...
        </button>
      </p>
    </div>
  );
}

GitHubBlankNoLocal.propTypes = {
  openCreateDialog: PropTypes.func.isRequired,
  openCloneDialog: PropTypes.func.isRequired,
};
