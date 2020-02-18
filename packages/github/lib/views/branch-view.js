import React from 'react';
import PropTypes from 'prop-types';
import cx from 'classnames';

import {BranchPropType} from '../prop-types';

export default class BranchView extends React.Component {
  static propTypes = {
    currentBranch: BranchPropType.isRequired,
    refRoot: PropTypes.func,
  }

  static defaultProps = {
    refRoot: () => {},
  }

  render() {
    const classNames = cx(
      'github-branch', 'inline-block', {'github-branch-detached': this.props.currentBranch.isDetached()},
    );

    return (
      <div className={classNames} ref={this.props.refRoot}>
        <span className="icon icon-git-branch" />
        <span className="branch-label">{this.props.currentBranch.getName()}</span>
      </div>
    );
  }
}
