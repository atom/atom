import React from 'react';
import PropTypes from 'prop-types';
import {humanizeKeystroke} from 'underscore-plus';
import {Disposable} from 'event-kit';

import {autobind} from '../helpers';
import {RefHolderPropType} from '../prop-types';

export default class Keystroke extends React.Component {
  static propTypes = {
    keymaps: PropTypes.shape({
      findKeyBindings: PropTypes.func.isRequired,
    }).isRequired,
    command: PropTypes.string.isRequired,
    refTarget: RefHolderPropType,
  }

  constructor(props) {
    super(props);
    autobind(this, 'didChangeTarget');

    this.sub = new Disposable();
    this.state = {keybinding: null};
  }

  componentDidMount() {
    this.observeTarget();
  }

  componentDidUpdate(prevProps, prevState) {
    if (this.props.refTarget !== prevProps.refTarget) {
      this.observeTarget();
    } else if (this.props.command !== prevProps.command) {
      this.didChangeTarget(this.props.refTarget.getOr(null));
    }
  }

  componentWillUnmount() {
    this.sub.dispose();
  }

  render() {
    if (!this.state.keybinding) {
      return null;
    }

    return <span className="keystroke">{humanizeKeystroke(this.state.keybinding.keystrokes)}</span>;
  }

  observeTarget() {
    this.sub.dispose();
    if (this.props.refTarget) {
      this.sub = this.props.refTarget.observe(this.didChangeTarget);
    } else {
      this.didChangeTarget(null);
    }
  }

  didChangeTarget(target) {
    const [keybinding] = this.props.keymaps.findKeyBindings({
      command: this.props.command,
      target,
    });
    this.setState({keybinding});
  }
}
