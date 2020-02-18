import React from 'react';
import PropTypes from 'prop-types';
import yubikiri from 'yubikiri';
import {Disposable} from 'event-kit';

import {GithubLoginModelPropType, RefHolderPropType} from '../prop-types';
import OperationStateObserver, {PUSH, PULL, FETCH} from '../models/operation-state-observer';
import Refresher from '../models/refresher';
import GitHubTabController from '../controllers/github-tab-controller';
import ObserveModel from '../views/observe-model';
import RemoteSet from '../models/remote-set';
import BranchSet from '../models/branch-set';

export default class GitHubTabContainer extends React.Component {
  static propTypes = {
    workspace: PropTypes.object.isRequired,
    repository: PropTypes.object,
    loginModel: GithubLoginModelPropType.isRequired,
    rootHolder: RefHolderPropType.isRequired,

    changeWorkingDirectory: PropTypes.func.isRequired,
    onDidChangeWorkDirs: PropTypes.func.isRequired,
    getCurrentWorkDirs: PropTypes.func.isRequired,
    openCreateDialog: PropTypes.func.isRequired,
    openPublishDialog: PropTypes.func.isRequired,
    openCloneDialog: PropTypes.func.isRequired,
    openGitTab: PropTypes.func.isRequired,
  }

  constructor(props) {
    super(props);

    this.state = {
      lastRepository: null,
      remoteOperationObserver: new Disposable(),
      refresher: new Refresher(),
      observerSub: new Disposable(),
    };
  }

  static getDerivedStateFromProps(props, state) {
    if (props.repository !== state.lastRepository) {
      state.remoteOperationObserver.dispose();
      state.observerSub.dispose();

      const remoteOperationObserver = new OperationStateObserver(props.repository, PUSH, PULL, FETCH);
      const observerSub = remoteOperationObserver.onDidComplete(() => state.refresher.trigger());

      return {
        lastRepository: props.repository,
        remoteOperationObserver,
        observerSub,
      };
    }

    return null;
  }

  componentWillUnmount() {
    this.state.observerSub.dispose();
    this.state.remoteOperationObserver.dispose();
    this.state.refresher.dispose();
  }

  fetchRepositoryData = repository => {
    return yubikiri({
      workingDirectory: repository.getWorkingDirectoryPath(),
      allRemotes: repository.getRemotes(),
      branches: repository.getBranches(),
      selectedRemoteName: repository.getConfig('atomGithub.currentRemote'),
      aheadCount: async query => {
        const branches = await query.branches;
        const currentBranch = branches.getHeadBranch();
        return repository.getAheadCount(currentBranch.getName());
      },
      pushInProgress: repository.getOperationStates().isPushInProgress(),
    });
  }

  render() {
    return (
      <ObserveModel model={this.props.repository} fetchData={this.fetchRepositoryData}>
        {this.renderRepositoryData}
      </ObserveModel>
    );
  }

  renderRepositoryData = data => {
    if (!data || this.props.repository.isLoading()) {
      return (
        <GitHubTabController
          {...this.props}
          refresher={this.state.refresher}

          allRemotes={new RemoteSet()}
          branches={new BranchSet()}
          aheadCount={0}
          pushInProgress={false}
          isLoading={true}
        />
      );
    }

    if (!this.props.repository.isPresent()) {
      return (
        <GitHubTabController
          {...this.props}
          refresher={this.state.refresher}

          allRemotes={new RemoteSet()}
          branches={new BranchSet()}
          aheadCount={0}
          pushInProgress={false}
          isLoading={false}
        />
      );
    }

    return (
      <GitHubTabController
        {...data}
        {...this.props}
        refresher={this.state.refresher}
        isLoading={false}
      />
    );
  }
}
