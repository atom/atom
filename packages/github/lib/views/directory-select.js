import React from 'react';
import PropTypes from 'prop-types';
import {remote} from 'electron';

import {TabbableTextEditor, TabbableButton} from './tabbable';

const {dialog} = remote;

export default class DirectorySelect extends React.Component {
  static propTypes = {
    buffer: PropTypes.object.isRequired,
    disabled: PropTypes.bool,
    showOpenDialog: PropTypes.func,
    tabGroup: PropTypes.object.isRequired,

    // Atom environment
    currentWindow: PropTypes.object.isRequired,
    commands: PropTypes.object.isRequired,
  }

  static defaultProps = {
    disabled: false,
    showOpenDialog: /* istanbul ignore next */ (...args) => dialog.showOpenDialog(...args),
  }

  render() {
    return (
      <div className="github-Dialog-row">
        <TabbableTextEditor
          tabGroup={this.props.tabGroup}
          commands={this.props.commands}
          className="github-DirectorySelect-destinationPath"
          mini={true}
          readOnly={this.props.disabled}
          buffer={this.props.buffer}
        />
        <TabbableButton
          tabGroup={this.props.tabGroup}
          commands={this.props.commands}
          className="btn icon icon-file-directory github-Dialog-rightBumper"
          disabled={this.props.disabled}
          onClick={this.chooseDirectory}
        />
      </div>
    );
  }

  chooseDirectory = () => new Promise(resolve => {
    this.props.showOpenDialog(this.props.currentWindow, {
      defaultPath: this.props.buffer.getText(),
      properties: ['openDirectory', 'createDirectory', 'promptToCreate'],
    }, filePaths => {
      if (filePaths !== undefined) {
        this.props.buffer.setText(filePaths[0]);
      }
      resolve();
    });
  });
}
