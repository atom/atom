import React from 'react';
import PropTypes from 'prop-types';
import cx from 'classnames';

import Commands, {Command} from '../atom/commands';
import {BranchPropType, BranchSetPropType} from '../prop-types';
import {GitError} from '../git-shell-out-strategy';

export default class BranchMenuView extends React.Component {
  static propTypes = {
    // Atom environment
    workspace: PropTypes.object.isRequired,
    commands: PropTypes.object.isRequired,
    notificationManager: PropTypes.object.isRequired,

    // Model
    repository: PropTypes.object,
    branches: BranchSetPropType.isRequired,
    currentBranch: BranchPropType.isRequired,
    checkout: PropTypes.func,
  }

  state = {
    createNew: false,
    checkedOutBranch: null,
  }

  render() {
    const branchNames = this.props.branches.getNames().filter(Boolean);
    let currentBranchName = this.props.currentBranch.isDetached() ? 'detached' : this.props.currentBranch.getName();
    if (this.state.checkedOutBranch) {
      currentBranchName = this.state.checkedOutBranch;
      if (branchNames.indexOf(this.state.checkedOutBranch) === -1) {
        branchNames.push(this.state.checkedOutBranch);
      }
    }

    const disableControls = !!this.state.checkedOutBranch;

    const branchEditorClasses = cx('github-BranchMenuView-item', 'github-BranchMenuView-editor', {
      hidden: !this.state.createNew,
    });

    const branchSelectListClasses = cx('github-BranchMenuView-item', 'github-BranchMenuView-select', 'input-select', {
      hidden: !!this.state.createNew,
    });

    const iconClasses = cx('github-BranchMenuView-item', 'icon', {
      'icon-git-branch': !disableControls,
      'icon-sync': disableControls,
    });

    const newBranchEditor = (
      <div className={branchEditorClasses}>
        <atom-text-editor
          ref={e => { this.editorElement = e; }}
          mini={true}
          readonly={disableControls ? true : undefined}
        />
      </div>
    );

    const selectBranchView = (
      /* eslint-disable jsx-a11y/no-onchange */
      <select
        className={branchSelectListClasses}
        onChange={this.didSelectItem}
        disabled={disableControls}
        value={currentBranchName}>
        {this.props.currentBranch.isDetached() &&
          <option key="detached" value="detached" disabled>{this.props.currentBranch.getName()}</option>
        }
        {branchNames.map(branchName => {
          return <option key={`branch-${branchName}`} value={branchName}>{branchName}</option>;
        })}
      </select>
    );

    return (
      <div className="github-BranchMenuView">
        <Commands registry={this.props.commands} target=".github-BranchMenuView-editor atom-text-editor[mini]">
          <Command command="tool-panel:unfocus" callback={this.cancelCreateNewBranch} />
          <Command command="core:cancel" callback={this.cancelCreateNewBranch} />
          <Command command="core:confirm" callback={this.createBranch} />
        </Commands>
        <div className="github-BranchMenuView-selector">
          <span className={iconClasses} />
          {newBranchEditor}
          {selectBranchView}
          <button className="github-BranchMenuView-item github-BranchMenuView-button btn"
            onClick={this.createBranch} disabled={disableControls}> New Branch </button>
        </div>
      </div>
    );
  }

  didSelectItem = async event => {
    const branchName = event.target.value;
    await this.checkout(branchName);
  }

  createBranch = async () => {
    if (this.state.createNew) {
      const branchName = this.editorElement.getModel().getText().trim();
      await this.checkout(branchName, {createNew: true});
    } else {
      await new Promise(resolve => {
        this.setState({createNew: true}, () => {
          this.editorElement.focus();
          resolve();
        });
      });
    }
  }

  checkout = async (branchName, options) => {
    this.editorElement.classList.remove('is-focused');
    await new Promise(resolve => {
      this.setState({checkedOutBranch: branchName}, resolve);
    });
    try {
      await this.props.checkout(branchName, options);
      await new Promise(resolve => {
        this.setState({checkedOutBranch: null, createNew: false}, resolve);
      });
      this.editorElement.getModel().setText('');
    } catch (error) {
      this.editorElement.classList.add('is-focused');
      await new Promise(resolve => {
        this.setState({checkedOutBranch: null}, resolve);
      });
      if (!(error instanceof GitError)) {
        throw error;
      }
    }
  }

  cancelCreateNewBranch = () => {
    this.setState({createNew: false});
  }
}
