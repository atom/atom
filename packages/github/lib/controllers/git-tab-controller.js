import path from 'path';

import React from 'react';
import PropTypes from 'prop-types';

import GitTabView from '../views/git-tab-view';
import UserStore from '../models/user-store';
import RefHolder from '../models/ref-holder';
import {
  CommitPropType, BranchPropType, FilePatchItemPropType, MergeConflictItemPropType, RefHolderPropType,
} from '../prop-types';
import {autobind} from '../helpers';

export default class GitTabController extends React.Component {
  static focus = {
    ...GitTabView.focus,
  };

  static propTypes = {
    repository: PropTypes.object.isRequired,
    loginModel: PropTypes.object.isRequired,

    lastCommit: CommitPropType.isRequired,
    recentCommits: PropTypes.arrayOf(CommitPropType).isRequired,
    isMerging: PropTypes.bool.isRequired,
    isRebasing: PropTypes.bool.isRequired,
    hasUndoHistory: PropTypes.bool.isRequired,
    currentBranch: BranchPropType.isRequired,
    unstagedChanges: PropTypes.arrayOf(FilePatchItemPropType).isRequired,
    stagedChanges: PropTypes.arrayOf(FilePatchItemPropType).isRequired,
    mergeConflicts: PropTypes.arrayOf(MergeConflictItemPropType).isRequired,
    workingDirectoryPath: PropTypes.string,
    mergeMessage: PropTypes.string,
    fetchInProgress: PropTypes.bool.isRequired,
    currentWorkDir: PropTypes.string,

    workspace: PropTypes.object.isRequired,
    commands: PropTypes.object.isRequired,
    grammars: PropTypes.object.isRequired,
    resolutionProgress: PropTypes.object.isRequired,
    notificationManager: PropTypes.object.isRequired,
    config: PropTypes.object.isRequired,
    project: PropTypes.object.isRequired,
    tooltips: PropTypes.object.isRequired,

    confirm: PropTypes.func.isRequired,
    ensureGitTab: PropTypes.func.isRequired,
    refreshResolutionProgress: PropTypes.func.isRequired,
    undoLastDiscard: PropTypes.func.isRequired,
    discardWorkDirChangesForPaths: PropTypes.func.isRequired,
    openFiles: PropTypes.func.isRequired,
    openInitializeDialog: PropTypes.func.isRequired,
    controllerRef: RefHolderPropType,
    contextLocked: PropTypes.bool.isRequired,
    changeWorkingDirectory: PropTypes.func.isRequired,
    setContextLock: PropTypes.func.isRequired,
    onDidChangeWorkDirs: PropTypes.func.isRequired,
    getCurrentWorkDirs: PropTypes.func.isRequired,
  };

  constructor(props, context) {
    super(props, context);
    autobind(
      this,
      'attemptStageAllOperation', 'attemptFileStageOperation', 'unstageFiles', 'prepareToCommit',
      'commit', 'updateSelectedCoAuthors', 'undoLastCommit', 'abortMerge', 'resolveAsOurs', 'resolveAsTheirs',
      'checkout', 'rememberLastFocus', 'quietlySelectItem',
    );

    this.stagingOperationInProgress = false;
    this.lastFocus = GitTabView.focus.STAGING;

    this.refView = new RefHolder();
    this.refRoot = new RefHolder();
    this.refStagingView = new RefHolder();

    this.state = {
      selectedCoAuthors: [],
    };

    this.userStore = new UserStore({
      repository: this.props.repository,
      login: this.props.loginModel,
      config: this.props.config,
    });
  }

  render() {
    return (
      <GitTabView
        ref={this.refView.setter}
        refRoot={this.refRoot}
        refStagingView={this.refStagingView}

        isLoading={this.props.fetchInProgress}
        repository={this.props.repository}

        lastCommit={this.props.lastCommit}
        recentCommits={this.props.recentCommits}
        isMerging={this.props.isMerging}
        isRebasing={this.props.isRebasing}
        hasUndoHistory={this.props.hasUndoHistory}
        currentBranch={this.props.currentBranch}
        unstagedChanges={this.props.unstagedChanges}
        stagedChanges={this.props.stagedChanges}
        mergeConflicts={this.props.mergeConflicts}
        workingDirectoryPath={this.props.workingDirectoryPath || this.props.currentWorkDir}
        mergeMessage={this.props.mergeMessage}
        userStore={this.userStore}
        selectedCoAuthors={this.state.selectedCoAuthors}
        updateSelectedCoAuthors={this.updateSelectedCoAuthors}

        resolutionProgress={this.props.resolutionProgress}
        workspace={this.props.workspace}
        commands={this.props.commands}
        grammars={this.props.grammars}
        tooltips={this.props.tooltips}
        notificationManager={this.props.notificationManager}
        project={this.props.project}
        confirm={this.props.confirm}
        config={this.props.config}

        openInitializeDialog={this.props.openInitializeDialog}
        openFiles={this.props.openFiles}
        discardWorkDirChangesForPaths={this.props.discardWorkDirChangesForPaths}
        undoLastDiscard={this.props.undoLastDiscard}
        contextLocked={this.props.contextLocked}
        changeWorkingDirectory={this.props.changeWorkingDirectory}
        setContextLock={this.props.setContextLock}
        getCurrentWorkDirs={this.props.getCurrentWorkDirs}
        onDidChangeWorkDirs={this.props.onDidChangeWorkDirs}

        attemptFileStageOperation={this.attemptFileStageOperation}
        attemptStageAllOperation={this.attemptStageAllOperation}
        prepareToCommit={this.prepareToCommit}
        commit={this.commit}
        undoLastCommit={this.undoLastCommit}
        push={this.push}
        pull={this.pull}
        fetch={this.fetch}
        checkout={this.checkout}
        abortMerge={this.abortMerge}
        resolveAsOurs={this.resolveAsOurs}
        resolveAsTheirs={this.resolveAsTheirs}
      />
    );
  }

  componentDidMount() {
    this.refreshResolutionProgress(false, false);
    this.refRoot.map(root => root.addEventListener('focusin', this.rememberLastFocus));

    if (this.props.controllerRef) {
      this.props.controllerRef.setter(this);
    }
  }

  componentDidUpdate() {
    this.userStore.setRepository(this.props.repository);
    this.userStore.setLoginModel(this.props.loginModel);
    this.refreshResolutionProgress(false, false);
  }

  componentWillUnmount() {
    this.refRoot.map(root => root.removeEventListener('focusin', this.rememberLastFocus));
  }

  /*
   * Begin (but don't await) an async conflict-counting task for each merge conflict path that has no conflict
   * marker count yet. Omit any path that's already open in a TextEditor or that has already been counted.
   *
   * includeOpen - update marker counts for files that are currently open in TextEditors
   * includeCounted - update marker counts for files that have been counted before
   */
  refreshResolutionProgress(includeOpen, includeCounted) {
    if (this.props.fetchInProgress) {
      return;
    }

    const openPaths = new Set(
      this.props.workspace.getTextEditors().map(editor => editor.getPath()),
    );

    for (let i = 0; i < this.props.mergeConflicts.length; i++) {
      const conflictPath = path.join(
        this.props.workingDirectoryPath,
        this.props.mergeConflicts[i].filePath,
      );

      if (!includeOpen && openPaths.has(conflictPath)) {
        continue;
      }

      if (!includeCounted && this.props.resolutionProgress.getRemaining(conflictPath) !== undefined) {
        continue;
      }

      this.props.refreshResolutionProgress(conflictPath);
    }
  }

  attemptStageAllOperation(stageStatus) {
    return this.attemptFileStageOperation(['.'], stageStatus);
  }

  attemptFileStageOperation(filePaths, stageStatus) {
    if (this.stagingOperationInProgress) {
      return {
        stageOperationPromise: Promise.resolve(),
        selectionUpdatePromise: Promise.resolve(),
      };
    }

    this.stagingOperationInProgress = true;

    const fileListUpdatePromise = this.refStagingView.map(view => {
      return view.getNextListUpdatePromise();
    }).getOr(Promise.resolve());
    let stageOperationPromise;
    if (stageStatus === 'staged') {
      stageOperationPromise = this.unstageFiles(filePaths);
    } else {
      stageOperationPromise = this.stageFiles(filePaths);
    }
    const selectionUpdatePromise = fileListUpdatePromise.then(() => {
      this.stagingOperationInProgress = false;
    });

    return {stageOperationPromise, selectionUpdatePromise};
  }

  async stageFiles(filePaths) {
    const pathsToStage = new Set(filePaths);

    const mergeMarkers = await Promise.all(
      filePaths.map(async filePath => {
        return {
          filePath,
          hasMarkers: await this.props.repository.pathHasMergeMarkers(filePath),
        };
      }),
    );

    for (const {filePath, hasMarkers} of mergeMarkers) {
      if (hasMarkers) {
        const choice = this.props.confirm({
          message: 'File contains merge markers: ',
          detailedMessage: `Do you still want to stage this file?\n${filePath}`,
          buttons: ['Stage', 'Cancel'],
        });
        if (choice !== 0) { pathsToStage.delete(filePath); }
      }
    }

    return this.props.repository.stageFiles(Array.from(pathsToStage));
  }

  unstageFiles(filePaths) {
    return this.props.repository.unstageFiles(filePaths);
  }

  async prepareToCommit() {
    return !await this.props.ensureGitTab();
  }

  commit(message, options) {
    return this.props.repository.commit(message, options);
  }

  updateSelectedCoAuthors(selectedCoAuthors, newAuthor) {
    if (newAuthor) {
      this.userStore.addUsers([newAuthor]);
      selectedCoAuthors = selectedCoAuthors.concat([newAuthor]);
    }
    this.setState({selectedCoAuthors});
  }

  async undoLastCommit() {
    const repo = this.props.repository;
    const lastCommit = await repo.getLastCommit();
    if (lastCommit.isUnbornRef()) { return null; }

    await repo.undoLastCommit();
    repo.setCommitMessage(lastCommit.getFullMessage());
    this.updateSelectedCoAuthors(lastCommit.getCoAuthors());

    return null;
  }

  async abortMerge() {
    const choice = this.props.confirm({
      message: 'Abort merge',
      detailedMessage: 'Are you sure?',
      buttons: ['Abort', 'Cancel'],
    });
    if (choice !== 0) { return; }

    try {
      await this.props.repository.abortMerge();
    } catch (e) {
      if (e.code === 'EDIRTYSTAGED') {
        this.props.notificationManager.addError(
          `Cannot abort because ${e.path} is both dirty and staged.`,
          {dismissable: true},
        );
      } else {
        throw e;
      }
    }
  }

  async resolveAsOurs(paths) {
    if (this.props.fetchInProgress) {
      return;
    }

    const side = this.props.isRebasing ? 'theirs' : 'ours';
    await this.props.repository.checkoutSide(side, paths);
    this.refreshResolutionProgress(false, true);
  }

  async resolveAsTheirs(paths) {
    if (this.props.fetchInProgress) {
      return;
    }

    const side = this.props.isRebasing ? 'ours' : 'theirs';
    await this.props.repository.checkoutSide(side, paths);
    this.refreshResolutionProgress(false, true);
  }

  checkout(branchName, options) {
    return this.props.repository.checkout(branchName, options);
  }

  rememberLastFocus(event) {
    this.lastFocus = this.refView.map(view => view.getFocus(event.target)).getOr(null) || GitTabView.focus.STAGING;
  }

  restoreFocus() {
    this.refView.map(view => view.setFocus(this.lastFocus));
  }

  hasFocus() {
    return this.refRoot.map(root => root.contains(document.activeElement)).getOr(false);
  }

  wasActivated(isStillActive) {
    process.nextTick(() => {
      isStillActive() && this.restoreFocus();
    });
  }

  focusAndSelectStagingItem(filePath, stagingStatus) {
    return this.refView.map(view => view.focusAndSelectStagingItem(filePath, stagingStatus)).getOr(null);
  }

  focusAndSelectCommitPreviewButton() {
    return this.refView.map(view => view.focusAndSelectCommitPreviewButton());
  }

  focusAndSelectRecentCommit() {
    return this.refView.map(view => view.focusAndSelectRecentCommit());
  }

  quietlySelectItem(filePath, stagingStatus) {
    return this.refView.map(view => view.quietlySelectItem(filePath, stagingStatus)).getOr(null);
  }
}
