import React from 'react';
import PropTypes from 'prop-types';
import path from 'path';

import {autobind, equalSets} from '../helpers';
import {addEvent} from '../reporter-proxy';
import {MultiFilePatchPropType} from '../prop-types';
import ChangedFileItem from '../items/changed-file-item';
import MultiFilePatchView from '../views/multi-file-patch-view';

export default class MultiFilePatchController extends React.Component {
  static propTypes = {
    repository: PropTypes.object.isRequired,
    stagingStatus: PropTypes.oneOf(['staged', 'unstaged']),
    multiFilePatch: MultiFilePatchPropType.isRequired,
    hasUndoHistory: PropTypes.bool,

    reviewCommentsLoading: PropTypes.bool,
    reviewCommentThreads: PropTypes.arrayOf(PropTypes.shape({
      thread: PropTypes.object.isRequired,
      comments: PropTypes.arrayOf(PropTypes.object).isRequired,
    })),

    workspace: PropTypes.object.isRequired,
    commands: PropTypes.object.isRequired,
    keymaps: PropTypes.object.isRequired,
    tooltips: PropTypes.object.isRequired,
    config: PropTypes.object.isRequired,

    destroy: PropTypes.func.isRequired,
    discardLines: PropTypes.func,
    undoLastDiscard: PropTypes.func,
    surface: PropTypes.func,
    switchToIssueish: PropTypes.func,
  }

  constructor(props) {
    super(props);
    autobind(
      this,
      'selectedRowsChanged',
      'undoLastDiscard', 'diveIntoMirrorPatch', 'openFile',
      'toggleFile', 'toggleRows', 'toggleModeChange', 'toggleSymlinkChange', 'discardRows',
    );

    this.state = {
      selectionMode: 'hunk',
      selectedRows: new Set(),
      hasMultipleFileSelections: false,
    };

    this.mouseSelectionInProgress = false;
    this.stagingOperationInProgress = false;

    this.lastPatchString = null;
    this.patchChangePromise = new Promise(resolve => {
      this.resolvePatchChangePromise = resolve;
    });
  }

  componentDidUpdate(prevProps) {
    if (
      this.lastPatchString !== null &&
      this.lastPatchString !== this.props.multiFilePatch.toString()
    ) {
      this.resolvePatchChangePromise();
      this.patchChangePromise = new Promise(resolve => {
        this.resolvePatchChangePromise = resolve;
      });
    }
  }

  render() {
    return (
      <MultiFilePatchView
        {...this.props}

        selectedRows={this.state.selectedRows}
        selectionMode={this.state.selectionMode}
        hasMultipleFileSelections={this.state.hasMultipleFileSelections}
        selectedRowsChanged={this.selectedRowsChanged}

        diveIntoMirrorPatch={this.diveIntoMirrorPatch}
        openFile={this.openFile}
        toggleFile={this.toggleFile}
        toggleRows={this.toggleRows}
        toggleModeChange={this.toggleModeChange}
        toggleSymlinkChange={this.toggleSymlinkChange}
        undoLastDiscard={this.undoLastDiscard}
        discardRows={this.discardRows}
        selectNextHunk={this.selectNextHunk}
        selectPreviousHunk={this.selectPreviousHunk}
        switchToIssueish={this.props.switchToIssueish}
      />
    );
  }

  undoLastDiscard(filePatch, {eventSource} = {}) {
    addEvent('undo-last-discard', {
      package: 'github',
      component: this.constructor.name,
      eventSource,
    });

    return this.props.undoLastDiscard(filePatch.getPath(), this.props.repository);
  }

  diveIntoMirrorPatch(filePatch) {
    const mirrorStatus = this.withStagingStatus({staged: 'unstaged', unstaged: 'staged'});
    const workingDirectory = this.props.repository.getWorkingDirectoryPath();
    const uri = ChangedFileItem.buildURI(filePatch.getPath(), workingDirectory, mirrorStatus);

    this.props.destroy();
    return this.props.workspace.open(uri);
  }

  async openFile(filePatch, positions, pending) {
    const absolutePath = path.join(this.props.repository.getWorkingDirectoryPath(), filePatch.getPath());
    const editor = await this.props.workspace.open(absolutePath, {pending});
    if (positions.length > 0) {
      editor.setCursorBufferPosition(positions[0], {autoscroll: false});
      for (const position of positions.slice(1)) {
        editor.addCursorAtBufferPosition(position);
      }
      editor.scrollToBufferPosition(positions[positions.length - 1], {center: true});
    }
    return editor;
  }

  toggleFile(filePatch) {
    return this.stagingOperation(() => {
      const methodName = this.withStagingStatus({staged: 'unstageFiles', unstaged: 'stageFiles'});
      return this.props.repository[methodName]([filePatch.getPath()]);
    });
  }

  async toggleRows(rowSet, nextSelectionMode) {
    let chosenRows = rowSet;
    if (chosenRows) {
      const nextMultipleFileSelections = this.props.multiFilePatch.spansMultipleFiles(chosenRows);
      await this.selectedRowsChanged(chosenRows, nextSelectionMode, nextMultipleFileSelections);
    } else {
      chosenRows = this.state.selectedRows;
    }

    if (chosenRows.size === 0) {
      return Promise.resolve();
    }

    return this.stagingOperation(() => {
      const patch = this.withStagingStatus({
        staged: () => this.props.multiFilePatch.getUnstagePatchForLines(chosenRows),
        unstaged: () => this.props.multiFilePatch.getStagePatchForLines(chosenRows),
      });
      return this.props.repository.applyPatchToIndex(patch);
    });
  }

  toggleModeChange(filePatch) {
    return this.stagingOperation(() => {
      const targetMode = this.withStagingStatus({
        unstaged: filePatch.getNewMode(),
        staged: filePatch.getOldMode(),
      });
      return this.props.repository.stageFileModeChange(filePatch.getPath(), targetMode);
    });
  }

  toggleSymlinkChange(filePatch) {
    return this.stagingOperation(() => {
      const relPath = filePatch.getPath();
      const repository = this.props.repository;
      return this.withStagingStatus({
        unstaged: () => {
          if (filePatch.hasTypechange() && filePatch.getStatus() === 'added') {
            return repository.stageFileSymlinkChange(relPath);
          }

          return repository.stageFiles([relPath]);
        },
        staged: () => {
          if (filePatch.hasTypechange() && filePatch.getStatus() === 'deleted') {
            return repository.stageFileSymlinkChange(relPath);
          }

          return repository.unstageFiles([relPath]);
        },
      });
    });
  }

  async discardRows(rowSet, nextSelectionMode, {eventSource} = {}) {
    // (kuychaco) For now we only support discarding rows for MultiFilePatches that contain a single file patch
    // The only way to access this method from the UI is to be in a ChangedFileItem, which only has a single file patch
    // This check is duplicated in RootController#discardLines. We also want it here to prevent us from sending metrics
    // unnecessarily
    if (this.props.multiFilePatch.getFilePatches().length !== 1) {
      return Promise.resolve(null);
    }

    let chosenRows = rowSet;
    if (chosenRows) {
      const nextMultipleFileSelections = this.props.multiFilePatch.spansMultipleFiles(chosenRows);
      await this.selectedRowsChanged(chosenRows, nextSelectionMode, nextMultipleFileSelections);
    } else {
      chosenRows = this.state.selectedRows;
    }

    addEvent('discard-unstaged-changes', {
      package: 'github',
      component: this.constructor.name,
      lineCount: chosenRows.size,
      eventSource,
    });

    return this.props.discardLines(this.props.multiFilePatch, chosenRows, this.props.repository);
  }

  selectedRowsChanged(rows, nextSelectionMode, nextMultipleFileSelections) {
    if (
      equalSets(this.state.selectedRows, rows) &&
      this.state.selectionMode === nextSelectionMode &&
      this.state.hasMultipleFileSelections === nextMultipleFileSelections
    ) {
      return Promise.resolve();
    }

    return new Promise(resolve => {
      this.setState({
        selectedRows: rows,
        selectionMode: nextSelectionMode,
        hasMultipleFileSelections: nextMultipleFileSelections,
      }, resolve);
    });
  }

  withStagingStatus(callbacks) {
    const callback = callbacks[this.props.stagingStatus];
    /* istanbul ignore if */
    if (!callback) {
      throw new Error(`Unknown staging status: ${this.props.stagingStatus}`);
    }
    return callback instanceof Function ? callback() : callback;
  }

  stagingOperation(fn) {
    if (this.stagingOperationInProgress) {
      return null;
    }

    this.stagingOperationInProgress = true;
    this.lastPatchString = this.props.multiFilePatch.toString();
    const operationPromise = fn();

    operationPromise
      .then(() => this.patchChangePromise)
      .then(() => {
        this.stagingOperationInProgress = false;
        this.lastPatchString = null;
      });

    return operationPromise;
  }
}
