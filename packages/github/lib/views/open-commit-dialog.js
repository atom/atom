import React from 'react';
import PropTypes from 'prop-types';
import {TextBuffer} from 'atom';

import CommitDetailItem from '../items/commit-detail-item';
import {GitError} from '../git-shell-out-strategy';
import DialogView from './dialog-view';
import TabGroup from '../tab-group';
import {TabbableTextEditor} from './tabbable';
import {addEvent} from '../reporter-proxy';

export default class OpenCommitDialog extends React.Component {
  static propTypes = {
    // Model
    request: PropTypes.shape({
      getParams: PropTypes.func.isRequired,
      accept: PropTypes.func.isRequired,
      cancel: PropTypes.func.isRequired,
    }).isRequired,
    inProgress: PropTypes.bool,
    error: PropTypes.instanceOf(Error),

    // Atom environment
    workspace: PropTypes.object.isRequired,
    commands: PropTypes.object.isRequired,
  }

  constructor(props) {
    super(props);

    this.ref = new TextBuffer();
    this.sub = this.ref.onDidChange(this.didChangeRef);

    this.state = {
      acceptEnabled: false,
    };

    this.tabGroup = new TabGroup();
  }

  render() {
    return (
      <DialogView
        acceptEnabled={this.state.acceptEnabled}
        acceptClassName="icon icon-commit"
        acceptText="Open commit"
        accept={this.accept}
        cancel={this.props.request.cancel}
        tabGroup={this.tabGroup}
        inProgress={this.props.inProgress}
        error={this.props.error}
        workspace={this.props.workspace}
        commands={this.props.commands}>

        <label className="github-DialogLabel github-CommitRef">
          Commit sha or ref:
          <TabbableTextEditor
            tabGroup={this.tabGroup}
            commands={this.props.commands}
            autofocus
            mini
            buffer={this.ref}
          />
        </label>

      </DialogView>
    );
  }

  componentDidMount() {
    this.tabGroup.autofocus();
  }

  componentWillUnmount() {
    this.sub.dispose();
  }

  accept = () => {
    const ref = this.ref.getText();
    if (ref.length === 0) {
      return Promise.resolve();
    }

    return this.props.request.accept(ref);
  }

  didChangeRef = () => {
    const enabled = !this.ref.isEmpty();
    if (this.state.acceptEnabled !== enabled) {
      this.setState({acceptEnabled: enabled});
    }
  }
}

export async function openCommitDetailItem(ref, {workspace, repository}) {
  try {
    await repository.getCommit(ref);
  } catch (error) {
    if (error instanceof GitError && error.code === 128) {
      error.userMessage = 'There is no commit associated with that reference.';
    }

    throw error;
  }

  const item = await workspace.open(
    CommitDetailItem.buildURI(repository.getWorkingDirectoryPath(), ref),
    {searchAllPanes: true},
  );
  addEvent('open-commit-in-pane', {package: 'github', from: OpenCommitDialog.name});
  return item;
}
