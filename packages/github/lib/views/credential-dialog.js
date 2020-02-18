import React from 'react';
import PropTypes from 'prop-types';

import DialogView from './dialog-view';
import TabGroup from '../tab-group';
import {TabbableInput, TabbableButton} from './tabbable';

export default class CredentialDialog extends React.Component {
  static propTypes = {
    // Model
    request: PropTypes.shape({
      getParams: PropTypes.func.isRequired,
      accept: PropTypes.func.isRequired,
      cancel: PropTypes.func.isRequired,
    }).isRequired,
    inProgress: PropTypes.bool,
    error: PropTypes.instanceOf(Error),

    // Atom environment
    workspace: PropTypes.object.isRequired,
    commands: PropTypes.object.isRequired,
  }

  constructor(props) {
    super(props);

    this.tabGroup = new TabGroup();

    this.state = {
      username: '',
      password: '',
      remember: false,
      showPassword: false,
    };
  }

  render() {
    const request = this.props.request;
    const params = request.getParams();

    return (
      <DialogView
        prompt={params.prompt}
        acceptEnabled={this.canSignIn()}
        acceptText="Sign in"
        accept={this.accept}
        cancel={request.cancel}
        tabGroup={this.tabGroup}
        inProgress={this.props.inProgress}
        error={this.props.error}
        workspace={this.props.workspace}
        commands={this.props.commands}>

        {params.includeUsername && (
          <label className="github-DialogLabel github-DialogLabel--horizontal">
            Username:
            <TabbableInput
              tabGroup={this.tabGroup}
              commands={this.props.commands}
              autofocus
              type="text"
              className="input-text native-key-bindings github-Credential-username"
              value={this.state.username}
              onChange={this.didChangeUsername}
            />
          </label>
        )}
        <label className="github-DialogLabel github-DialogLabel--horizontal">
          Password:
          <TabbableInput
            tabGroup={this.tabGroup}
            commands={this.props.commands}
            autofocus
            type={this.state.showPassword ? 'text' : 'password'}
            className="input-text native-key-bindings github-Credential-password"
            value={this.state.password}
            onChange={this.didChangePassword}
          />
          <TabbableButton
            tabGroup={this.tabGroup}
            commands={this.props.commands}
            className="github-Dialog--insetButton github-Credential-visibility"
            onClick={this.toggleShowPassword}>
            {this.state.showPassword ? 'Hide' : 'Show'}
          </TabbableButton>
        </label>
        {params.includeRemember && (
          <label className="github-DialogLabel github-DialogLabel--horizontal github-Credential-rememberLabel">
            <TabbableInput
              tabGroup={this.tabGroup}
              commands={this.props.commands}
              className="input-checkbox github-Credential-remember"
              type="checkbox"
              checked={this.state.remember}
              onChange={this.didChangeRemember}
            />
            Remember
          </label>
        )}

      </DialogView>
    );
  }

  componentDidMount() {
    this.tabGroup.autofocus();
  }

  accept = () => {
    if (!this.canSignIn()) {
      return Promise.resolve();
    }

    const request = this.props.request;
    const params = request.getParams();

    const payload = {password: this.state.password};

    if (params.includeUsername) {
      payload.username = this.state.username;
    }

    if (params.includeRemember) {
      payload.remember = this.state.remember;
    }

    return request.accept(payload);
  }

  didChangeUsername = e => this.setState({username: e.target.value});

  didChangePassword = e => this.setState({password: e.target.value});

  didChangeRemember = e => this.setState({remember: e.target.checked});

  toggleShowPassword = () => this.setState({showPassword: !this.state.showPassword});

  canSignIn() {
    return !this.props.request.getParams().includeUsername || this.state.username.length > 0;
  }
}
