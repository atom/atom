import path from 'path';
import React from 'react';
import PropTypes from 'prop-types';
import yubikiri from 'yubikiri';
import {CompositeDisposable} from 'event-kit';

import ObserveModel from '../views/observe-model';
import ResolutionProgress from '../models/conflicts/resolution-progress';
import EditorConflictController from './editor-conflict-controller';

const DEFAULT_REPO_DATA = {
  mergeConflictPaths: [],
  isRebasing: false,
};

/**
 * Render an `EditorConflictController` for each `TextEditor` open on a file that contains git conflict markers.
 */
export default class RepositoryConflictController extends React.Component {
  static propTypes = {
    workspace: PropTypes.object.isRequired,
    commands: PropTypes.object.isRequired,
    config: PropTypes.object.isRequired,
    resolutionProgress: PropTypes.object.isRequired,
    repository: PropTypes.object.isRequired,
    refreshResolutionProgress: PropTypes.func,
  };

  static defaultProps = {
    refreshResolutionProgress: () => {},
    resolutionProgress: new ResolutionProgress(),
  };

  constructor(props, context) {
    super(props, context);

    this.state = {openEditors: this.props.workspace.getTextEditors()};
    this.subscriptions = new CompositeDisposable();
  }

  componentDidMount() {
    const updateState = () => {
      this.setState({
        openEditors: this.props.workspace.getTextEditors(),
      });
    };

    this.subscriptions.add(
      this.props.workspace.observeTextEditors(updateState),
      this.props.workspace.onDidDestroyPaneItem(updateState),
      this.props.config.observe('github.graphicalConflictResolution', () => this.forceUpdate()),
    );
  }

  fetchData = repository => {
    return yubikiri({
      workingDirectoryPath: repository.getWorkingDirectoryPath(),
      mergeConflictPaths: repository.getMergeConflicts().then(conflicts => {
        return conflicts.map(conflict => conflict.filePath);
      }),
      isRebasing: repository.isRebasing(),
    });
  }

  render() {
    return (
      <ObserveModel model={this.props.repository} fetchData={this.fetchData}>
        {data => this.renderWithData(data || DEFAULT_REPO_DATA)}
      </ObserveModel>
    );
  }

  renderWithData(repoData) {
    const conflictingEditors = this.getConflictingEditors(repoData);

    return (
      <div>
        {conflictingEditors.map(editor => (
          <EditorConflictController
            key={editor.id}
            commands={this.props.commands}
            resolutionProgress={this.props.resolutionProgress}
            editor={editor}
            isRebase={repoData.isRebasing}
            refreshResolutionProgress={this.props.refreshResolutionProgress}
          />
        ))}
      </div>
    );
  }

  getConflictingEditors(repoData) {
    if (
      repoData.mergeConflictPaths.length === 0 ||
      this.state.openEditors.length === 0 ||
      !this.props.config.get('github.graphicalConflictResolution')
    ) {
      return [];
    }

    const commonBasePath = this.props.repository.getWorkingDirectoryPath();
    const fullMergeConflictPaths = new Set(
      repoData.mergeConflictPaths.map(relativePath => path.join(commonBasePath, relativePath)),
    );

    return this.state.openEditors.filter(editor => fullMergeConflictPaths.has(editor.getPath()));
  }

  componentWillUnmount() {
    this.subscriptions.dispose();
  }
}
