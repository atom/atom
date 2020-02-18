import React from 'react';
import PropTypes from 'prop-types';

import {blankLabel} from '../helpers';
import AtomTextEditor from '../atom/atom-text-editor';
import Decoration from '../atom/decoration';
import MarkerLayer from '../atom/marker-layer';
import Gutter from '../atom/gutter';

export default class PatchPreviewView extends React.Component {
  static propTypes = {
    multiFilePatch: PropTypes.shape({
      getPreviewPatchBuffer: PropTypes.func.isRequired,
    }).isRequired,
    fileName: PropTypes.string.isRequired,
    diffRow: PropTypes.number.isRequired,
    maxRowCount: PropTypes.number.isRequired,

    // Atom environment
    config: PropTypes.shape({
      get: PropTypes.func.isRequired,
    }),
  }

  state = {
    lastPatch: null,
    lastFileName: null,
    lastDiffRow: null,
    lastMaxRowCount: null,
    previewPatchBuffer: null,
  }

  static getDerivedStateFromProps(props, state) {
    if (
      props.multiFilePatch === state.lastPatch &&
      props.fileName === state.lastFileName &&
      props.diffRow === state.lastDiffRow &&
      props.maxRowCount === state.lastMaxRowCount
    ) {
      return null;
    }

    const nextPreviewPatchBuffer = props.multiFilePatch.getPreviewPatchBuffer(
      props.fileName, props.diffRow, props.maxRowCount,
    );
    let previewPatchBuffer = null;
    if (state.previewPatchBuffer !== null) {
      state.previewPatchBuffer.adopt(nextPreviewPatchBuffer);
      previewPatchBuffer = state.previewPatchBuffer;
    } else {
      previewPatchBuffer = nextPreviewPatchBuffer;
    }

    return {
      lastPatch: props.multiFilePatch,
      lastFileName: props.fileName,
      lastDiffRow: props.diffRow,
      lastMaxRowCount: props.maxRowCount,
      previewPatchBuffer,
    };
  }

  render() {
    return (
      <AtomTextEditor
        buffer={this.state.previewPatchBuffer.getBuffer()}
        readOnly={true}
        lineNumberGutterVisible={false}
        autoHeight={true}
        autoWidth={false}
        softWrapped={false}>

        {this.props.config.get('github.showDiffIconGutter') && (
          <Gutter name="diff-icons" priority={1} type="line-number" className="icons" labelFn={blankLabel} />
        )}

        {this.renderLayerDecorations('addition', 'github-FilePatchView-line--added')}
        {this.renderLayerDecorations('deletion', 'github-FilePatchView-line--deleted')}

      </AtomTextEditor>
    );
  }

  renderLayerDecorations(layerName, className) {
    const layer = this.state.previewPatchBuffer.getLayer(layerName);
    if (layer.getMarkerCount() === 0) {
      return null;
    }

    return (
      <MarkerLayer external={layer}>
        <Decoration type="line" className={className} omitEmptyLastRow={false} />
        {this.props.config.get('github.showDiffIconGutter') && (
          <Decoration type="line-number" gutterName="diff-icons" className={className} omitEmptyLastRow={false} />
        )}
      </MarkerLayer>
    );
  }
}
