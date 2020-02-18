import React from 'react';
import PropTypes from 'prop-types';
import {Emitter} from 'event-kit';

import {WorkdirContextPoolPropType} from '../prop-types';
import CommitPreviewContainer from '../containers/commit-preview-container';
import RefHolder from '../models/ref-holder';

export default class CommitPreviewItem extends React.Component {
  static propTypes = {
    workdirContextPool: WorkdirContextPoolPropType.isRequired,
    workingDirectory: PropTypes.string.isRequired,

    discardLines: PropTypes.func.isRequired,
    undoLastDiscard: PropTypes.func.isRequired,
    surfaceToCommitPreviewButton: PropTypes.func.isRequired,
  }

  static uriPattern = 'atom-github://commit-preview?workdir={workingDirectory}'

  static buildURI(workingDirectory) {
    return `atom-github://commit-preview?workdir=${encodeURIComponent(workingDirectory)}`;
  }

  constructor(props) {
    super(props);

    this.emitter = new Emitter();
    this.isDestroyed = false;
    this.hasTerminatedPendingState = false;
    this.refInitialFocus = new RefHolder();

    this.refEditor = new RefHolder();
    this.refEditor.observe(editor => {
      if (editor.isAlive()) {
        this.emitter.emit('did-change-embedded-text-editor', editor);
      }
    });
  }

  terminatePendingState() {
    if (!this.hasTerminatedPendingState) {
      this.emitter.emit('did-terminate-pending-state');
      this.hasTerminatedPendingState = true;
    }
  }

  onDidTerminatePendingState(callback) {
    return this.emitter.on('did-terminate-pending-state', callback);
  }

  destroy = () => {
    /* istanbul ignore else */
    if (!this.isDestroyed) {
      this.emitter.emit('did-destroy');
      this.isDestroyed = true;
    }
  }

  onDidDestroy(callback) {
    return this.emitter.on('did-destroy', callback);
  }

  render() {
    const repository = this.props.workdirContextPool.getContext(this.props.workingDirectory).getRepository();

    return (
      <CommitPreviewContainer
        itemType={this.constructor}
        repository={repository}
        {...this.props}
        destroy={this.destroy}
        refEditor={this.refEditor}
        refInitialFocus={this.refInitialFocus}
      />
    );
  }

  getTitle() {
    return 'Staged Changes';
  }

  getIconName() {
    return 'tasklist';
  }

  observeEmbeddedTextEditor(cb) {
    this.refEditor.map(editor => editor.isAlive() && cb(editor));
    return this.emitter.on('did-change-embedded-text-editor', cb);
  }

  getWorkingDirectory() {
    return this.props.workingDirectory;
  }

  serialize() {
    return {
      deserializer: 'CommitPreviewStub',
      uri: CommitPreviewItem.buildURI(this.props.workingDirectory),
    };
  }

  focus() {
    this.refInitialFocus.map(focusable => focusable.focus());
  }
}
