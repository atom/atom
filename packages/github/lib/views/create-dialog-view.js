import React from 'react';
import PropTypes from 'prop-types';

import DialogView from './dialog-view';
import RepositoryHomeSelectionView from './repository-home-selection-view';
import DirectorySelect from './directory-select';
import RemoteConfigurationView from './remote-configuration-view';
import TabGroup from '../tab-group';
import {TabbableInput} from './tabbable';
import Octicon from '../atom/octicon';

const DIALOG_TEXT = {
  create: {
    heading: 'Create GitHub repository',
    hostPath: 'Destination path:',
    progressMessage: 'Creating repository...',
    acceptText: 'Create',
  },
  publish: {
    heading: 'Publish GitHub repository',
    hostPath: 'Local path:',
    progressMessage: 'Publishing repository...',
    acceptText: 'Publish',
  },
};

export default class CreateDialogView extends React.Component {
  static propTypes = {
    // Relay
    user: PropTypes.object,

    // Model
    request: PropTypes.shape({
      identifier: PropTypes.oneOf(['create', 'publish']).isRequired,
      getParams: PropTypes.func.isRequired,
      cancel: PropTypes.func.isRequired,
    }).isRequired,
    error: PropTypes.instanceOf(Error),
    isLoading: PropTypes.bool.isRequired,
    inProgress: PropTypes.bool.isRequired,
    selectedOwnerID: PropTypes.string.isRequired,
    repoName: PropTypes.object.isRequired,
    selectedVisibility: PropTypes.oneOf(['PUBLIC', 'PRIVATE']).isRequired,
    localPath: PropTypes.object.isRequired,
    sourceRemoteName: PropTypes.object.isRequired,
    selectedProtocol: PropTypes.oneOf(['https', 'ssh']).isRequired,
    acceptEnabled: PropTypes.bool.isRequired,

    // Change callbacks
    didChangeOwnerID: PropTypes.func.isRequired,
    didChangeVisibility: PropTypes.func.isRequired,
    didChangeProtocol: PropTypes.func.isRequired,
    accept: PropTypes.func.isRequired,

    // Atom environment
    currentWindow: PropTypes.object.isRequired,
    workspace: PropTypes.object.isRequired,
    commands: PropTypes.object.isRequired,
    config: PropTypes.object.isRequired,
  }

  constructor(props) {
    super(props);

    this.tabGroup = new TabGroup();
  }

  render() {
    const text = DIALOG_TEXT[this.props.request.identifier];

    return (
      <DialogView
        progressMessage={text.progressMessage}
        acceptEnabled={this.props.acceptEnabled}
        acceptText={text.acceptText}
        accept={this.props.accept}
        cancel={this.props.request.cancel}
        tabGroup={this.tabGroup}
        inProgress={this.props.inProgress}
        error={this.props.error}
        workspace={this.props.workspace}
        commands={this.props.commands}>

        <h1 className="github-Create-header">
          <Octicon icon="globe" />
          {text.heading}
        </h1>
        <div className="github-Create-repo block">
          <RepositoryHomeSelectionView
            tabGroup={this.tabGroup}
            commands={this.props.commands}
            autofocusName
            user={this.props.user}
            nameBuffer={this.props.repoName}
            selectedOwnerID={this.props.selectedOwnerID}
            didChangeOwnerID={this.props.didChangeOwnerID}
            isLoading={this.props.isLoading}
          />
        </div>
        <div className="github-Create-visibility block">
          <span className="github-Create-visibilityHeading">Visibility:</span>
          <label className="github-Create-visibilityOption input-label">
            <TabbableInput
              tabGroup={this.tabGroup}
              commands={this.props.commands}
              className="input-radio"
              type="radio"
              name="visibility"
              value="PUBLIC"
              checked={this.props.selectedVisibility === 'PUBLIC'}
              onChange={this.didChangeVisibility}
            />
            <Octicon icon="globe" />
            Public
          </label>
          <label className="github-Create-visibilityOption input-label">
            <TabbableInput
              tabGroup={this.tabGroup}
              commands={this.props.commands}
              className="input-radio"
              type="radio"
              name="visibility"
              value="PRIVATE"
              checked={this.props.selectedVisibility === 'PRIVATE'}
              onChange={this.didChangeVisibility}
            />
            <Octicon icon="mirror-private" />
            Private
          </label>
        </div>
        <div className="github-Create-localPath">
          <DirectorySelect
            tabGroup={this.tabGroup}
            commands={this.props.commands}
            currentWindow={this.props.currentWindow}
            buffer={this.props.localPath}
            disabled={this.props.request.identifier === 'publish'}
          />
        </div>
        <RemoteConfigurationView
          tabGroup={this.tabGroup}
          commands={this.props.commands}
          currentProtocol={this.props.selectedProtocol}
          didChangeProtocol={this.props.didChangeProtocol}
          sourceRemoteBuffer={this.props.sourceRemoteName}
        />

      </DialogView>
    );
  }

  componentDidMount() {
    this.tabGroup.autofocus();
  }

  didChangeVisibility = event => this.props.didChangeVisibility(event.target.value);
}
