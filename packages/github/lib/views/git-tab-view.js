import React, {Fragment} from 'react';
import PropTypes from 'prop-types';
import cx from 'classnames';
import {CompositeDisposable} from 'atom';

import StagingView from './staging-view';
import GitTabHeaderController from '../controllers/git-tab-header-controller';
import CommitController from '../controllers/commit-controller';
import RecentCommitsController from '../controllers/recent-commits-controller';
import RefHolder from '../models/ref-holder';
import {isValidWorkdir, autobind} from '../helpers';
import {AuthorPropType, UserStorePropType, RefHolderPropType} from '../prop-types';

export default class GitTabView extends React.Component {
  static focus = {
    ...StagingView.focus,
    ...CommitController.focus,
    ...RecentCommitsController.focus,
  };

  static propTypes = {
    refRoot: RefHolderPropType,
    refStagingView: RefHolderPropType,

    repository: PropTypes.object.isRequired,
    isLoading: PropTypes.bool.isRequired,

    lastCommit: PropTypes.object.isRequired,
    currentBranch: PropTypes.object,
    recentCommits: PropTypes.arrayOf(PropTypes.object).isRequired,
    isMerging: PropTypes.bool,
    isRebasing: PropTypes.bool,
    hasUndoHistory: PropTypes.bool,
    unstagedChanges: PropTypes.arrayOf(PropTypes.object),
    stagedChanges: PropTypes.arrayOf(PropTypes.object),
    mergeConflicts: PropTypes.arrayOf(PropTypes.object),
    workingDirectoryPath: PropTypes.string,
    mergeMessage: PropTypes.string,
    userStore: UserStorePropType.isRequired,
    selectedCoAuthors: PropTypes.arrayOf(AuthorPropType),
    updateSelectedCoAuthors: PropTypes.func.isRequired,

    workspace: PropTypes.object.isRequired,
    commands: PropTypes.object.isRequired,
    grammars: PropTypes.object.isRequired,
    resolutionProgress: PropTypes.object.isRequired,
    notificationManager: PropTypes.object.isRequired,
    config: PropTypes.object.isRequired,
    project: PropTypes.object.isRequired,
    tooltips: PropTypes.object.isRequired,

    openInitializeDialog: PropTypes.func.isRequired,
    abortMerge: PropTypes.func.isRequired,
    commit: PropTypes.func.isRequired,
    undoLastCommit: PropTypes.func.isRequired,
    prepareToCommit: PropTypes.func.isRequired,
    resolveAsOurs: PropTypes.func.isRequired,
    resolveAsTheirs: PropTypes.func.isRequired,
    undoLastDiscard: PropTypes.func.isRequired,
    attemptStageAllOperation: PropTypes.func.isRequired,
    attemptFileStageOperation: PropTypes.func.isRequired,
    discardWorkDirChangesForPaths: PropTypes.func.isRequired,
    openFiles: PropTypes.func.isRequired,
    contextLocked: PropTypes.bool.isRequired,
    changeWorkingDirectory: PropTypes.func.isRequired,
    setContextLock: PropTypes.func.isRequired,
    onDidChangeWorkDirs: PropTypes.func.isRequired,
    getCurrentWorkDirs: PropTypes.func.isRequired,
  };

  constructor(props, context) {
    super(props, context);
    autobind(this, 'initializeRepo', 'blur', 'advanceFocus', 'retreatFocus', 'quietlySelectItem');

    this.subscriptions = new CompositeDisposable();

    this.refCommitController = new RefHolder();
    this.refRecentCommitsController = new RefHolder();
  }

  componentDidMount() {
    this.props.refRoot.map(root => {
      return this.subscriptions.add(
        this.props.commands.add(root, {
          'tool-panel:unfocus': this.blur,
          'core:focus-next': this.advanceFocus,
          'core:focus-previous': this.retreatFocus,
        }),
      );
    });
  }

  render() {
    let renderMethod = 'renderNormal';
    let isEmpty = false;
    let isLoading = false;
    if (this.props.repository.isTooLarge()) {
      renderMethod = 'renderTooLarge';
      isEmpty = true;
    } else if (this.props.repository.hasDirectory() &&
      !isValidWorkdir(this.props.repository.getWorkingDirectoryPath())) {
      renderMethod = 'renderUnsupportedDir';
      isEmpty = true;
    } else if (this.props.repository.showGitTabInit()) {
      renderMethod = 'renderNoRepo';
      isEmpty = true;
    } else if (this.props.isLoading || this.props.repository.showGitTabLoading()) {
      isLoading = true;
    }

    return (
      <div
        className={cx('github-Git', {'is-empty': isEmpty, 'is-loading': !isEmpty && isLoading})}
        tabIndex="-1"
        ref={this.props.refRoot.setter}>
        {this.renderHeader()}
        {this[renderMethod]()}
      </div>
    );
  }

  renderHeader() {
    const {repository} = this.props;
    return (
      <GitTabHeaderController
        getCommitter={repository.getCommitter.bind(repository)}

        // Workspace
        currentWorkDir={this.props.workingDirectoryPath}
        getCurrentWorkDirs={this.props.getCurrentWorkDirs}
        contextLocked={this.props.contextLocked}
        changeWorkingDirectory={this.props.changeWorkingDirectory}
        setContextLock={this.props.setContextLock}

        // Event Handlers
        onDidChangeWorkDirs={this.props.onDidChangeWorkDirs}
        onDidUpdateRepo={repository.onDidUpdate.bind(repository)}
      />
    );
  }

  renderNormal() {
    return (
      <Fragment>
        <StagingView
          ref={this.props.refStagingView.setter}
          commands={this.props.commands}
          notificationManager={this.props.notificationManager}
          workspace={this.props.workspace}
          stagedChanges={this.props.stagedChanges}
          unstagedChanges={this.props.unstagedChanges}
          mergeConflicts={this.props.mergeConflicts}
          workingDirectoryPath={this.props.workingDirectoryPath}
          resolutionProgress={this.props.resolutionProgress}
          openFiles={this.props.openFiles}
          discardWorkDirChangesForPaths={this.props.discardWorkDirChangesForPaths}
          attemptFileStageOperation={this.props.attemptFileStageOperation}
          attemptStageAllOperation={this.props.attemptStageAllOperation}
          undoLastDiscard={this.props.undoLastDiscard}
          abortMerge={this.props.abortMerge}
          resolveAsOurs={this.props.resolveAsOurs}
          resolveAsTheirs={this.props.resolveAsTheirs}
          lastCommit={this.props.lastCommit}
          isLoading={this.props.isLoading}
          hasUndoHistory={this.props.hasUndoHistory}
          isMerging={this.props.isMerging}
        />
        <CommitController
          ref={this.refCommitController.setter}
          tooltips={this.props.tooltips}
          config={this.props.config}
          stagedChangesExist={this.props.stagedChanges.length > 0}
          mergeConflictsExist={this.props.mergeConflicts.length > 0}
          prepareToCommit={this.props.prepareToCommit}
          commit={this.props.commit}
          abortMerge={this.props.abortMerge}
          currentBranch={this.props.currentBranch}
          workspace={this.props.workspace}
          commands={this.props.commands}
          notificationManager={this.props.notificationManager}
          grammars={this.props.grammars}
          mergeMessage={this.props.mergeMessage}
          isMerging={this.props.isMerging}
          isLoading={this.props.isLoading}
          lastCommit={this.props.lastCommit}
          repository={this.props.repository}
          userStore={this.props.userStore}
          selectedCoAuthors={this.props.selectedCoAuthors}
          updateSelectedCoAuthors={this.props.updateSelectedCoAuthors}
        />
        <RecentCommitsController
          ref={this.refRecentCommitsController.setter}
          commands={this.props.commands}
          commits={this.props.recentCommits}
          isLoading={this.props.isLoading}
          undoLastCommit={this.props.undoLastCommit}
          workspace={this.props.workspace}
          repository={this.props.repository}
        />
      </Fragment>
    );
  }

  renderTooLarge() {
    return (
      <div className="github-Git too-many-changes">
        <div className="github-Git-LargeIcon icon icon-diff" />
        <h1>Too many changes</h1>
        <div className="initialize-repo-description">
          The repository at <strong>{this.props.workingDirectoryPath}</strong> has too many changed files
          to display in Atom. Ensure that you have set up an appropriate <code>.gitignore</code> file.
        </div>
      </div>
    );
  }

  renderUnsupportedDir() {
    return (
      <div className="github-Git unsupported-directory">
        <div className="github-Git-LargeIcon icon icon-alert" />
        <h1>Unsupported directory</h1>
        <div className="initialize-repo-description">
          Atom does not support managing Git repositories in your home or root directories.
        </div>
      </div>
    );
  }

  renderNoRepo() {
    return (
      <div className="github-Git no-repository">
        <div className="github-Git-LargeIcon icon icon-repo" />
        <h1>Create Repository</h1>
        <div className="initialize-repo-description">
          {
            this.props.repository.hasDirectory()
              ?
              (
                <span>Initialize <strong>{this.props.workingDirectoryPath}</strong> with a
                Git repository</span>
              )
              : <span>Initialize a new project directory with a Git repository</span>
          }
        </div>
        <button
          onClick={this.initializeRepo}
          disabled={this.props.repository.showGitTabInitInProgress()}
          className="btn btn-primary">
          {this.props.repository.showGitTabInitInProgress()
            ? 'Creating repository...' : 'Create repository'}
        </button>
      </div>
    );
  }

  componentWillUnmount() {
    this.subscriptions.dispose();
  }

  initializeRepo(event) {
    event.preventDefault();

    const workdir = this.props.repository.isAbsent() ? null : this.props.repository.getWorkingDirectoryPath();
    return this.props.openInitializeDialog(workdir);
  }

  getFocus(element) {
    for (const ref of [this.props.refStagingView, this.refCommitController, this.refRecentCommitsController]) {
      const focus = ref.map(sub => sub.getFocus(element)).getOr(null);
      if (focus !== null) {
        return focus;
      }
    }
    return null;
  }

  setFocus(focus) {
    for (const ref of [this.props.refStagingView, this.refCommitController, this.refRecentCommitsController]) {
      if (ref.map(sub => sub.setFocus(focus)).getOr(false)) {
        return true;
      }
    }
    return false;
  }

  blur() {
    this.props.workspace.getCenter().activate();
  }

  async advanceFocus(evt) {
    const currentFocus = this.getFocus(document.activeElement);
    let nextSeen = false;

    for (const subHolder of [this.props.refStagingView, this.refCommitController, this.refRecentCommitsController]) {
      const next = await subHolder.map(sub => sub.advanceFocusFrom(currentFocus)).getOr(null);
      if (next !== null && !nextSeen) {
        nextSeen = true;
        evt.stopPropagation();
        if (next !== currentFocus) {
          this.setFocus(next);
        }
      }
    }
  }

  async retreatFocus(evt) {
    const currentFocus = this.getFocus(document.activeElement);
    let previousSeen = false;

    for (const subHolder of [this.refRecentCommitsController, this.refCommitController, this.props.refStagingView]) {
      const previous = await subHolder.map(sub => sub.retreatFocusFrom(currentFocus)).getOr(null);
      if (previous !== null && !previousSeen) {
        previousSeen = true;
        evt.stopPropagation();
        if (previous !== currentFocus) {
          this.setFocus(previous);
        }
      }
    }
  }

  async focusAndSelectStagingItem(filePath, stagingStatus) {
    await this.quietlySelectItem(filePath, stagingStatus);
    this.setFocus(GitTabView.focus.STAGING);
  }

  focusAndSelectRecentCommit() {
    this.setFocus(RecentCommitsController.focus.RECENT_COMMIT);
  }

  focusAndSelectCommitPreviewButton() {
    this.setFocus(GitTabView.focus.COMMIT_PREVIEW_BUTTON);
  }

  quietlySelectItem(filePath, stagingStatus) {
    return this.props.refStagingView.map(view => view.quietlySelectItem(filePath, stagingStatus)).getOr(false);
  }

  hasFocus() {
    return this.props.refRoot.map(root => root.contains(document.activeElement)).getOr(false);
  }
}
