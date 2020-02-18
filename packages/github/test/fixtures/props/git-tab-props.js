import ResolutionProgress from '../../../lib/models/conflicts/resolution-progress';
import {InMemoryStrategy} from '../../../lib/shared/keytar-strategy';
import GithubLoginModel from '../../../lib/models/github-login-model';
import RefHolder from '../../../lib/models/ref-holder';
import UserStore from '../../../lib/models/user-store';
import {nullAuthor} from '../../../lib/models/author';

function noop() {}

export function gitTabItemProps(atomEnv, repository, overrides = {}) {
  return {
    repository,
    loginModel: new GithubLoginModel(InMemoryStrategy),
    workspace: atomEnv.workspace,
    commands: atomEnv.commands,
    grammars: atomEnv.grammars,
    resolutionProgress: new ResolutionProgress(),
    notificationManager: atomEnv.notifications,
    config: atomEnv.config,
    project: atomEnv.project,
    tooltips: atomEnv.tooltips,
    confirm: noop,
    ensureGitTab: noop,
    refreshResolutionProgress: noop,
    undoLastDiscard: noop,
    discardWorkDirChangesForPaths: noop,
    openFiles: noop,
    openInitializeDialog: noop,
    changeWorkingDirectory: noop,
    contextLocked: false,
    setContextLock: () => {},
    onDidChangeWorkDirs: () => ({dispose: () => {}}),
    getCurrentWorkDirs: () => new Set(),
    ...overrides
  };
}

export function gitTabContainerProps(atomEnv, repository, overrides = {}) {
  return gitTabItemProps(atomEnv, repository, overrides);
}

export async function gitTabControllerProps(atomEnv, repository, overrides = {}) {
  const repoProps = {
    lastCommit: await repository.getLastCommit(),
    recentCommits: await repository.getRecentCommits({max: 10}),
    isMerging: await repository.isMerging(),
    isRebasing: await repository.isRebasing(),
    hasUndoHistory: await repository.hasDiscardHistory(),
    currentBranch: await repository.getCurrentBranch(),
    unstagedChanges: await repository.getUnstagedChanges(),
    stagedChanges: await repository.getStagedChanges(),
    mergeConflicts: await repository.getMergeConflicts(),
    workingDirectoryPath: repository.getWorkingDirectoryPath(),
    fetchInProgress: false,
    ...overrides,
  };

  repoProps.mergeMessage = repoProps.isMerging ? await repository.getMergeMessage() : null;

  return gitTabContainerProps(atomEnv, repository, repoProps);
}

export async function gitTabViewProps(atomEnv, repository, overrides = {}) {
  const props = {
    refRoot: new RefHolder(),
    refStagingView: new RefHolder(),

    repository,
    isLoading: false,

    lastCommit: await repository.getLastCommit(),
    currentBranch: await repository.getCurrentBranch(),
    recentCommits: await repository.getRecentCommits({max: 10}),
    isMerging: await repository.isMerging(),
    isRebasing: await repository.isRebasing(),
    hasUndoHistory: await repository.hasDiscardHistory(),
    unstagedChanges: await repository.getUnstagedChanges(),
    stagedChanges: await repository.getStagedChanges(),
    mergeConflicts: await repository.getMergeConflicts(),
    workingDirectoryPath: repository.getWorkingDirectoryPath(),

    selectedCoAuthors: [],
    updateSelectedCoAuthors: () => {},
    resolutionProgress: new ResolutionProgress(),

    workspace: atomEnv.workspace,
    commands: atomEnv.commands,
    grammars: atomEnv.grammars,
    notificationManager: atomEnv.notifications,
    config: atomEnv.config,
    project: atomEnv.project,
    tooltips: atomEnv.tooltips,

    openInitializeDialog: () => {},
    abortMerge: () => {},
    commit: () => {},
    undoLastCommit: () => {},
    prepareToCommit: () => {},
    resolveAsOurs: () => {},
    resolveAsTheirs: () => {},
    undoLastDiscard: () => {},
    attemptStageAllOperation: () => {},
    attemptFileStageOperation: () => {},
    discardWorkDirChangesForPaths: () => {},
    openFiles: () => {},

    contextLocked: false,
    changeWorkingDirectory: () => {},
    setContextLock: () => {},
    onDidChangeWorkDirs: () => ({dispose: () => {}}),
    getCurrentWorkDirs: () => new Set(),
    onDidUpdateRepo: () => ({dispose: () => {}}),
    getCommitter: () => nullAuthor,

    ...overrides,
  };

  props.mergeMessage = props.isMerging ? await repository.getMergeMessage() : null;
  props.userStore = new UserStore({
    repository: props.repository,
    login: new GithubLoginModel(InMemoryStrategy),
    config: props.config,
  });

  return props;
}
