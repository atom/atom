import React from 'react';
import PropTypes from 'prop-types';

import {
  GithubLoginModelPropType, RefHolderPropType, RemoteSetPropType, RemotePropType, BranchSetPropType, BranchPropType,
  RefresherPropType,
} from '../prop-types';
import LoadingView from './loading-view';
import RemoteSelectorView from './remote-selector-view';
import GithubTabHeaderContainer from '../containers/github-tab-header-container';
import GithubTabHeaderController from '../controllers/github-tab-header-controller';
import GitHubBlankNoLocal from './github-blank-nolocal';
import GitHubBlankUninitialized from './github-blank-uninitialized';
import GitHubBlankNoRemote from './github-blank-noremote';
import RemoteContainer from '../containers/remote-container';
import {nullAuthor} from '../models/author';

export default class GitHubTabView extends React.Component {
  static propTypes = {
    refresher: RefresherPropType.isRequired,
    rootHolder: RefHolderPropType.isRequired,

    // Connection
    loginModel: GithubLoginModelPropType.isRequired,

    // Workspace
    workspace: PropTypes.object.isRequired,
    workingDirectory: PropTypes.string,
    getCurrentWorkDirs: PropTypes.func.isRequired,
    changeWorkingDirectory: PropTypes.func.isRequired,
    contextLocked: PropTypes.bool.isRequired,
    setContextLock: PropTypes.func.isRequired,
    repository: PropTypes.object.isRequired,

    // Remotes
    remotes: RemoteSetPropType.isRequired,
    currentRemote: RemotePropType.isRequired,
    manyRemotesAvailable: PropTypes.bool.isRequired,
    isLoading: PropTypes.bool.isRequired,
    branches: BranchSetPropType.isRequired,
    currentBranch: BranchPropType.isRequired,
    aheadCount: PropTypes.number,
    pushInProgress: PropTypes.bool.isRequired,

    // Event Handlers
    handleWorkDirSelect: PropTypes.func,
    handlePushBranch: PropTypes.func.isRequired,
    handleRemoteSelect: PropTypes.func.isRequired,
    onDidChangeWorkDirs: PropTypes.func.isRequired,
    openCreateDialog: PropTypes.func.isRequired,
    openBoundPublishDialog: PropTypes.func.isRequired,
    openCloneDialog: PropTypes.func.isRequired,
    openGitTab: PropTypes.func.isRequired,
  }

  render() {
    return (
      <div className="github-GitHub" ref={this.props.rootHolder.setter}>
        {this.renderHeader()}
        <div className="github-GitHub-content">
          {this.renderRemote()}
        </div>
      </div>
    );
  }

  renderRemote() {
    if (this.props.isLoading) {
      return <LoadingView />;
    }

    if (this.props.repository.isAbsent() || this.props.repository.isAbsentGuess()) {
      return (
        <GitHubBlankNoLocal
          openCreateDialog={this.props.openCreateDialog}
          openCloneDialog={this.props.openCloneDialog}
        />
      );
    }

    if (this.props.repository.isEmpty()) {
      return (
        <GitHubBlankUninitialized
          openBoundPublishDialog={this.props.openBoundPublishDialog}
          openGitTab={this.props.openGitTab}
        />
      );
    }

    if (this.props.currentRemote.isPresent()) {
      // Single, chosen or unambiguous remote
      return (
        <RemoteContainer
          // Connection
          loginModel={this.props.loginModel}
          endpoint={this.props.currentRemote.getEndpoint()}

          // Workspace
          workspace={this.props.workspace}
          workingDirectory={this.props.workingDirectory}

          // Remote
          remote={this.props.currentRemote}
          remotes={this.props.remotes}
          branches={this.props.branches}
          aheadCount={this.props.aheadCount}
          pushInProgress={this.props.pushInProgress}
          refresher={this.props.refresher}

          // Event Handlers
          onPushBranch={() => this.props.handlePushBranch(this.props.currentBranch, this.props.currentRemote)}
        />
      );
    }

    if (this.props.manyRemotesAvailable) {
      // No chosen remote, multiple remotes hosted on GitHub instances
      return (
        <RemoteSelectorView
          remotes={this.props.remotes}
          currentBranch={this.props.currentBranch}
          selectRemote={this.props.handleRemoteSelect}
        />
      );
    }

    return (
      <GitHubBlankNoRemote openBoundPublishDialog={this.props.openBoundPublishDialog} />
    );
  }

  renderHeader() {
    if (this.props.currentRemote.isPresent()) {
      return (
        <GithubTabHeaderContainer
          // Connection
          loginModel={this.props.loginModel}
          endpoint={this.props.currentRemote.getEndpoint()}

          // Workspace
          currentWorkDir={this.props.workingDirectory}
          contextLocked={this.props.contextLocked}
          changeWorkingDirectory={this.props.changeWorkingDirectory}
          setContextLock={this.props.setContextLock}
          getCurrentWorkDirs={this.props.getCurrentWorkDirs}

          // Event Handlers
          // handleWorkDirSelect={e => this.props.changeWorkingDirectory(e.target.value)}
          onDidChangeWorkDirs={this.props.onDidChangeWorkDirs}
        />
      );
    }
    return (
      <GithubTabHeaderController
        user={nullAuthor}

        // Workspace
        currentWorkDir={this.props.workingDirectory}
        contextLocked={this.props.contextLocked}
        changeWorkingDirectory={this.props.changeWorkingDirectory}
        setContextLock={this.props.setContextLock}
        getCurrentWorkDirs={this.props.getCurrentWorkDirs}

        // Event Handlers
        onDidChangeWorkDirs={this.props.onDidChangeWorkDirs}
      />
    );
  }
}
