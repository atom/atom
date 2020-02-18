import path from 'path';

import React, {Fragment} from 'react';
import PropTypes from 'prop-types';
import cx from 'classnames';

import Octicon from '../atom/octicon';
import RefHolder from '../models/ref-holder';
import IssueishDetailItem from '../items/issueish-detail-item';
import ChangedFileItem from '../items/changed-file-item';
import CommitDetailItem from '../items/commit-detail-item';
import {ItemTypePropType} from '../prop-types';
import {addEvent} from '../reporter-proxy';

export default class FilePatchHeaderView extends React.Component {
  static propTypes = {
    relPath: PropTypes.string.isRequired,
    newPath: PropTypes.string,
    stagingStatus: PropTypes.oneOf(['staged', 'unstaged']),
    isPartiallyStaged: PropTypes.bool,
    hasUndoHistory: PropTypes.bool,
    hasMultipleFileSelections: PropTypes.bool.isRequired,

    tooltips: PropTypes.object.isRequired,

    undoLastDiscard: PropTypes.func.isRequired,
    diveIntoMirrorPatch: PropTypes.func.isRequired,
    openFile: PropTypes.func.isRequired,
    // should probably change 'toggleFile' to 'toggleFileStagingStatus'
    // because the addition of another toggling function makes the old name confusing.
    toggleFile: PropTypes.func.isRequired,

    itemType: ItemTypePropType.isRequired,

    isCollapsed: PropTypes.bool.isRequired,
    triggerExpand: PropTypes.func.isRequired,
    triggerCollapse: PropTypes.func.isRequired,
  };

  constructor(props) {
    super(props);

    this.refMirrorButton = new RefHolder();
    this.refOpenFileButton = new RefHolder();
  }

  render() {
    return (
      <header className="github-FilePatchView-header">
        {this.renderCollapseButton()}
        <span className="github-FilePatchView-title">
          {this.renderTitle()}
        </span>
        {this.renderButtonGroup()}
      </header>
    );
  }

  togglePatchCollapse = () => {
    if (this.props.isCollapsed) {
      addEvent('expand-file-patch', {component: this.constructor.name, package: 'github'});
      this.props.triggerExpand();
    } else {
      addEvent('collapse-file-patch', {component: this.constructor.name, package: 'github'});
      this.props.triggerCollapse();
    }
  }

  renderCollapseButton() {
    if (this.props.itemType === ChangedFileItem) {
      return null;
    }
    const icon = this.props.isCollapsed ? 'chevron-right' : 'chevron-down';
    return (
      <button
        className="github-FilePatchView-collapseButton"
        onClick={this.togglePatchCollapse}>
        <Octicon className="github-FilePatchView-collapseButtonIcon" icon={icon} />
      </button>
    );
  }

  renderTitle() {
    if (this.props.itemType === ChangedFileItem) {
      const status = this.props.stagingStatus;
      return (
        <span>{status[0].toUpperCase()}{status.slice(1)} Changes for {this.renderDisplayPath()}</span>
      );
    } else {
      return this.renderDisplayPath();
    }
  }

  renderDisplayPath() {
    if (this.props.newPath && this.props.newPath !== this.props.relPath) {
      const oldPath = this.renderPath(this.props.relPath);
      const newPath = this.renderPath(this.props.newPath);
      return <span>{oldPath} <span>→</span> {newPath}</span>;
    } else {
      return this.renderPath(this.props.relPath);
    }
  }

  renderPath(filePath) {
    const dirname = path.dirname(filePath);
    const basename = path.basename(filePath);

    if (dirname === '.') {
      return <span className="gitub-FilePatchHeaderView-basename">{basename}</span>;
    } else {
      return (
        <span>
          {dirname}{path.sep}<span className="gitub-FilePatchHeaderView-basename">{basename}</span>
        </span>
      );
    }
  }

  renderButtonGroup() {
    if (this.props.itemType === CommitDetailItem || this.props.itemType === IssueishDetailItem) {
      return null;
    } else {
      return (
        <span className="btn-group">
          {this.renderUndoDiscardButton()}
          {this.renderMirrorPatchButton()}
          {this.renderOpenFileButton()}
          {this.renderToggleFileButton()}
        </span>
      );
    }
  }

  renderUndoDiscardButton() {
    const unstagedChangedFileItem = this.props.itemType === ChangedFileItem && this.props.stagingStatus === 'unstaged';
    if (unstagedChangedFileItem && this.props.hasUndoHistory) {
      return (
        <button className="btn icon icon-history" onClick={this.props.undoLastDiscard}>
        Undo Discard
        </button>
      );
    } else {
      return null;
    }
  }

  renderMirrorPatchButton() {
    if (!this.props.isPartiallyStaged) {
      return null;
    }

    const attrs = this.props.stagingStatus === 'unstaged'
      ? {
        iconClass: 'icon-tasklist',
        buttonText: 'View Staged',
      }
      : {
        iconClass: 'icon-list-unordered',
        buttonText: 'View Unstaged',
      };

    return (
      <Fragment>
        <button
          ref={this.refMirrorButton.setter}
          className={cx('btn', 'icon', attrs.iconClass)}
          onClick={this.props.diveIntoMirrorPatch}>
          {attrs.buttonText}
        </button>
      </Fragment>
    );
  }

  renderOpenFileButton() {
    let buttonText = 'Jump To File';
    if (this.props.hasMultipleFileSelections) {
      buttonText += 's';
    }

    return (
      <Fragment>
        <button
          ref={this.refOpenFileButton.setter}
          className="btn icon icon-code github-FilePatchHeaderView-jumpToFileButton"
          onClick={this.props.openFile}>
          {buttonText}
        </button>
      </Fragment>
    );
  }

  renderToggleFileButton() {
    const attrs = this.props.stagingStatus === 'unstaged'
      ? {
        buttonClass: 'icon-move-down',
        buttonText: 'Stage File',
      }
      : {
        buttonClass: 'icon-move-up',
        buttonText: 'Unstage File',
      };

    return (
      <button className={cx('btn', 'icon', attrs.buttonClass)} onClick={this.props.toggleFile}>
        {attrs.buttonText}
      </button>
    );
  }
}
