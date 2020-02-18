import React from 'react';
import PropTypes from 'prop-types';
import {createFragmentContainer, graphql} from 'react-relay';
import {TextBuffer} from 'atom';
import {CompositeDisposable} from 'event-kit';
import path from 'path';

import CreateDialogView from '../views/create-dialog-view';

export class BareCreateDialogController extends React.Component {
  static propTypes = {
    // Relay
    user: PropTypes.shape({
      id: PropTypes.string.isRequired,
    }),

    // Model
    request: PropTypes.shape({
      getParams: PropTypes.func.isRequired,
      accept: PropTypes.func.isRequired,
    }).isRequired,
    error: PropTypes.instanceOf(Error),
    isLoading: PropTypes.bool.isRequired,
    inProgress: PropTypes.bool.isRequired,

    // Atom environment
    currentWindow: PropTypes.object.isRequired,
    workspace: PropTypes.object.isRequired,
    commands: PropTypes.object.isRequired,
    config: PropTypes.object.isRequired,
  }

  constructor(props) {
    super(props);

    const {localDir} = this.props.request.getParams();

    this.projectHome = this.props.config.get('core.projectHome');
    this.modified = {
      repoName: false,
      localPath: false,
    };

    this.repoName = new TextBuffer({
      text: localDir ? path.basename(localDir) : '',
    });
    this.localPath = new TextBuffer({
      text: localDir || this.projectHome,
    });
    this.sourceRemoteName = new TextBuffer({
      text: this.props.config.get('github.sourceRemoteName'),
    });

    this.subs = new CompositeDisposable(
      this.repoName.onDidChange(this.didChangeRepoName),
      this.localPath.onDidChange(this.didChangeLocalPath),
      this.sourceRemoteName.onDidChange(this.didChangeSourceRemoteName),
      this.props.config.onDidChange('github.sourceRemoteName', this.readSourceRemoteNameSetting),
      this.props.config.onDidChange('github.remoteFetchProtocol', this.readRemoteFetchProtocolSetting),
    );

    this.state = {
      acceptEnabled: this.acceptIsEnabled(),
      selectedVisibility: 'PUBLIC',
      selectedProtocol: this.props.config.get('github.remoteFetchProtocol'),
      selectedOwnerID: this.props.user ? this.props.user.id : '',
    };
  }

  render() {
    return (
      <CreateDialogView
        selectedOwnerID={this.state.selectedOwnerID}
        repoName={this.repoName}
        selectedVisibility={this.state.selectedVisibility}
        localPath={this.localPath}
        sourceRemoteName={this.sourceRemoteName}
        selectedProtocol={this.state.selectedProtocol}
        didChangeOwnerID={this.didChangeOwnerID}
        didChangeVisibility={this.didChangeVisibility}
        didChangeProtocol={this.didChangeProtocol}
        acceptEnabled={this.state.acceptEnabled}
        accept={this.accept}
        {...this.props}
      />
    );
  }

  componentDidUpdate(prevProps) {
    if (this.props.user !== prevProps.user) {
      this.recheckAcceptEnablement();
    }
  }

  componentWillUnmount() {
    this.subs.dispose();
  }

  didChangeRepoName = () => {
    this.modified.repoName = true;
    if (!this.modified.localPath) {
      if (this.localPath.getText() === this.projectHome) {
        this.localPath.setText(path.join(this.projectHome, this.repoName.getText()));
      } else {
        const dirName = path.dirname(this.localPath.getText());
        this.localPath.setText(path.join(dirName, this.repoName.getText()));
      }
      this.modified.localPath = false;
    }
    this.recheckAcceptEnablement();
  }

  didChangeOwnerID = ownerID => new Promise(resolve => this.setState({selectedOwnerID: ownerID}, resolve))

  didChangeLocalPath = () => {
    this.modified.localPath = true;
    if (!this.modified.repoName) {
      this.repoName.setText(path.basename(this.localPath.getText()));
      this.modified.repoName = false;
    }
    this.recheckAcceptEnablement();
  }

  didChangeVisibility = visibility => {
    return new Promise(resolve => this.setState({selectedVisibility: visibility}, resolve));
  }

  didChangeSourceRemoteName = () => {
    this.writeSourceRemoteNameSetting();
    this.recheckAcceptEnablement();
  }

  didChangeProtocol = async protocol => {
    await new Promise(resolve => this.setState({selectedProtocol: protocol}, resolve));
    this.writeRemoteFetchProtocolSetting(protocol);
  }

  readSourceRemoteNameSetting = ({newValue}) => {
    if (newValue !== this.sourceRemoteName.getText()) {
      this.sourceRemoteName.setText(newValue);
    }
  }

  writeSourceRemoteNameSetting() {
    if (this.props.config.get('github.sourceRemoteName') !== this.sourceRemoteName.getText()) {
      this.props.config.set('github.sourceRemoteName', this.sourceRemoteName.getText());
    }
  }

  readRemoteFetchProtocolSetting = ({newValue}) => {
    if (newValue !== this.state.selectedProtocol) {
      this.setState({selectedProtocol: newValue});
    }
  }

  writeRemoteFetchProtocolSetting(protocol) {
    if (this.props.config.get('github.remoteFetchProtocol') !== protocol) {
      this.props.config.set('github.remoteFetchProtocol', protocol);
    }
  }

  acceptIsEnabled() {
    return !this.repoName.isEmpty() &&
      !this.localPath.isEmpty() &&
      !this.sourceRemoteName.isEmpty() &&
      this.props.user !== null;
  }

  recheckAcceptEnablement() {
    const nextEnablement = this.acceptIsEnabled();
    if (nextEnablement !== this.state.acceptEnabled) {
      this.setState({acceptEnabled: nextEnablement});
    }
  }

  accept = () => {
    if (!this.acceptIsEnabled()) {
      return Promise.resolve();
    }

    const ownerID = this.state.selectedOwnerID !== '' ? this.state.selectedOwnerID : this.props.user.id;

    return this.props.request.accept({
      ownerID,
      name: this.repoName.getText(),
      visibility: this.state.selectedVisibility,
      localPath: this.localPath.getText(),
      protocol: this.state.selectedProtocol,
      sourceRemoteName: this.sourceRemoteName.getText(),
    });
  }
}

export default createFragmentContainer(BareCreateDialogController, {
  user: graphql`
    fragment createDialogController_user on User
    @argumentDefinitions(
      organizationCount: {type: "Int!"}
      organizationCursor: {type: "String"}
    ) {
      id
      ...repositoryHomeSelectionView_user @arguments(
        organizationCount: $organizationCount
        organizationCursor: $organizationCursor
      )
    }
  `,
});
