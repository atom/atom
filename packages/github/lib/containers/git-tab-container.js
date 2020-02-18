import React from 'react';
import PropTypes from 'prop-types';
import yubikiri from 'yubikiri';

import {autobind} from '../helpers';
import {nullCommit} from '../models/commit';
import {nullBranch} from '../models/branch';
import ObserveModel from '../views/observe-model';
import GitTabController from '../controllers/git-tab-controller';

const DEFAULT_REPO_DATA = {
  lastCommit: nullCommit,
  recentCommits: [],
  isMerging: false,
  isRebasing: false,
  hasUndoHistory: false,
  currentBranch: nullBranch,
  unstagedChanges: [],
  stagedChanges: [],
  mergeConflicts: [],
  workingDirectoryPath: null,
  mergeMessage: null,
  fetchInProgress: true,
};

export default class GitTabContainer extends React.Component {
  static propTypes = {
    repository: PropTypes.object.isRequired,
  }

  constructor(props) {
    super(props);

    autobind(this, 'fetchData');
  }

  fetchData(repository) {
    return yubikiri({
      lastCommit: repository.getLastCommit(),
      recentCommits: repository.getRecentCommits({max: 10}),
      isMerging: repository.isMerging(),
      isRebasing: repository.isRebasing(),
      hasUndoHistory: repository.hasDiscardHistory(),
      currentBranch: repository.getCurrentBranch(),
      unstagedChanges: repository.getUnstagedChanges(),
      stagedChanges: repository.getStagedChanges(),
      mergeConflicts: repository.getMergeConflicts(),
      workingDirectoryPath: repository.getWorkingDirectoryPath(),
      mergeMessage: async query => {
        const isMerging = await query.isMerging;
        return isMerging ? repository.getMergeMessage() : null;
      },
      fetchInProgress: false,
    });
  }

  render() {
    return (
      <ObserveModel model={this.props.repository} fetchData={this.fetchData}>
        {data => <GitTabController {...this.props} {...(data || DEFAULT_REPO_DATA)} />}
      </ObserveModel>
    );
  }
}
