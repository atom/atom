import React from 'react';
import PropTypes from 'prop-types';
import cx from 'classnames';

import {TabbableInput, TabbableSummary, TabbableTextEditor} from './tabbable';

export default class RemoteConfigurationView extends React.Component {
  static propTypes = {
    tabGroup: PropTypes.object.isRequired,
    currentProtocol: PropTypes.oneOf(['https', 'ssh']),
    sourceRemoteBuffer: PropTypes.object.isRequired,
    didChangeProtocol: PropTypes.func.isRequired,

    // Atom environment
    commands: PropTypes.object.isRequired,
  }

  render() {
    const httpsClassName = cx(
      'github-RemoteConfiguration-protocolOption',
      'github-RemoteConfiguration-protocolOption--https',
      'input-label',
    );

    const sshClassName = cx(
      'github-RemoteConfiguration-protocolOption',
      'github-RemoteConfiguration-protocolOption--ssh',
      'input-label',
    );

    return (
      <details className="github-RemoteConfiguration-details block">
        <TabbableSummary tabGroup={this.props.tabGroup} commands={this.props.commands}>Advanced</TabbableSummary>
        <main>
          <div className="github-RemoteConfiguration-protocol block">
            <span className="github-RemoteConfiguration-protocolHeading">Protocol:</span>
            <label className={httpsClassName}>
              <TabbableInput
                tabGroup={this.props.tabGroup}
                commands={this.props.commands}
                className="input-radio"
                type="radio"
                name="protocol"
                value="https"
                checked={this.props.currentProtocol === 'https'}
                onChange={this.handleProtocolChange}
              />
              HTTPS
            </label>
            <label className={sshClassName}>
              <TabbableInput
                tabGroup={this.props.tabGroup}
                commands={this.props.commands}
                className="input-radio"
                type="radio"
                name="protocol"
                value="ssh"
                checked={this.props.currentProtocol === 'ssh'}
                onChange={this.handleProtocolChange}
              />
              SSH
            </label>
          </div>
          <div className="github-RemoteConfiguration-sourceRemote block">
            <label className="input-label">Source remote name:
              <TabbableTextEditor
                tabGroup={this.props.tabGroup}
                commands={this.props.commands}
                className="github-RemoteConfiguration-sourceRemoteName"
                mini={true}
                autoWidth={false}
                buffer={this.props.sourceRemoteBuffer}
              />
            </label>
          </div>
        </main>
      </details>
    );
  }

  handleProtocolChange = event => {
    this.props.didChangeProtocol(event.target.value);
  }
}
