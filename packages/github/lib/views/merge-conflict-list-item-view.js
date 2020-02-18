import React from 'react';
import PropTypes from 'prop-types';
import {CompositeDisposable} from 'event-kit';

import {classNameForStatus} from '../helpers';
import {MergeConflictItemPropType} from '../prop-types';
import RefHolder from '../models/ref-holder';

export default class MergeConflictListItemView extends React.Component {
  static propTypes = {
    mergeConflict: MergeConflictItemPropType.isRequired,
    selected: PropTypes.bool.isRequired,
    remainingConflicts: PropTypes.number,
    registerItemElement: PropTypes.func.isRequired,
  };

  constructor(props) {
    super(props);

    this.refItem = new RefHolder();
    this.subs = new CompositeDisposable(
      this.refItem.observe(item => this.props.registerItemElement(this.props.mergeConflict, item)),
    );
  }

  render() {
    const {mergeConflict, selected, ...others} = this.props;
    delete others.remainingConflicts;
    delete others.registerItemElement;
    const fileStatus = classNameForStatus[mergeConflict.status.file];
    const oursStatus = classNameForStatus[mergeConflict.status.ours];
    const theirsStatus = classNameForStatus[mergeConflict.status.theirs];
    const className = selected ? 'is-selected' : '';

    return (
      <div
        ref={this.refItem.setter}
        {...others}
        className={`github-MergeConflictListView-item is-${fileStatus} ${className}`}>
        <div className="github-FilePatchListView-item github-FilePatchListView-pathItem">
          <span className={`github-FilePatchListView-icon icon icon-diff-${fileStatus} status-${fileStatus}`} />
          <span className="github-FilePatchListView-path">{mergeConflict.filePath}</span>
          <span className={'github-FilePatchListView ours-theirs-info'}>
            <span className={`github-FilePatchListView-icon icon icon-diff-${oursStatus}`} />
            <span className={`github-FilePatchListView-icon icon icon-diff-${theirsStatus}`} />
          </span>
        </div>
        <div className="github-FilePatchListView-item github-FilePatchListView-resolutionItem">
          {this.renderRemainingConflicts()}
        </div>
      </div>
    );
  }

  renderRemainingConflicts() {
    if (this.props.remainingConflicts === 0) {
      return (
        <span className="icon icon-check github-RemainingConflicts text-success">
          ready
        </span>
      );
    } else if (this.props.remainingConflicts !== undefined) {
      const pluralConflicts = this.props.remainingConflicts === 1 ? '' : 's';

      return (
        <span className="github-RemainingConflicts text-warning">
          {this.props.remainingConflicts} conflict{pluralConflicts} remaining
        </span>
      );
    } else {
      return (
        <span className="github-RemainingConflicts text-subtle">calculating</span>
      );
    }
  }

  componentWillUnmount() {
    this.subs.dispose();
  }
}
