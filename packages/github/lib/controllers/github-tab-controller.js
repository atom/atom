import React from 'react';
import PropTypes from 'prop-types';

import {
  GithubLoginModelPropType, RefHolderPropType, RemoteSetPropType, BranchSetPropType, RefresherPropType,
} from '../prop-types';
import GitHubTabView from '../views/github-tab-view';

export default class GitHubTabController extends React.Component {
  static propTypes = {
    workspace: PropTypes.object.isRequired,
    refresher: RefresherPropType.isRequired,
    loginModel: GithubLoginModelPropType.isRequired,
    rootHolder: RefHolderPropType.isRequired,

    workingDirectory: PropTypes.string,
    repository: PropTypes.object.isRequired,
    allRemotes: RemoteSetPropType.isRequired,
    branches: BranchSetPropType.isRequired,
    selectedRemoteName: PropTypes.string,
    aheadCount: PropTypes.number,
    pushInProgress: PropTypes.bool.isRequired,
    isLoading: PropTypes.bool.isRequired,
    currentWorkDir: PropTypes.string,

    changeWorkingDirectory: PropTypes.func.isRequired,
    setContextLock: PropTypes.func.isRequired,
    contextLocked: PropTypes.bool.isRequired,
    onDidChangeWorkDirs: PropTypes.func.isRequired,
    getCurrentWorkDirs: PropTypes.func.isRequired,
    openCreateDialog: PropTypes.func.isRequired,
    openPublishDialog: PropTypes.func.isRequired,
    openCloneDialog: PropTypes.func.isRequired,
    openGitTab: PropTypes.func.isRequired,
  }

  render() {
    const gitHubRemotes = this.props.allRemotes.filter(remote => remote.isGithubRepo());
    const currentBranch = this.props.branches.getHeadBranch();

    let currentRemote = gitHubRemotes.withName(this.props.selectedRemoteName);
    let manyRemotesAvailable = false;
    if (!currentRemote.isPresent() && gitHubRemotes.size() === 1) {
      currentRemote = Array.from(gitHubRemotes)[0];
    } else if (!currentRemote.isPresent() && gitHubRemotes.size() > 1) {
      manyRemotesAvailable = true;
    }

    return (
      <GitHubTabView
        // Connection
        loginModel={this.props.loginModel}

        workspace={this.props.workspace}
        refresher={this.props.refresher}
        rootHolder={this.props.rootHolder}

        workingDirectory={this.props.workingDirectory || this.props.currentWorkDir}
        contextLocked={this.props.contextLocked}
        repository={this.props.repository}
        branches={this.props.branches}
        currentBranch={currentBranch}
        remotes={gitHubRemotes}
        currentRemote={currentRemote}
        manyRemotesAvailable={manyRemotesAvailable}
        aheadCount={this.props.aheadCount}
        pushInProgress={this.props.pushInProgress}
        isLoading={this.props.isLoading}

        handlePushBranch={this.handlePushBranch}
        handleRemoteSelect={this.handleRemoteSelect}
        changeWorkingDirectory={this.props.changeWorkingDirectory}
        setContextLock={this.props.setContextLock}
        getCurrentWorkDirs={this.props.getCurrentWorkDirs}
        onDidChangeWorkDirs={this.props.onDidChangeWorkDirs}
        openCreateDialog={this.props.openCreateDialog}
        openBoundPublishDialog={this.openBoundPublishDialog}
        openCloneDialog={this.props.openCloneDialog}
        openGitTab={this.props.openGitTab}
      />
    );
  }

  handlePushBranch = (currentBranch, targetRemote) => {
    return this.props.repository.push(currentBranch.getName(), {
      remote: targetRemote,
      setUpstream: true,
    });
  }

  handleRemoteSelect = (e, remote) => {
    e.preventDefault();
    return this.props.repository.setConfig('atomGithub.currentRemote', remote.getName());
  }

  openBoundPublishDialog = () => this.props.openPublishDialog(this.props.repository);
}
