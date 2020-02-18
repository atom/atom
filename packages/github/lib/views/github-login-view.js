import React from 'react';
import PropTypes from 'prop-types';

import {autobind} from '../helpers';

export default class GithubLoginView extends React.Component {
  static propTypes = {
    children: PropTypes.node,
    onLogin: PropTypes.func,
  }

  static defaultProps = {
    children:
  <div className="initialize-repo-description">
    <span>Log in to GitHub to access PR information and more!</span>
  </div>,
    onLogin: token => {},
  }

  constructor(props, context) {
    super(props, context);
    autobind(
      this,
      'handleLoginClick', 'handleCancelTokenClick', 'handleSubmitTokenClick', 'handleSubmitToken', 'handleTokenChange',
    );
    this.state = {
      loggingIn: false,
      token: '',
    };
  }

  render() {
    let subview;
    if (this.state.loggingIn) {
      subview = this.renderTokenInput();
    } else {
      subview = this.renderLogin();
    }

    return (
      <div className="github-GithubLoginView">
        {subview}
      </div>
    );
  }

  renderLogin() {
    return (
      <div className="github-GithubLoginView-Subview">
        <div className="github-GitHub-LargeIcon icon icon-mark-github" />
        <h1>Log in to GitHub</h1>
        {this.props.children}
        <button onClick={this.handleLoginClick} className="btn btn-primary icon icon-octoface">
          Login
        </button>
      </div>
    );
  }

  renderTokenInput() {
    return (
      <form className="github-GithubLoginView-Subview" onSubmit={this.handleSubmitToken}>
        <div className="github-GitHub-LargeIcon icon icon-mark-github" />
        <h1>Enter Token</h1>
        <ol>
          <li>Visit <a href="https://github.atom.io/login">github.atom.io/login</a> to generate
          an authentication token.</li>
          <li>Enter the token below:</li>
        </ol>

        <input
          type="text"
          className="input-text native-key-bindings"
          placeholder="Enter your token..."
          value={this.state.token}
          onChange={this.handleTokenChange}
        />
        <ul>
          <li>
            <button type="button" onClick={this.handleCancelTokenClick} className="btn icon icon-remove-close">
              Cancel
            </button>
          </li>
          <li>
            <button
              type="submit" onClick={this.handleSubmitTokenClick} className="btn btn-primary icon icon-check">
                Login
            </button>
          </li>
        </ul>
      </form>
    );
  }

  handleLoginClick() {
    this.setState({loggingIn: true});
  }

  handleCancelTokenClick(e) {
    e.preventDefault();
    this.setState({loggingIn: false});
  }

  handleSubmitTokenClick(e) {
    e.preventDefault();
    this.handleSubmitToken();
  }

  handleSubmitToken() {
    this.props.onLogin(this.state.token);
  }

  handleTokenChange(e) {
    this.setState({token: e.target.value});
  }
}
