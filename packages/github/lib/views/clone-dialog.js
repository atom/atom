import React from 'react';
import PropTypes from 'prop-types';
import {CompositeDisposable} from 'event-kit';
import {TextBuffer} from 'atom';
import url from 'url';
import path from 'path';

import TabGroup from '../tab-group';
import DialogView from './dialog-view';
import {TabbableTextEditor} from './tabbable';

export default class CloneDialog extends React.Component {
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
    config: PropTypes.object.isRequired,
  }

  constructor(props) {
    super(props);

    const params = this.props.request.getParams();
    this.sourceURL = new TextBuffer({text: params.sourceURL});
    this.destinationPath = new TextBuffer({
      text: params.destPath || this.props.config.get('core.projectHome'),
    });
    this.destinationPathModified = false;

    this.state = {
      acceptEnabled: false,
    };

    this.subs = new CompositeDisposable(
      this.sourceURL.onDidChange(this.didChangeSourceUrl),
      this.destinationPath.onDidChange(this.didChangeDestinationPath),
    );

    this.tabGroup = new TabGroup();
  }

  render() {
    return (
      <DialogView
        progressMessage="cloning..."
        acceptEnabled={this.state.acceptEnabled}
        acceptClassNames="icon icon-repo-clone"
        acceptText="Clone"
        accept={this.accept}
        cancel={this.props.request.cancel}
        tabGroup={this.tabGroup}
        inProgress={this.props.inProgress}
        error={this.props.error}
        workspace={this.props.workspace}
        commands={this.props.commands}>

        <label className="github-DialogLabel">
          Clone from
          <TabbableTextEditor
            tabGroup={this.tabGroup}
            commands={this.props.commands}
            autofocus
            className="github-Clone-sourceURL"
            mini
            readOnly={this.props.inProgress}
            buffer={this.sourceURL}
          />
        </label>
        <label className="github-DialogLabel">
          To directory
          <TabbableTextEditor
            tabGroup={this.tabGroup}
            commands={this.props.commands}
            className="github-Clone-destinationPath"
            mini
            readOnly={this.props.inProgress}
            buffer={this.destinationPath}
          />
        </label>

      </DialogView>
    );
  }

  componentDidMount() {
    this.tabGroup.autofocus();
  }

  accept = () => {
    const sourceURL = this.sourceURL.getText();
    const destinationPath = this.destinationPath.getText();
    if (sourceURL === '' || destinationPath === '') {
      return Promise.resolve();
    }

    return this.props.request.accept(sourceURL, destinationPath);
  }

  didChangeSourceUrl = () => {
    if (!this.destinationPathModified) {
      const name = path.basename(url.parse(this.sourceURL.getText()).pathname, '.git') || '';

      if (name.length > 0) {
        const proposedPath = path.join(this.props.config.get('core.projectHome'), name);
        this.destinationPath.setText(proposedPath);
        this.destinationPathModified = false;
      }
    }

    this.setAcceptEnablement();
  }

  didChangeDestinationPath = () => {
    this.destinationPathModified = true;
    this.setAcceptEnablement();
  }

  setAcceptEnablement = () => {
    const enabled = !this.sourceURL.isEmpty() && !this.destinationPath.isEmpty();
    if (enabled !== this.state.acceptEnabled) {
      this.setState({acceptEnabled: enabled});
    }
  }
}
