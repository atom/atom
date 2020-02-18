import React, {Fragment} from 'react';
import PropTypes from 'prop-types';
import Select from 'react-select';

import Commands, {Command} from '../atom/commands';
import AtomTextEditor from '../atom/atom-text-editor';
import RefHolder from '../models/ref-holder';
import {RefHolderPropType} from '../prop-types';
import {unusedProps} from '../helpers';

export function makeTabbable(Component, options = {}) {
  return class extends React.Component {
    static propTypes = {
      tabGroup: PropTypes.shape({
        appendElement: PropTypes.func.isRequired,
        removeElement: PropTypes.func.isRequired,
        focusAfter: PropTypes.func.isRequired,
        focusBefore: PropTypes.func.isRequired,
      }).isRequired,
      autofocus: PropTypes.bool,

      commands: PropTypes.object.isRequired,
    }

    static defaultProps = {
      autofocus: false,
    }

    constructor(props) {
      super(props);

      this.rootRef = new RefHolder();
      this.elementRef = new RefHolder();

      if (options.rootRefProp) {
        this.rootRef = new RefHolder();
        this.rootRefProps = {[options.rootRefProp]: this.rootRef};
      } else {
        this.rootRef = this.elementRef;
        this.rootRefProps = {};
      }

      if (options.passCommands) {
        this.commandProps = {commands: this.props.commands};
      } else {
        this.commandProps = {};
      }
    }

    render() {
      return (
        <Fragment>
          <Commands registry={this.props.commands} target={this.rootRef}>
            <Command command="core:focus-next" callback={this.focusNext} />
            <Command command="core:focus-previous" callback={this.focusPrevious} />
          </Commands>
          <Component
            ref={this.elementRef.setter}
            tabIndex={-1}
            {...unusedProps(this.props, this.constructor.propTypes)}
            {...this.rootRefProps}
            {...this.commandProps}
          />
        </Fragment>
      );
    }

    componentDidMount() {
      this.elementRef.map(element => this.props.tabGroup.appendElement(element, this.props.autofocus));
    }

    componentWillUnmount() {
      this.elementRef.map(element => this.props.tabGroup.removeElement(element));
    }

    focusNext = e => {
      this.elementRef.map(element => this.props.tabGroup.focusAfter(element));
      e.stopPropagation();
    }

    focusPrevious = e => {
      this.elementRef.map(element => this.props.tabGroup.focusBefore(element));
      e.stopPropagation();
    }
  };
}

export const TabbableInput = makeTabbable('input');

export const TabbableButton = makeTabbable('button');

export const TabbableSummary = makeTabbable('summary');

export const TabbableTextEditor = makeTabbable(AtomTextEditor, {rootRefProp: 'refElement'});

// CustomEvent is a DOM primitive, which v8 can't access
// so we're essentially lazy loading to keep snapshotting from breaking.
let FakeKeyDownEvent;

class WrapSelect extends React.Component {
  static propTypes = {
    refElement: RefHolderPropType.isRequired,
    commands: PropTypes.object.isRequired,
  }

  constructor(props) {
    super(props);

    this.refSelect = new RefHolder();
  }

  render() {
    return (
      <div className="github-TabbableWrapper" ref={this.props.refElement.setter}>
        <Commands registry={this.props.commands} target={this.props.refElement}>
          <Command command="github:selectbox-down" callback={this.proxyKeyCode(40)} />
          <Command command="github:selectbox-up" callback={this.proxyKeyCode(38)} />
          <Command command="github:selectbox-enter" callback={this.proxyKeyCode(13)} />
          <Command command="github:selectbox-tab" callback={this.proxyKeyCode(9)} />
          <Command command="github:selectbox-backspace" callback={this.proxyKeyCode(8)} />
          <Command command="github:selectbox-pageup" callback={this.proxyKeyCode(33)} />
          <Command command="github:selectbox-pagedown" callback={this.proxyKeyCode(34)} />
          <Command command="github:selectbox-end" callback={this.proxyKeyCode(35)} />
          <Command command="github:selectbox-home" callback={this.proxyKeyCode(36)} />
          <Command command="github:selectbox-delete" callback={this.proxyKeyCode(46)} />
          <Command command="github:selectbox-escape" callback={this.proxyKeyCode(27)} />
        </Commands>
        <Select
          ref={this.refSelect.setter}
          {...unusedProps(this.props, this.constructor.propTypes)}
        />
      </div>
    );
  }

  focus() {
    return this.refSelect.map(select => select.focus());
  }

  proxyKeyCode(keyCode) {
    return e => this.refSelect.map(select => {
      if (!FakeKeyDownEvent) {
        FakeKeyDownEvent = class extends CustomEvent {
          constructor(kCode) {
            super('keydown');
            this.keyCode = kCode;
          }
        };
      }

      const fakeEvent = new FakeKeyDownEvent(keyCode);
      select.handleKeyDown(fakeEvent);
      return null;
    });
  }
}

export const TabbableSelect = makeTabbable(WrapSelect, {rootRefProp: 'refElement', passCommands: true});
