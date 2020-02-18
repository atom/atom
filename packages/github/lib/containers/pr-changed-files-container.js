import React from 'react';
import PropTypes from 'prop-types';
import {CompositeDisposable} from 'event-kit';

import {ItemTypePropType, EndpointPropType} from '../prop-types';
import PullRequestPatchContainer from './pr-patch-container';
import MultiFilePatchController from '../controllers/multi-file-patch-controller';
import LoadingView from '../views/loading-view';
import ErrorView from '../views/error-view';

export default class PullRequestChangedFilesContainer extends React.Component {
  static propTypes = {
    // Pull request properties
    owner: PropTypes.string.isRequired,
    repo: PropTypes.string.isRequired,
    number: PropTypes.number.isRequired,

    // Connection properties
    endpoint: EndpointPropType.isRequired,
    token: PropTypes.string.isRequired,

    // Item context
    itemType: ItemTypePropType.isRequired,

    // action methods
    destroy: PropTypes.func.isRequired,

    // Atom environment
    workspace: PropTypes.object.isRequired,
    commands: PropTypes.object.isRequired,
    keymaps: PropTypes.object.isRequired,
    tooltips: PropTypes.object.isRequired,
    config: PropTypes.object.isRequired,

    // local repo as opposed to pull request repo
    localRepository: PropTypes.object.isRequired,
    workdirPath: PropTypes.string,

    // Review comment threads
    reviewCommentsLoading: PropTypes.bool.isRequired,
    reviewCommentThreads: PropTypes.arrayOf(PropTypes.shape({
      thread: PropTypes.object.isRequired,
      comments: PropTypes.arrayOf(PropTypes.object).isRequired,
    })).isRequired,

    // refetch diff on refresh
    shouldRefetch: PropTypes.bool.isRequired,

    // For opening files changed tab
    initChangedFilePath: PropTypes.string,
    initChangedFilePosition: PropTypes.number,
    onOpenFilesTab: PropTypes.func.isRequired,
  }

  constructor(props) {
    super(props);

    this.lastPatch = {
      patch: null,
      subs: new CompositeDisposable(),
    };
  }

  componentWillUnmount() {
    this.lastPatch.subs.dispose();
  }

  render() {
    const patchProps = {
      owner: this.props.owner,
      repo: this.props.repo,
      number: this.props.number,
      endpoint: this.props.endpoint,
      token: this.props.token,
      refetch: this.props.shouldRefetch,
    };

    return (
      <PullRequestPatchContainer {...patchProps}>
        {this.renderPatchResult}
      </PullRequestPatchContainer>
    );
  }

  renderPatchResult = (error, multiFilePatch) => {
    if (error === null && multiFilePatch === null) {
      return <LoadingView />;
    }

    if (error !== null) {
      return <ErrorView descriptions={[error]} />;
    }

    if (multiFilePatch !== this.lastPatch.patch) {
      this.lastPatch.subs.dispose();

      this.lastPatch = {
        subs: new CompositeDisposable(
          ...multiFilePatch.getFilePatches().map(fp => fp.onDidChangeRenderStatus(() => this.forceUpdate())),
        ),
        patch: multiFilePatch,
      };
    }

    return (
      <MultiFilePatchController
        multiFilePatch={multiFilePatch}
        repository={this.props.localRepository}
        reviewCommentsLoading={this.props.reviewCommentsLoading}
        reviewCommentThreads={this.props.reviewCommentThreads}
        {...this.props}
      />
    );
  }
}
