import React from 'react';
import PropTypes from 'prop-types';

import MultiFilePatchController from './multi-file-patch-controller';

export default class ChangedFileController extends React.Component {
  static propTypes = {
    repository: PropTypes.object.isRequired,
    stagingStatus: PropTypes.oneOf(['staged', 'unstaged']),
    relPath: PropTypes.string.isRequired,

    workspace: PropTypes.object.isRequired,
    commands: PropTypes.object.isRequired,
    keymaps: PropTypes.object.isRequired,
    tooltips: PropTypes.object.isRequired,
    config: PropTypes.object.isRequired,

    destroy: PropTypes.func.isRequired,
    undoLastDiscard: PropTypes.func.isRequired,
    surfaceFileAtPath: PropTypes.func.isRequired,
  }

  render() {
    return (
      <MultiFilePatchController
        surface={this.surface}
        {...this.props}
      />
    );
  }

  surface = () => this.props.surfaceFileAtPath(this.props.relPath, this.props.stagingStatus)
}
