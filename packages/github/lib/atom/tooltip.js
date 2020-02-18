import React from 'react';
import ReactDOM from 'react-dom';
import PropTypes from 'prop-types';
import {Disposable} from 'event-kit';

import {RefHolderPropType} from '../prop-types';
import {createItem} from '../helpers';

const VERBATIM_OPTION_PROPS = [
  'title', 'html', 'placement', 'trigger', 'keyBindingCommand', 'keyBindingTarget',
];

const OPTION_PROPS = [
  ...VERBATIM_OPTION_PROPS,
  'tooltips', 'className', 'showDelay', 'hideDelay',
];

export default class Tooltip extends React.Component {
  static propTypes = {
    manager: PropTypes.object.isRequired,
    target: RefHolderPropType.isRequired,
    title: PropTypes.oneOfType([
      PropTypes.string,
      PropTypes.func,
    ]),
    html: PropTypes.bool,
    className: PropTypes.string,
    placement: PropTypes.oneOfType([
      PropTypes.string,
      PropTypes.func,
    ]),
    trigger: PropTypes.oneOf(['hover', 'click', 'focus', 'manual']),
    showDelay: PropTypes.number,
    hideDelay: PropTypes.number,
    keyBindingCommand: PropTypes.string,
    keyBindingTarget: PropTypes.element,
    children: PropTypes.element,
    itemHolder: RefHolderPropType,
    tooltipHolder: RefHolderPropType,
  }

  static defaultProps = {
    getItemComponent: () => {},
  }

  constructor(props, context) {
    super(props, context);

    this.refSub = new Disposable();
    this.tipSub = new Disposable();

    this.domNode = null;
    if (this.props.children !== undefined) {
      this.domNode = document.createElement('div');
      this.domNode.className = 'react-atom-tooltip';
    }

    this.lastTooltipProps = {};
  }

  componentDidMount() {
    this.setupTooltip();
  }

  render() {
    if (this.props.children !== undefined) {
      return ReactDOM.createPortal(
        this.props.children,
        this.domNode,
      );
    } else {
      return null;
    }
  }

  componentDidUpdate() {
    if (this.shouldRecreateTooltip()) {
      this.refSub.dispose();
      this.tipSub.dispose();
      this.setupTooltip();
    }
  }

  componentWillUnmount() {
    this.refSub.dispose();
    this.tipSub.dispose();
  }

  getTooltipProps() {
    const p = {};
    for (const key of OPTION_PROPS) {
      p[key] = this.props[key];
    }
    return p;
  }

  shouldRecreateTooltip() {
    return OPTION_PROPS.some(key => this.lastTooltipProps[key] !== this.props[key]);
  }

  setupTooltip() {
    this.lastTooltipProps = this.getTooltipProps();

    const options = {};
    VERBATIM_OPTION_PROPS.forEach(key => {
      if (this.props[key] !== undefined) {
        options[key] = this.props[key];
      }
    });
    if (this.props.className !== undefined) {
      options.class = this.props.className;
    }
    if (this.props.showDelay !== undefined || this.props.hideDelay !== undefined) {
      const delayDefaults = (this.props.trigger === 'hover' || this.props.trigger === undefined)
        && {show: 1000, hide: 100}
        || {show: 0, hide: 0};

      options.delay = {
        show: this.props.showDelay !== undefined ? this.props.showDelay : delayDefaults.show,
        hide: this.props.hideDelay !== undefined ? this.props.hideDelay : delayDefaults.hide,
      };
    }
    if (this.props.children !== undefined) {
      options.item = createItem(this.domNode, this.props.itemHolder);
    }

    this.refSub = this.props.target.observe(t => {
      this.tipSub.dispose();
      this.tipSub = this.props.manager.add(t, options);
      const h = this.props.tooltipHolder;
      if (h) {
        h.setter(this.tipSub);
      }
    });
  }
}
