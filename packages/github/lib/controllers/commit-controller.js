import path from 'path';
import {TextBuffer} from 'atom';

import React from 'react';
import PropTypes from 'prop-types';
import {CompositeDisposable} from 'event-kit';
import fs from 'fs-extra';

import CommitView from '../views/commit-view';
import RefHolder from '../models/ref-holder';
import CommitPreviewItem from '../items/commit-preview-item';
import {AuthorPropType, UserStorePropType} from '../prop-types';
import {watchWorkspaceItem} from '../watch-workspace-item';
import {autobind} from '../helpers';
import {addEvent} from '../reporter-proxy';

export const COMMIT_GRAMMAR_SCOPE = 'text.git-commit';

export default class CommitController extends React.Component {
  static focus = {
    ...CommitView.focus,
  }

  static propTypes = {
    workspace: PropTypes.object.isRequired,
    grammars: PropTypes.object.isRequired,
    commands: PropTypes.object.isRequired,
    config: PropTypes.object.isRequired,
    tooltips: PropTypes.object.isRequired,

    repository: PropTypes.object.isRequired,
    isMerging: PropTypes.bool.isRequired,
    mergeConflictsExist: PropTypes.bool.isRequired,
    stagedChangesExist: PropTypes.bool.isRequired,
    lastCommit: PropTypes.object.isRequired,
    currentBranch: PropTypes.object.isRequired,
    userStore: UserStorePropType.isRequired,
    selectedCoAuthors: PropTypes.arrayOf(AuthorPropType),
    updateSelectedCoAuthors: PropTypes.func,
    prepareToCommit: PropTypes.func.isRequired,
    commit: PropTypes.func.isRequired,
    abortMerge: PropTypes.func.isRequired,
  }

  constructor(props, context) {
    super(props, context);
    autobind(this, 'commit', 'handleMessageChange', 'toggleExpandedCommitMessageEditor', 'grammarAdded',
      'toggleCommitPreview');

    this.subscriptions = new CompositeDisposable();
    this.refCommitView = new RefHolder();

    this.commitMessageBuffer = new TextBuffer({text: this.props.repository.getCommitMessage()});
    this.subscriptions.add(
      this.commitMessageBuffer.onDidChange(this.handleMessageChange),
    );

    this.previewWatcher = watchWorkspaceItem(
      this.props.workspace,
      CommitPreviewItem.buildURI(this.props.repository.getWorkingDirectoryPath()),
      this,
      'commitPreviewActive',
    );
    this.subscriptions.add(this.previewWatcher);
  }

  componentDidMount() {
    this.subscriptions.add(
      this.props.workspace.onDidAddTextEditor(({textEditor}) => {
        if (this.props.repository.isPresent() && textEditor.getPath() === this.getCommitMessagePath()) {
          const grammar = this.props.grammars.grammarForScopeName(COMMIT_GRAMMAR_SCOPE);
          if (grammar) {
            textEditor.setGrammar(grammar);
          }
        }
      }),
      this.props.workspace.onDidDestroyPaneItem(async ({item}) => {
        if (this.props.repository.isPresent() && item.getPath && item.getPath() === this.getCommitMessagePath() &&
          this.getCommitMessageEditors().length === 0) {
          // we closed the last editor pointing to the commit message file
          try {
            this.commitMessageBuffer.setText(await fs.readFile(this.getCommitMessagePath(), {encoding: 'utf8'}));
          } catch (e) {
            if (e.code !== 'ENOENT') {
              throw e;
            }
          }
        }
      }),
    );
  }

  render() {
    const operationStates = this.props.repository.getOperationStates();

    return (
      <CommitView
        ref={this.refCommitView.setter}
        workspace={this.props.workspace}
        tooltips={this.props.tooltips}
        config={this.props.config}
        stagedChangesExist={this.props.stagedChangesExist}
        mergeConflictsExist={this.props.mergeConflictsExist}
        prepareToCommit={this.props.prepareToCommit}
        commit={this.commit}
        abortMerge={this.props.abortMerge}
        commands={this.props.commands}
        maximumCharacterLimit={72}
        messageBuffer={this.commitMessageBuffer}
        isMerging={this.props.isMerging}
        isCommitting={operationStates.isCommitInProgress()}
        lastCommit={this.props.lastCommit}
        currentBranch={this.props.currentBranch}
        toggleExpandedCommitMessageEditor={this.toggleExpandedCommitMessageEditor}
        deactivateCommitBox={this.isCommitMessageEditorExpanded()}
        userStore={this.props.userStore}
        selectedCoAuthors={this.props.selectedCoAuthors}
        updateSelectedCoAuthors={this.props.updateSelectedCoAuthors}
        toggleCommitPreview={this.toggleCommitPreview}
        activateCommitPreview={this.activateCommitPreview}
        commitPreviewActive={this.state.commitPreviewActive}
      />
    );
  }

  componentDidUpdate(prevProps) {
    this.commitMessageBuffer.setTextViaDiff(this.getCommitMessage());

    if (prevProps.repository !== this.props.repository) {
      this.previewWatcher.setPattern(
        CommitPreviewItem.buildURI(this.props.repository.getWorkingDirectoryPath()),
      );
    }
  }

  componentWillUnmount() {
    this.subscriptions.dispose();
  }

  commit(message, coAuthors = [], amend = false) {
    let msg, verbatim;
    if (this.isCommitMessageEditorExpanded()) {
      msg = this.getCommitMessageEditors()[0].getText();
      verbatim = false;
    } else {
      const wrapMessage = this.props.config.get('github.automaticCommitMessageWrapping');
      msg = wrapMessage ? wrapCommitMessage(message) : message;
      verbatim = true;
    }

    return this.props.commit(msg.trim(), {amend, coAuthors, verbatim});
  }

  setCommitMessage(message, options) {
    if (!this.props.repository.isPresent()) { return; }
    this.props.repository.setCommitMessage(message, options);
  }

  getCommitMessage() {
    return this.props.repository.getCommitMessage();
  }

  getCommitMessagePath() {
    return path.join(this.props.repository.getGitDirectoryPath(), 'ATOM_COMMIT_EDITMSG');
  }

  handleMessageChange() {
    if (!this.props.repository.isPresent()) {
      return;
    }
    this.setCommitMessage(this.commitMessageBuffer.getText(), {suppressUpdate: true});
  }

  getCommitMessageEditors() {
    if (!this.props.repository.isPresent()) {
      return [];
    }
    return this.props.workspace.getTextEditors().filter(editor => editor.getPath() === this.getCommitMessagePath());
  }

  async toggleExpandedCommitMessageEditor(messageFromBox) {
    if (this.isCommitMessageEditorExpanded()) {
      if (this.commitMessageEditorIsInForeground()) {
        await this.closeAllOpenCommitMessageEditors();
        this.forceUpdate();
      } else {
        this.activateCommitMessageEditor();
      }
    } else {
      await this.openCommitMessageEditor(messageFromBox);
      this.forceUpdate();
    }
  }

  isCommitMessageEditorExpanded() {
    return this.getCommitMessageEditors().length > 0;
  }

  commitMessageEditorIsInForeground() {
    const commitMessageEditorsInForeground = this.props.workspace.getPanes()
      .map(pane => pane.getActiveItem())
      .filter(item => item && item.getPath && item.getPath() === this.getCommitMessagePath());
    return commitMessageEditorsInForeground.length > 0;
  }

  activateCommitMessageEditor() {
    const panes = this.props.workspace.getPanes();
    let editor;
    const paneWithEditor = panes.find(pane => {
      editor = pane.getItems().find(item => item.getPath && item.getPath() === this.getCommitMessagePath());
      return !!editor;
    });
    paneWithEditor.activate();
    paneWithEditor.activateItem(editor);
  }

  closeAllOpenCommitMessageEditors() {
    return Promise.all(
      this.props.workspace.getPanes().map(pane => {
        return Promise.all(
          pane.getItems().map(async item => {
            if (item && item.getPath && item.getPath() === this.getCommitMessagePath()) {
              const destroyed = await pane.destroyItem(item);
              if (!destroyed) {
                pane.activateItem(item);
              }
            }
          }),
        );
      }),
    );
  }

  async openCommitMessageEditor(messageFromBox) {
    await fs.writeFile(this.getCommitMessagePath(), messageFromBox, 'utf8');
    const commitEditor = await this.props.workspace.open(this.getCommitMessagePath());
    addEvent('open-commit-message-editor', {package: 'github'});

    const grammar = this.props.grammars.grammarForScopeName(COMMIT_GRAMMAR_SCOPE);
    if (grammar) {
      commitEditor.setGrammar(grammar);
    } else {
      this.grammarSubscription = this.props.grammars.onDidAddGrammar(this.grammarAdded);
      this.subscriptions.add(this.grammarSubscription);
    }
  }

  grammarAdded(grammar) {
    if (grammar.scopeName !== COMMIT_GRAMMAR_SCOPE) { return; }

    this.getCommitMessageEditors().forEach(editor => editor.setGrammar(grammar));
    this.grammarSubscription.dispose();
  }

  getFocus(element) {
    return this.refCommitView.map(view => view.getFocus(element)).getOr(null);
  }

  setFocus(focus) {
    return this.refCommitView.map(view => view.setFocus(focus)).getOr(false);
  }

  advanceFocusFrom(...args) {
    return this.refCommitView.map(view => view.advanceFocusFrom(...args)).getOr(false);
  }

  retreatFocusFrom(...args) {
    return this.refCommitView.map(view => view.retreatFocusFrom(...args)).getOr(false);
  }

  toggleCommitPreview() {
    addEvent('toggle-commit-preview', {package: 'github'});
    const uri = CommitPreviewItem.buildURI(this.props.repository.getWorkingDirectoryPath());
    if (this.props.workspace.hide(uri)) {
      return Promise.resolve();
    } else {
      return this.props.workspace.open(uri, {searchAllPanes: true, pending: true});
    }
  }

  activateCommitPreview = () => {
    const uri = CommitPreviewItem.buildURI(this.props.repository.getWorkingDirectoryPath());
    return this.props.workspace.open(uri, {searchAllPanes: true, pending: true, activate: true});
  }
}

function wrapCommitMessage(message) {
  // hard wrap message (except for first line) at 72 characters
  let results = [];
  message.split('\n').forEach((line, index) => {
    if (line.length <= 72 || index === 0) {
      results.push(line);
    } else {
      const matches = line.match(/.{1,72}(\s|$)|\S+?(\s|$)/g)
        .map(match => {
          return match.endsWith('\n') ? match.substr(0, match.length - 1) : match;
        });
      results = results.concat(matches);
    }
  });

  return results.join('\n');
}
