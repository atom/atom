import React from 'react';
import PropTypes from 'prop-types';

import MultiFilePatchController from './multi-file-patch-controller';

export default class CommitPreviewController extends React.Component {
  static propTypes = {
    repository: PropTypes.object.isRequired,
    stagingStatus: PropTypes.oneOf(['staged', 'unstaged']),

    workspace: PropTypes.object.isRequired,
    commands: PropTypes.object.isRequired,
    keymaps: PropTypes.object.isRequired,
    tooltips: PropTypes.object.isRequired,
    config: PropTypes.object.isRequired,

    destroy: PropTypes.func.isRequired,
    undoLastDiscard: PropTypes.func.isRequired,
    surfaceToCommitPreviewButton: PropTypes.func.isRequired,
  }

  render() {
    return (
      <MultiFilePatchController
        surface={this.props.surfaceToCommitPreviewButton}
        {...this.props}
      />
    );
  }
}
