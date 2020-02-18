import React from 'react';
import PropTypes from 'prop-types';
import {CompositeDisposable} from 'event-kit';

import {FilePatchItemPropType} from '../prop-types';
import {classNameForStatus} from '../helpers';
import RefHolder from '../models/ref-holder';

export default class FilePatchListItemView extends React.Component {
  static propTypes = {
    filePatch: FilePatchItemPropType.isRequired,
    selected: PropTypes.bool.isRequired,
    registerItemElement: PropTypes.func,
  }

  static defaultProps = {
    registerItemElement: () => {},
  }

  constructor(props) {
    super(props);

    this.refItem = new RefHolder();
    this.subs = new CompositeDisposable(
      this.refItem.observe(item => this.props.registerItemElement(this.props.filePatch, item)),
    );
  }

  render() {
    const {filePatch, selected, ...others} = this.props;
    delete others.registerItemElement;
    const status = classNameForStatus[filePatch.status];
    const className = selected ? 'is-selected' : '';

    return (
      <div ref={this.refItem.setter} {...others} className={`github-FilePatchListView-item is-${status} ${className}`}>
        <span className={`github-FilePatchListView-icon icon icon-diff-${status} status-${status}`} />
        <span className="github-FilePatchListView-path">{filePatch.filePath}</span>
      </div>
    );
  }

  componentWillUnmount() {
    this.subs.dispose();
  }
}
