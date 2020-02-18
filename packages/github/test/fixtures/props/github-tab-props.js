import {InMemoryStrategy} from '../../../lib/shared/keytar-strategy';
import GithubLoginModel from '../../../lib/models/github-login-model';
import RefHolder from '../../../lib/models/ref-holder';
import OperationStateObserver, {PUSH, PULL, FETCH} from '../../../lib/models/operation-state-observer';
import RemoteSet from '../../../lib/models/remote-set';
import {nullRemote} from '../../../lib/models/remote';
import BranchSet from '../../../lib/models/branch-set';
import {nullBranch} from '../../../lib/models/branch';
import {nullAuthor} from '../../../lib/models/author';

export function gitHubTabItemProps(atomEnv, repository, overrides = {}) {
  return {
    workspace: atomEnv.workspace,
    repository,
    loginModel: new GithubLoginModel(InMemoryStrategy),
    changeWorkingDirectory: () => {},
    onDidChangeWorkDirs: () => ({dispose: () => {}}),
    getCurrentWorkDirs: () => [],
    ...overrides,
  };
}

export function gitHubTabContainerProps(atomEnv, repository, overrides = {}) {
  return {
    ...gitHubTabItemProps(atomEnv, repository),
    rootHolder: new RefHolder(),
    ...overrides,
  };
}

export function gitHubTabControllerProps(atomEnv, repository, overrides = {}) {
  return {
    ...gitHubTabContainerProps(atomEnv, repository),
    remoteOperationObserver: new OperationStateObserver(repository, PUSH, PULL, FETCH),
    workingDirectory: repository.getWorkingDirectoryPath(),
    allRemotes: new RemoteSet(),
    branches: new BranchSet(),
    aheadCount: 0,
    pushInProgress: false,
    ...overrides,
  };
}

export function gitHubTabViewProps(atomEnv, repository, overrides = {}) {
  return {
    workspace: atomEnv.workspace,
    remoteOperationObserver: new OperationStateObserver(repository, PUSH, PULL, FETCH),
    loginModel: new GithubLoginModel(InMemoryStrategy),
    rootHolder: new RefHolder(),

    workingDirectory: repository.getWorkingDirectoryPath(),
    branches: new BranchSet(),
    currentBranch: nullBranch,
    remotes: new RemoteSet(),
    currentRemote: nullRemote,
    manyRemotesAvailable: false,
    aheadCount: 0,
    pushInProgress: false,

    handlePushBranch: () => {},
    handleRemoteSelect: () => {},
    changeWorkingDirectory: () => {},
    onDidChangeWorkDirs: () => ({dispose: () => {}}),
    getCurrentWorkDirs: () => [],
    repository,

    ...overrides,
  };
}
