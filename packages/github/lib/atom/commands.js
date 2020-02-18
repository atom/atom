import React from 'react';
import PropTypes from 'prop-types';
import {Disposable} from 'event-kit';

import {DOMNodePropType, RefHolderPropType} from '../prop-types';
import RefHolder from '../models/ref-holder';

export default class Commands extends React.Component {
  static propTypes = {
    registry: PropTypes.object.isRequired,
    target: PropTypes.oneOfType([
      PropTypes.string,
      DOMNodePropType,
      RefHolderPropType,
    ]).isRequired,
    children: PropTypes.oneOfType([
      PropTypes.element,
      PropTypes.arrayOf(PropTypes.element),
    ]).isRequired,
  }

  render() {
    const {registry, target} = this.props;
    return (
      <div>
        {React.Children.map(this.props.children, child => {
          return child ? React.cloneElement(child, {registry, target}) : null;
        })}
      </div>
    );
  }
}

export class Command extends React.Component {
  static propTypes = {
    registry: PropTypes.object,
    target: PropTypes.oneOfType([
      PropTypes.string,
      DOMNodePropType,
      RefHolderPropType,
    ]),
    command: PropTypes.string.isRequired,
    callback: PropTypes.func.isRequired,
  }

  constructor(props, context) {
    super(props, context);
    this.subTarget = new Disposable();
    this.subCommand = new Disposable();
  }

  componentDidMount() {
    this.observeTarget(this.props);
  }

  componentWillReceiveProps(newProps) {
    if (['registry', 'target', 'command', 'callback'].some(p => newProps[p] !== this.props[p])) {
      this.observeTarget(newProps);
    }
  }

  componentWillUnmount() {
    this.subTarget.dispose();
    this.subCommand.dispose();
  }

  observeTarget(props) {
    this.subTarget.dispose();
    this.subTarget = RefHolder.on(props.target).observe(t => this.registerCommand(t, props));
  }

  registerCommand(target, {registry, command, callback}) {
    this.subCommand.dispose();
    this.subCommand = registry.add(target, command, callback);
  }

  render() {
    return null;
  }
}
