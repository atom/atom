import React from 'react';
import PropTypes from 'prop-types';
import yubikiri from 'yubikiri';
import {CompositeDisposable, Emitter} from 'event-kit';

import ObserveModel from '../views/observe-model';
import LoadingView from '../views/loading-view';
import CommitPreviewController from '../controllers/commit-preview-controller';
import PatchBuffer from '../models/patch/patch-buffer';

export default class CommitPreviewContainer extends React.Component {
  static propTypes = {
    repository: PropTypes.object.isRequired,
    largeDiffThreshold: PropTypes.number,
  }

  constructor(props) {
    super(props);

    this.emitter = new Emitter();

    this.patchBuffer = new PatchBuffer();

    this.lastMultiFilePatch = null;
    this.sub = new CompositeDisposable();

    this.state = {renderStatusOverrides: {}};
  }

  fetchData = repository => {
    const builderOpts = {renderStatusOverrides: this.state.renderStatusOverrides};

    if (this.props.largeDiffThreshold !== undefined) {
      builderOpts.largeDiffThreshold = this.props.largeDiffThreshold;
    }

    const before = () => this.emitter.emit('will-update-patch');
    const after = patch => this.emitter.emit('did-update-patch', patch);

    return yubikiri({
      multiFilePatch: repository.getStagedChangesPatch({
        patchBuffer: this.patchBuffer,
        builder: builderOpts,
        before,
        after,
      }),
    });
  }

  render() {
    return (
      <ObserveModel model={this.props.repository} fetchData={this.fetchData}>
        {this.renderResult}
      </ObserveModel>
    );
  }

  renderResult = data => {
    const currentMultiFilePatch = data && data.multiFilePatch;
    if (currentMultiFilePatch !== this.lastMultiFilePatch) {
      this.sub.dispose();
      if (currentMultiFilePatch) {
        this.sub = new CompositeDisposable(
          ...currentMultiFilePatch.getFilePatches().map(fp => fp.onDidChangeRenderStatus(() => {
            this.setState(prevState => {
              return {
                renderStatusOverrides: {
                  ...prevState.renderStatusOverrides,
                  [fp.getPath()]: fp.getRenderStatus(),
                },
              };
            });
          })),
        );
      }
      this.lastMultiFilePatch = currentMultiFilePatch;
    }

    if (this.props.repository.isLoading() || data === null) {
      return <LoadingView />;
    }

    return (
      <CommitPreviewController
        stagingStatus={'staged'}
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
