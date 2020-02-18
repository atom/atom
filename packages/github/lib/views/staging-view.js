import {Disposable, CompositeDisposable} from 'event-kit';
import {remote} from 'electron';
const {Menu, MenuItem} = remote;
import {File} from 'atom';
import React, {Fragment} from 'react';
import PropTypes from 'prop-types';
import path from 'path';

import {FilePatchItemPropType, MergeConflictItemPropType} from '../prop-types';
import FilePatchListItemView from './file-patch-list-item-view';
import ObserveModel from './observe-model';
import MergeConflictListItemView from './merge-conflict-list-item-view';
import CompositeListSelection from '../models/composite-list-selection';
import ResolutionProgress from '../models/conflicts/resolution-progress';
import CommitView from './commit-view';
import RefHolder from '../models/ref-holder';
import ChangedFileItem from '../items/changed-file-item';
import Commands, {Command} from '../atom/commands';
import {autobind} from '../helpers';
import {addEvent} from '../reporter-proxy';

const debounce = (fn, wait) => {
  let timeout;
  return (...args) => {
    return new Promise(resolve => {
      clearTimeout(timeout);
      timeout = setTimeout(() => {
        resolve(fn(...args));
      }, wait);
    });
  };
};

function calculateTruncatedLists(lists) {
  return Object.keys(lists).reduce((acc, key) => {
    const list = lists[key];
    acc.source[key] = list;
    if (list.length <= MAXIMUM_LISTED_ENTRIES) {
      acc[key] = list;
    } else {
      acc[key] = list.slice(0, MAXIMUM_LISTED_ENTRIES);
    }
    return acc;
  }, {source: {}});
}

const noop = () => { };

const MAXIMUM_LISTED_ENTRIES = 1000;

export default class StagingView extends React.Component {
  static propTypes = {
    unstagedChanges: PropTypes.arrayOf(FilePatchItemPropType).isRequired,
    stagedChanges: PropTypes.arrayOf(FilePatchItemPropType).isRequired,
    mergeConflicts: PropTypes.arrayOf(MergeConflictItemPropType),
    workingDirectoryPath: PropTypes.string,
    resolutionProgress: PropTypes.object,
    hasUndoHistory: PropTypes.bool.isRequired,
    commands: PropTypes.object.isRequired,
    notificationManager: PropTypes.object.isRequired,
    workspace: PropTypes.object.isRequired,
    openFiles: PropTypes.func.isRequired,
    attemptFileStageOperation: PropTypes.func.isRequired,
    discardWorkDirChangesForPaths: PropTypes.func.isRequired,
    undoLastDiscard: PropTypes.func.isRequired,
    attemptStageAllOperation: PropTypes.func.isRequired,
    resolveAsOurs: PropTypes.func.isRequired,
    resolveAsTheirs: PropTypes.func.isRequired,
  }

  static defaultProps = {
    mergeConflicts: [],
    resolutionProgress: new ResolutionProgress(),
  }

  static focus = {
    STAGING: Symbol('staging'),
  };

  static firstFocus = StagingView.focus.STAGING;

  static lastFocus = StagingView.focus.STAGING;

  constructor(props) {
    super(props);
    autobind(
      this,
      'dblclickOnItem', 'contextMenuOnItem', 'mousedownOnItem', 'mousemoveOnItem', 'mouseup', 'registerItemElement',
      'renderBody', 'openFile', 'discardChanges', 'activateNextList', 'activatePreviousList', 'activateLastList',
      'stageAll', 'unstageAll', 'stageAllMergeConflicts', 'discardAll', 'confirmSelectedItems', 'selectAll',
      'selectFirst', 'selectLast', 'diveIntoSelection', 'showDiffView', 'showBulkResolveMenu', 'showActionsMenu',
      'resolveCurrentAsOurs', 'resolveCurrentAsTheirs', 'quietlySelectItem', 'didChangeSelectedItems',
    );

    this.subs = new CompositeDisposable(
      atom.config.observe('github.keyboardNavigationDelay', value => {
        if (value === 0) {
          this.debouncedDidChangeSelectedItem = this.didChangeSelectedItems;
        } else {
          this.debouncedDidChangeSelectedItem = debounce(this.didChangeSelectedItems, value);
        }
      }),
    );

    this.state = {
      ...calculateTruncatedLists({
        unstagedChanges: this.props.unstagedChanges,
        stagedChanges: this.props.stagedChanges,
        mergeConflicts: this.props.mergeConflicts,
      }),
      selection: new CompositeListSelection({
        listsByKey: [
          ['unstaged', this.props.unstagedChanges],
          ['conflicts', this.props.mergeConflicts],
          ['staged', this.props.stagedChanges],
        ],
        idForItem: item => item.filePath,
      }),
    };

    this.mouseSelectionInProgress = false;
    this.listElementsByItem = new WeakMap();
    this.refRoot = new RefHolder();
  }

  static getDerivedStateFromProps(nextProps, prevState) {
    let nextState = {};

    if (
      ['unstagedChanges', 'stagedChanges', 'mergeConflicts'].some(key => prevState.source[key] !== nextProps[key])
    ) {
      const nextLists = calculateTruncatedLists({
        unstagedChanges: nextProps.unstagedChanges,
        stagedChanges: nextProps.stagedChanges,
        mergeConflicts: nextProps.mergeConflicts,
      });

      nextState = {
        ...nextLists,
        selection: prevState.selection.updateLists([
          ['unstaged', nextLists.unstagedChanges],
          ['conflicts', nextLists.mergeConflicts],
          ['staged', nextLists.stagedChanges],
        ]),
      };
    }

    return nextState;
  }

  componentDidMount() {
    window.addEventListener('mouseup', this.mouseup);
    this.subs.add(
      new Disposable(() => window.removeEventListener('mouseup', this.mouseup)),
      this.props.workspace.onDidChangeActivePaneItem(() => {
        this.syncWithWorkspace();
      }),
    );

    if (this.isPopulated(this.props)) {
      this.syncWithWorkspace();
    }
  }

  componentDidUpdate(prevProps, prevState) {
    const isRepoSame = prevProps.workingDirectoryPath === this.props.workingDirectoryPath;
    const hasSelectionsPresent =
      prevState.selection.getSelectedItems().size > 0 &&
      this.state.selection.getSelectedItems().size > 0;
    const selectionChanged = this.state.selection !== prevState.selection;

    if (isRepoSame && hasSelectionsPresent && selectionChanged) {
      this.debouncedDidChangeSelectedItem();
    }

    const headItem = this.state.selection.getHeadItem();
    if (headItem) {
      const element = this.listElementsByItem.get(headItem);
      if (element) {
        element.scrollIntoViewIfNeeded();
      }
    }

    if (!this.isPopulated(prevProps) && this.isPopulated(this.props)) {
      this.syncWithWorkspace();
    }
  }

  render() {
    return (
      <ObserveModel model={this.props.resolutionProgress} fetchData={noop}>
        {this.renderBody}
      </ObserveModel>
    );
  }

  renderBody() {
    const selectedItems = this.state.selection.getSelectedItems();

    return (
      <div
        ref={this.refRoot.setter}
        className={`github-StagingView ${this.state.selection.getActiveListKey()}-changes-focused`}
        tabIndex="-1">
        {this.renderCommands()}
        <div className={`github-StagingView-group github-UnstagedChanges ${this.getFocusClass('unstaged')}`}>
          <header className="github-StagingView-header">
            <span className="icon icon-list-unordered" />
            <span className="github-StagingView-title">Unstaged Changes</span>
            {this.renderActionsMenu()}
            <button
              className="github-StagingView-headerButton icon icon-move-down"
              disabled={this.props.unstagedChanges.length === 0}
              onClick={this.stageAll}>Stage All</button>
          </header>
          <div className="github-StagingView-list github-FilePatchListView github-StagingView-unstaged">
            {
              this.state.unstagedChanges.map(filePatch => (
                <FilePatchListItemView
                  key={filePatch.filePath}
                  registerItemElement={this.registerItemElement}
                  filePatch={filePatch}
                  onDoubleClick={event => this.dblclickOnItem(event, filePatch)}
                  onContextMenu={event => this.contextMenuOnItem(event, filePatch)}
                  onMouseDown={event => this.mousedownOnItem(event, filePatch)}
                  onMouseMove={event => this.mousemoveOnItem(event, filePatch)}
                  selected={selectedItems.has(filePatch)}
                />
              ))
            }
          </div>
          {this.renderTruncatedMessage(this.props.unstagedChanges)}
        </div>
        {this.renderMergeConflicts()}
        <div className={`github-StagingView-group github-StagedChanges ${this.getFocusClass('staged')}`} >
          <header className="github-StagingView-header">
            <span className="icon icon-tasklist" />
            <span className="github-StagingView-title">
              Staged Changes
            </span>
            <button className="github-StagingView-headerButton icon icon-move-up"
              disabled={this.props.stagedChanges.length === 0}
              onClick={this.unstageAll}>Unstage All</button>
          </header>
          <div className="github-StagingView-list github-FilePatchListView github-StagingView-staged">
            {
              this.state.stagedChanges.map(filePatch => (
                <FilePatchListItemView
                  key={filePatch.filePath}
                  filePatch={filePatch}
                  registerItemElement={this.registerItemElement}
                  onDoubleClick={event => this.dblclickOnItem(event, filePatch)}
                  onContextMenu={event => this.contextMenuOnItem(event, filePatch)}
                  onMouseDown={event => this.mousedownOnItem(event, filePatch)}
                  onMouseMove={event => this.mousemoveOnItem(event, filePatch)}
                  selected={selectedItems.has(filePatch)}
                />
              ))
            }
          </div>
          {this.renderTruncatedMessage(this.props.stagedChanges)}
        </div>
      </div>
    );
  }

  renderCommands() {
    return (
      <Fragment>
        <Commands registry={this.props.commands} target=".github-StagingView">
          <Command command="core:move-up" callback={() => this.selectPrevious()} />
          <Command command="core:move-down" callback={() => this.selectNext()} />
          <Command command="core:move-left" callback={this.diveIntoSelection} />
          <Command command="github:show-diff-view" callback={this.showDiffView} />
          <Command command="core:select-up" callback={() => this.selectPrevious(true)} />
          <Command command="core:select-down" callback={() => this.selectNext(true)} />
          <Command command="core:select-all" callback={this.selectAll} />
          <Command command="core:move-to-top" callback={this.selectFirst} />
          <Command command="core:move-to-bottom" callback={this.selectLast} />
          <Command command="core:select-to-top" callback={() => this.selectFirst(true)} />
          <Command command="core:select-to-bottom" callback={() => this.selectLast(true)} />
          <Command command="core:confirm" callback={this.confirmSelectedItems} />
          <Command command="github:activate-next-list" callback={this.activateNextList} />
          <Command command="github:activate-previous-list" callback={this.activatePreviousList} />
          <Command command="github:jump-to-file" callback={this.openFile} />
          <Command command="github:resolve-file-as-ours" callback={this.resolveCurrentAsOurs} />
          <Command command="github:resolve-file-as-theirs" callback={this.resolveCurrentAsTheirs} />
          <Command command="github:discard-changes-in-selected-files" callback={this.discardChangesFromCommand} />
          <Command command="core:undo" callback={this.undoLastDiscardFromCoreUndo} />
        </Commands>
        <Commands registry={this.props.commands} target="atom-workspace">
          <Command command="github:stage-all-changes" callback={this.stageAll} />
          <Command command="github:unstage-all-changes" callback={this.unstageAll} />
          <Command command="github:discard-all-changes" callback={this.discardAllFromCommand} />
          <Command command="github:undo-last-discard-in-git-tab"
            callback={this.undoLastDiscardFromCommand}
          />
        </Commands>
      </Fragment>
    );
  }

  undoLastDiscardFromCoreUndo = () => {
    this.undoLastDiscard({eventSource: {command: 'core:undo'}});
  }

  undoLastDiscardFromCommand = () => {
    this.undoLastDiscard({eventSource: {command: 'github:undo-last-discard-in-git-tab'}});
  }

  undoLastDiscardFromButton = () => {
    this.undoLastDiscard({eventSource: 'button'});
  }

  undoLastDiscardFromHeaderMenu = () => {
    this.undoLastDiscard({eventSource: 'header-menu'});
  }

  discardChangesFromCommand = () => {
    this.discardChanges({eventSource: {command: 'github:discard-changes-in-selected-files'}});
  }

  discardAllFromCommand = () => {
    this.discardAll({eventSource: {command: 'github:discard-all-changes'}});
  }

  renderActionsMenu() {
    if (this.props.unstagedChanges.length || this.props.hasUndoHistory) {
      return (
        <button
          className="github-StagingView-headerButton github-StagingView-headerButton--iconOnly icon icon-ellipses"
          onClick={this.showActionsMenu}
        />
      );
    } else {
      return null;
    }
  }

  renderUndoButton() {
    return (
      <button className="github-StagingView-headerButton github-StagingView-headerButton--fullWidth icon icon-history"
        onClick={this.undoLastDiscardFromButton}>Undo Discard</button>
    );
  }

  renderTruncatedMessage(list) {
    if (list.length > MAXIMUM_LISTED_ENTRIES) {
      return (
        <div className="github-StagingView-group-truncatedMsg">
          List truncated to the first {MAXIMUM_LISTED_ENTRIES} items
        </div>
      );
    } else {
      return null;
    }
  }

  renderMergeConflicts() {
    const mergeConflicts = this.state.mergeConflicts;

    if (mergeConflicts && mergeConflicts.length > 0) {
      const selectedItems = this.state.selection.getSelectedItems();
      const resolutionProgress = this.props.resolutionProgress;
      const anyUnresolved = mergeConflicts
        .map(conflict => path.join(this.props.workingDirectoryPath, conflict.filePath))
        .some(conflictPath => resolutionProgress.getRemaining(conflictPath) !== 0);

      const bulkResolveDropdown = anyUnresolved ? (
        <span
          className="inline-block icon icon-ellipses"
          onClick={this.showBulkResolveMenu}
        />
      ) : null;

      return (
        <div className={`github-StagingView-group github-MergeConflictPaths ${this.getFocusClass('conflicts')}`}>
          <header className="github-StagingView-header">
            <span className={'github-FilePatchListView-icon icon icon-alert status-modified'} />
            <span className="github-StagingView-title">Merge Conflicts</span>
            {bulkResolveDropdown}
            <button
              className="github-StagingView-headerButton icon icon-move-down"
              disabled={anyUnresolved}
              onClick={this.stageAllMergeConflicts}>
              Stage All
            </button>
          </header>
          <div className="github-StagingView-list github-FilePatchListView github-StagingView-merge">
            {
              mergeConflicts.map(mergeConflict => {
                const fullPath = path.join(this.props.workingDirectoryPath, mergeConflict.filePath);

                return (
                  <MergeConflictListItemView
                    key={fullPath}
                    mergeConflict={mergeConflict}
                    remainingConflicts={resolutionProgress.getRemaining(fullPath)}
                    registerItemElement={this.registerItemElement}
                    onDoubleClick={event => this.dblclickOnItem(event, mergeConflict)}
                    onContextMenu={event => this.contextMenuOnItem(event, mergeConflict)}
                    onMouseDown={event => this.mousedownOnItem(event, mergeConflict)}
                    onMouseMove={event => this.mousemoveOnItem(event, mergeConflict)}
                    selected={selectedItems.has(mergeConflict)}
                  />
                );
              })
            }
          </div>
          {this.renderTruncatedMessage(mergeConflicts)}
        </div>
      );
    } else {
      return <noscript />;
    }
  }

  componentWillUnmount() {
    this.subs.dispose();
  }

  getSelectedItemFilePaths() {
    return Array.from(this.state.selection.getSelectedItems(), item => item.filePath);
  }

  getSelectedConflictPaths() {
    if (this.state.selection.getActiveListKey() !== 'conflicts') {
      return [];
    }
    return this.getSelectedItemFilePaths();
  }

  openFile() {
    const filePaths = this.getSelectedItemFilePaths();
    return this.props.openFiles(filePaths);
  }

  discardChanges({eventSource} = {}) {
    const filePaths = this.getSelectedItemFilePaths();
    addEvent('discard-unstaged-changes', {
      package: 'github',
      component: 'StagingView',
      fileCount: filePaths.length,
      type: 'selected',
      eventSource,
    });
    return this.props.discardWorkDirChangesForPaths(filePaths);
  }

  activateNextList() {
    return new Promise(resolve => {
      let advanced = false;

      this.setState(prevState => {
        const next = prevState.selection.activateNextSelection();
        if (prevState.selection === next) {
          return {};
        }

        advanced = true;
        return {selection: next.coalesce()};
      }, () => resolve(advanced));
    });
  }

  activatePreviousList() {
    return new Promise(resolve => {
      let retreated = false;
      this.setState(prevState => {
        const next = prevState.selection.activatePreviousSelection();
        if (prevState.selection === next) {
          return {};
        }

        retreated = true;
        return {selection: next.coalesce()};
      }, () => resolve(retreated));
    });
  }

  activateLastList() {
    return new Promise(resolve => {
      let emptySelection = false;
      this.setState(prevState => {
        const next = prevState.selection.activateLastSelection();
        emptySelection = next.getSelectedItems().size > 0;

        if (prevState.selection === next) {
          return {};
        }

        return {selection: next.coalesce()};
      }, () => resolve(emptySelection));
    });
  }

  stageAll() {
    if (this.props.unstagedChanges.length === 0) { return null; }
    return this.props.attemptStageAllOperation('unstaged');
  }

  unstageAll() {
    if (this.props.stagedChanges.length === 0) { return null; }
    return this.props.attemptStageAllOperation('staged');
  }

  stageAllMergeConflicts() {
    if (this.props.mergeConflicts.length === 0) { return null; }
    const filePaths = this.props.mergeConflicts.map(conflict => conflict.filePath);
    return this.props.attemptFileStageOperation(filePaths, 'unstaged');
  }

  discardAll({eventSource} = {}) {
    if (this.props.unstagedChanges.length === 0) { return null; }
    const filePaths = this.props.unstagedChanges.map(filePatch => filePatch.filePath);
    addEvent('discard-unstaged-changes', {
      package: 'github',
      component: 'StagingView',
      fileCount: filePaths.length,
      type: 'all',
      eventSource,
    });
    return this.props.discardWorkDirChangesForPaths(filePaths);
  }

  confirmSelectedItems = async () => {
    const itemPaths = this.getSelectedItemFilePaths();
    await this.props.attemptFileStageOperation(itemPaths, this.state.selection.getActiveListKey());
    await new Promise(resolve => {
      this.setState(prevState => ({selection: prevState.selection.coalesce()}), resolve);
    });
  }

  getNextListUpdatePromise() {
    return this.state.selection.getNextUpdatePromise();
  }

  selectPrevious(preserveTail = false) {
    return new Promise(resolve => {
      this.setState(prevState => ({
        selection: prevState.selection.selectPreviousItem(preserveTail).coalesce(),
      }), resolve);
    });
  }

  selectNext(preserveTail = false) {
    return new Promise(resolve => {
      this.setState(prevState => ({
        selection: prevState.selection.selectNextItem(preserveTail).coalesce(),
      }), resolve);
    });
  }

  selectAll() {
    return new Promise(resolve => {
      this.setState(prevState => ({
        selection: prevState.selection.selectAllItems().coalesce(),
      }), resolve);
    });
  }

  selectFirst(preserveTail = false) {
    return new Promise(resolve => {
      this.setState(prevState => ({
        selection: prevState.selection.selectFirstItem(preserveTail).coalesce(),
      }), resolve);
    });
  }

  selectLast(preserveTail = false) {
    return new Promise(resolve => {
      this.setState(prevState => ({
        selection: prevState.selection.selectLastItem(preserveTail).coalesce(),
      }), resolve);
    });
  }

  async diveIntoSelection() {
    const selectedItems = this.state.selection.getSelectedItems();
    if (selectedItems.size !== 1) {
      return;
    }

    const selectedItem = selectedItems.values().next().value;
    const stagingStatus = this.state.selection.getActiveListKey();

    if (stagingStatus === 'conflicts') {
      this.showMergeConflictFileForPath(selectedItem.filePath, {activate: true});
    } else {
      await this.showFilePatchItem(selectedItem.filePath, this.state.selection.getActiveListKey(), {activate: true});
    }
  }

  async syncWithWorkspace() {
    const item = this.props.workspace.getActivePaneItem();
    if (!item) {
      return;
    }

    const realItemPromise = item.getRealItemPromise && item.getRealItemPromise();
    const realItem = await realItemPromise;
    if (!realItem) {
      return;
    }

    const isFilePatchItem = realItem.isFilePatchItem && realItem.isFilePatchItem();
    const isMatch = realItem.getWorkingDirectory && realItem.getWorkingDirectory() === this.props.workingDirectoryPath;

    if (isFilePatchItem && isMatch) {
      this.quietlySelectItem(realItem.getFilePath(), realItem.getStagingStatus());
    }
  }

  async showDiffView() {
    const selectedItems = this.state.selection.getSelectedItems();
    if (selectedItems.size !== 1) {
      return;
    }

    const selectedItem = selectedItems.values().next().value;
    const stagingStatus = this.state.selection.getActiveListKey();

    if (stagingStatus === 'conflicts') {
      this.showMergeConflictFileForPath(selectedItem.filePath);
    } else {
      await this.showFilePatchItem(selectedItem.filePath, this.state.selection.getActiveListKey());
    }
  }

  showBulkResolveMenu(event) {
    const conflictPaths = this.props.mergeConflicts.map(c => c.filePath);

    event.preventDefault();

    const menu = new Menu();

    menu.append(new MenuItem({
      label: 'Resolve All as Ours',
      click: () => this.props.resolveAsOurs(conflictPaths),
    }));

    menu.append(new MenuItem({
      label: 'Resolve All as Theirs',
      click: () => this.props.resolveAsTheirs(conflictPaths),
    }));

    menu.popup(remote.getCurrentWindow());
  }

  showActionsMenu(event) {
    event.preventDefault();

    const menu = new Menu();

    const selectedItemCount = this.state.selection.getSelectedItems().size;
    const pluralization = selectedItemCount > 1 ? 's' : '';

    menu.append(new MenuItem({
      label: 'Discard All Changes',
      click: () => this.discardAll({eventSource: 'header-menu'}),
      enabled: this.props.unstagedChanges.length > 0,
    }));

    menu.append(new MenuItem({
      label: 'Discard Changes in Selected File' + pluralization,
      click: () => this.discardChanges({eventSource: 'header-menu'}),
      enabled: !!(this.props.unstagedChanges.length && selectedItemCount),
    }));

    menu.append(new MenuItem({
      label: 'Undo Last Discard',
      click: () => this.undoLastDiscard({eventSource: 'header-menu'}),
      enabled: this.props.hasUndoHistory,
    }));

    menu.popup(remote.getCurrentWindow());
  }

  resolveCurrentAsOurs() {
    this.props.resolveAsOurs(this.getSelectedConflictPaths());
  }

  resolveCurrentAsTheirs() {
    this.props.resolveAsTheirs(this.getSelectedConflictPaths());
  }

  // Directly modify the selection to include only the item identified by the file path and stagingStatus tuple.
  // Re-render the component, but don't notify didSelectSingleItem() or other callback functions. This is useful to
  // avoid circular callback loops for actions originating in FilePatchView or TextEditors with merge conflicts.
  quietlySelectItem(filePath, stagingStatus) {
    return new Promise(resolve => {
      this.setState(prevState => {
        const item = prevState.selection.findItem((each, key) => each.filePath === filePath && key === stagingStatus);
        if (!item) {
          // FIXME: make staging view display no selected item
          // eslint-disable-next-line no-console
          console.log(`Unable to find item at path ${filePath} with staging status ${stagingStatus}`);
          return null;
        }

        return {selection: prevState.selection.selectItem(item)};
      }, resolve);
    });
  }

  getSelectedItems() {
    const stagingStatus = this.state.selection.getActiveListKey();
    return Array.from(this.state.selection.getSelectedItems(), item => {
      return {
        filePath: item.filePath,
        stagingStatus,
      };
    });
  }

  didChangeSelectedItems(openNew) {
    const selectedItems = Array.from(this.state.selection.getSelectedItems());
    if (selectedItems.length === 1) {
      this.didSelectSingleItem(selectedItems[0], openNew);
    }
  }

  async didSelectSingleItem(selectedItem, openNew = false) {
    if (!this.hasFocus()) {
      return;
    }

    if (this.state.selection.getActiveListKey() === 'conflicts') {
      if (openNew) {
        await this.showMergeConflictFileForPath(selectedItem.filePath, {activate: true});
      }
    } else {
      if (openNew) {
        // User explicitly asked to view diff, such as via click
        await this.showFilePatchItem(selectedItem.filePath, this.state.selection.getActiveListKey(), {activate: false});
      } else {
        const panesWithStaleItemsToUpdate = this.getPanesWithStalePendingFilePatchItem();
        if (panesWithStaleItemsToUpdate.length > 0) {
          // Update stale items to reflect new selection
          await Promise.all(panesWithStaleItemsToUpdate.map(async pane => {
            await this.showFilePatchItem(selectedItem.filePath, this.state.selection.getActiveListKey(), {
              activate: false,
              pane,
            });
          }));
        } else {
          // Selection was changed via keyboard navigation, update pending item in active pane
          const activePane = this.props.workspace.getCenter().getActivePane();
          const activePendingItem = activePane.getPendingItem();
          const activePaneHasPendingFilePatchItem = activePendingItem && activePendingItem.getRealItem &&
            activePendingItem.getRealItem() instanceof ChangedFileItem;
          if (activePaneHasPendingFilePatchItem) {
            await this.showFilePatchItem(selectedItem.filePath, this.state.selection.getActiveListKey(), {
              activate: false,
              pane: activePane,
            });
          }
        }
      }
    }
  }

  getPanesWithStalePendingFilePatchItem() {
    // "stale" meaning there is no longer a changed file associated with item
    // due to changes being fully staged/unstaged/stashed/deleted/etc
    return this.props.workspace.getPanes().filter(pane => {
      const pendingItem = pane.getPendingItem();
      if (!pendingItem || !pendingItem.getRealItem) { return false; }
      const realItem = pendingItem.getRealItem();
      if (!(realItem instanceof ChangedFileItem)) {
        return false;
      }
      // We only want to update pending diff views for currently active repo
      const isInActiveRepo = realItem.getWorkingDirectory() === this.props.workingDirectoryPath;
      const isStale = !this.changedFileExists(realItem.getFilePath(), realItem.getStagingStatus());
      return isInActiveRepo && isStale;
    });
  }

  changedFileExists(filePath, stagingStatus) {
    return this.state.selection.findItem((item, key) => {
      return key === stagingStatus && item.filePath === filePath;
    });
  }

  async showFilePatchItem(filePath, stagingStatus, {activate, pane} = {activate: false}) {
    const uri = ChangedFileItem.buildURI(filePath, this.props.workingDirectoryPath, stagingStatus);
    const changedFileItem = await this.props.workspace.open(
      uri, {pending: true, activatePane: activate, activateItem: activate, pane},
    );
    if (activate) {
      const itemRoot = changedFileItem.getElement();
      const focusRoot = itemRoot.querySelector('[tabIndex]');
      if (focusRoot) {
        focusRoot.focus();
      }
    } else {
      // simply make item visible
      this.props.workspace.paneForItem(changedFileItem).activateItem(changedFileItem);
    }
  }

  async showMergeConflictFileForPath(relativeFilePath, {activate} = {activate: false}) {
    const absolutePath = path.join(this.props.workingDirectoryPath, relativeFilePath);
    if (await this.fileExists(absolutePath)) {
      return this.props.workspace.open(absolutePath, {activatePane: activate, activateItem: activate, pending: true});
    } else {
      this.props.notificationManager.addInfo('File has been deleted.');
      return null;
    }
  }

  fileExists(absolutePath) {
    return new File(absolutePath).exists();
  }

  dblclickOnItem(event, item) {
    return this.props.attemptFileStageOperation([item.filePath], this.state.selection.listKeyForItem(item));
  }

  async contextMenuOnItem(event, item) {
    if (!this.state.selection.getSelectedItems().has(item)) {
      event.stopPropagation();

      event.persist();
      await new Promise(resolve => {
        this.setState(prevState => ({
          selection: prevState.selection.selectItem(item, event.shiftKey),
        }), resolve);
      });

      const newEvent = new MouseEvent(event.type, event);
      requestAnimationFrame(() => {
        if (!event.target.parentNode) {
          return;
        }
        event.target.parentNode.dispatchEvent(newEvent);
      });
    }
  }

  async mousedownOnItem(event, item) {
    const windows = process.platform === 'win32';
    if (event.ctrlKey && !windows) { return; } // simply open context menu
    if (event.button === 0) {
      this.mouseSelectionInProgress = true;

      event.persist();
      await new Promise(resolve => {
        if (event.metaKey || (event.ctrlKey && windows)) {
          this.setState(prevState => ({
            selection: prevState.selection.addOrSubtractSelection(item),
          }), resolve);
        } else {
          this.setState(prevState => ({
            selection: prevState.selection.selectItem(item, event.shiftKey),
          }), resolve);
        }
      });
    }
  }

  async mousemoveOnItem(event, item) {
    if (this.mouseSelectionInProgress) {
      await new Promise(resolve => {
        this.setState(prevState => ({
          selection: prevState.selection.selectItem(item, true),
        }), resolve);
      });
    }
  }

  async mouseup() {
    const hadSelectionInProgress = this.mouseSelectionInProgress;
    this.mouseSelectionInProgress = false;

    await new Promise(resolve => {
      this.setState(prevState => ({
        selection: prevState.selection.coalesce(),
      }), resolve);
    });
    if (hadSelectionInProgress) {
      this.didChangeSelectedItems(true);
    }
  }

  undoLastDiscard({eventSource} = {}) {
    if (!this.props.hasUndoHistory) {
      return;
    }

    addEvent('undo-last-discard', {
      package: 'github',
      component: 'StagingView',
      eventSource,
    });

    this.props.undoLastDiscard();
  }

  getFocusClass(listKey) {
    return this.state.selection.getActiveListKey() === listKey ? 'is-focused' : '';
  }

  registerItemElement(item, element) {
    this.listElementsByItem.set(item, element);
  }

  getFocus(element) {
    return this.refRoot.map(root => root.contains(element)).getOr(false) ? StagingView.focus.STAGING : null;
  }

  setFocus(focus) {
    if (focus === this.constructor.focus.STAGING) {
      this.refRoot.map(root => root.focus());
      return true;
    }

    return false;
  }

  async advanceFocusFrom(focus) {
    if (focus === this.constructor.focus.STAGING) {
      if (await this.activateNextList()) {
        // There was a next list to activate.
        return this.constructor.focus.STAGING;
      }

      // We were already on the last list.
      return CommitView.firstFocus;
    }

    return null;
  }

  async retreatFocusFrom(focus) {
    if (focus === CommitView.firstFocus) {
      await this.activateLastList();
      return this.constructor.focus.STAGING;
    }

    if (focus === this.constructor.focus.STAGING) {
      await this.activatePreviousList();
      return this.constructor.focus.STAGING;
    }

    return false;
  }

  hasFocus() {
    return this.refRoot.map(root => root.contains(document.activeElement)).getOr(false);
  }

  isPopulated(props) {
    return props.workingDirectoryPath != null && (
      props.unstagedChanges.length > 0 ||
      props.mergeConflicts.length > 0 ||
      props.stagedChanges.length > 0
    );
  }
}
