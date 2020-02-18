import React from 'react';
import PropTypes from 'prop-types';
import yubikiri from 'yubikiri';
import {CompositeDisposable, Emitter} from 'event-kit';

import {autobind} from '../helpers';
import ObserveModel from '../views/observe-model';
import LoadingView from '../views/loading-view';
import ChangedFileController from '../controllers/changed-file-controller';
import PatchBuffer from '../models/patch/patch-buffer';

export default class ChangedFileContainer extends React.Component {
  static propTypes = {
    repository: PropTypes.object.isRequired,
    stagingStatus: PropTypes.oneOf(['staged', 'unstaged']),
    relPath: PropTypes.string.isRequired,
    largeDiffThreshold: PropTypes.number,

    workspace: PropTypes.object.isRequired,
    commands: PropTypes.object.isRequired,
    keymaps: PropTypes.object.isRequired,
    tooltips: PropTypes.object.isRequired,
    config: PropTypes.object.isRequired,

    destroy: PropTypes.func.isRequired,
    undoLastDiscard: PropTypes.func.isRequired,
    surfaceFileAtPath: PropTypes.func.isRequired,
  }

  constructor(props) {
    super(props);
    autobind(this, 'fetchData', 'renderWithData');

    this.emitter = new Emitter();

    this.patchBuffer = new PatchBuffer();
    this.lastMultiFilePatch = null;
    this.sub = new CompositeDisposable();

    this.state = {renderStatusOverride: null};
  }

  fetchData(repository) {
    const staged = this.props.stagingStatus === 'staged';

    const builderOpts = {};
    if (this.state.renderStatusOverride !== null) {
      builderOpts.renderStatusOverrides = {[this.props.relPath]: this.state.renderStatusOverride};
    }
    if (this.props.largeDiffThreshold !== undefined) {
      builderOpts.largeDiffThreshold = this.props.largeDiffThreshold;
    }

    const before = () => this.emitter.emit('will-update-patch');
    const after = patch => this.emitter.emit('did-update-patch', patch);

    return yubikiri({
      multiFilePatch: repository.getFilePatchForPath(this.props.relPath, {
        staged,
        patchBuffer: this.patchBuffer,
        builder: builderOpts,
        before,
        after,
      }),
      isPartiallyStaged: repository.isPartiallyStaged(this.props.relPath),
      hasUndoHistory: repository.hasDiscardHistory(this.props.relPath),
    });
  }

  render() {
    return (
      <ObserveModel model={this.props.repository} fetchData={this.fetchData}>
        {this.renderWithData}
      </ObserveModel>
    );
  }

  renderWithData(data) {
    const currentMultiFilePatch = data && data.multiFilePatch;
    if (currentMultiFilePatch !== this.lastMultiFilePatch) {
      this.sub.dispose();
      /* istanbul ignore else */
      if (currentMultiFilePatch) {
        // Keep this component's renderStatusOverride synchronized with the FilePatch we're rendering
        this.sub = new CompositeDisposable(
          ...currentMultiFilePatch.getFilePatches().map(fp => fp.onDidChangeRenderStatus(() => {
            this.setState({renderStatusOverride: fp.getRenderStatus()});
          })),
        );
      }
      this.lastMultiFilePatch = currentMultiFilePatch;
    }

    if (this.props.repository.isLoading() || data === null) {
      return <LoadingView />;
    }

    return (
      <ChangedFileController
        onWillUpdatePatch={this.onWillUpdatePatch}
        onDidUpdatePatch={this.onDidUpdatePatch}
        {...data}
        {...this.props}
      />
    );
  }

  componentWillUnmount() {
    this.sub.dispose();
  }

  onWillUpdatePatch = cb => this.emitter.on('will-update-patch', cb);

  onDidUpdatePatch = cb => this.emitter.on('did-update-patch', cb);
}
