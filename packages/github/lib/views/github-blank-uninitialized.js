/* istanbul ignore file */

import React from 'react';
import PropTypes from 'prop-types';

import Octicon from '../atom/octicon';

export default function GitHubBlankUninitialized(props) {
  return (
    <div className="github-Local-Uninit github-Blank">
      <main className="github-Blank-body">
        <div className="github-Blank-LargeIcon icon icon-mark-github" />
        <p className="github-Blank-context">This repository is not yet version controlled by git.</p>
        <p className="github-Blank-option">
          <button className="github-Blank-actionBtn btn icon icon-globe" onClick={props.openBoundPublishDialog}>
            Initialize and publish on GitHub...
          </button>
        </p>
        <p className="github-Blank-explanation">
          Create a new GitHub repository, then track the existing content within this directory as a git repository
          configured to push there.
        </p>
        <p className="github-Blank-footer github-Blank-explanation">
          To initialize this directory as a git repository without publishing it to GitHub, visit the
          <button className="github-Blank-tabLink" onClick={props.openGitTab}>
            <Octicon icon="git-commit" />Git tab.
          </button>
        </p>
      </main>
    </div>
  );
}

GitHubBlankUninitialized.propTypes = {
  openBoundPublishDialog: PropTypes.func.isRequired,
  openGitTab: PropTypes.func.isRequired,
};
