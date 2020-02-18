import React from 'react';
import PropTypes from 'prop-types';

import RefHolder from '../models/ref-holder';
import GitTabContainer from '../containers/git-tab-container';

export default class GitTabItem extends React.Component {
  static propTypes = {
    repository: PropTypes.object.isRequired,
  }

  static uriPattern = 'atom-github://dock-item/git'

  static buildURI() {
    return this.uriPattern;
  }

  constructor(props) {
    super(props);

    this.refController = new RefHolder();
  }

  render() {
    return (
      <GitTabContainer
        controllerRef={this.refController}
        {...this.props}
      />
    );
  }

  serialize() {
    return {
      deserializer: 'GitDockItem',
      uri: this.getURI(),
    };
  }

  getTitle() {
    return 'Git';
  }

  getIconName() {
    return 'git-commit';
  }

  getDefaultLocation() {
    return 'right';
  }

  getPreferredWidth() {
    return 400;
  }

  getURI() {
    return this.constructor.uriPattern;
  }

  getWorkingDirectory() {
    return this.props.repository.getWorkingDirectoryPath();
  }

  // Forwarded to the controller instance when one is present

  rememberLastFocus(...args) {
    return this.refController.map(c => c.rememberLastFocus(...args));
  }

  restoreFocus(...args) {
    return this.refController.map(c => c.restoreFocus(...args));
  }

  hasFocus(...args) {
    return this.refController.map(c => c.hasFocus(...args));
  }

  focus() {
    return this.refController.map(c => c.restoreFocus());
  }

  focusAndSelectStagingItem(...args) {
    return this.refController.map(c => c.focusAndSelectStagingItem(...args));
  }

  focusAndSelectCommitPreviewButton() {
    return this.refController.map(c => c.focusAndSelectCommitPreviewButton());
  }

  quietlySelectItem(...args) {
    return this.refController.map(c => c.quietlySelectItem(...args));
  }

  focusAndSelectRecentCommit() {
    return this.refController.map(c => c.focusAndSelectRecentCommit());
  }
}
