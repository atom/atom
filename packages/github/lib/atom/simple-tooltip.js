import React from 'react';
import ReactDOM from 'react-dom';
import PropTypes from 'prop-types';

export default class SimpleTooltip extends React.Component {
  static propTypes = {
    tooltips: PropTypes.object.isRequired,
    children: PropTypes.node.isRequired,
    title: PropTypes.string.isRequired,
  }

  componentDidMount() {
    this.disposable = this.props.tooltips.add(ReactDOM.findDOMNode(this.child), {title: () => this.props.title});
  }

  componentWillUnmount() {
    this.disposable.dispose();
  }

  componentDidUpdate(prevProps) {
    if (prevProps.title !== this.props.title) {
      this.disposable.dispose();
      this.disposable = this.props.tooltips.add(ReactDOM.findDOMNode(this.child), {title: () => this.props.title});
    }
  }

  render() {
    const child = React.Children.only(this.props.children);
    return React.cloneElement(child, {ref: e => { this.child = e; }});
  }
}
