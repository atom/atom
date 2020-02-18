import React from 'react';
import PropTypes from 'prop-types';

export default class ContextMenuInterceptor extends React.Component {
  static propTypes = {
    onWillShowContextMenu: PropTypes.func.isRequired,
    children: PropTypes.element.isRequired,
  }

  static registration = new Map()

  static handle(event) {
    for (const [element, callback] of ContextMenuInterceptor.registration) {
      if (element.contains(event.target)) {
        callback(event);
      }
    }
  }

  static dispose() {
    document.removeEventListener('contextmenu', contextMenuHandler, {capture: true});
  }

  componentDidMount() {
    // Helpfully, addEventListener dedupes listeners for us.
    document.addEventListener('contextmenu', contextMenuHandler, {capture: true});
    ContextMenuInterceptor.registration.set(this.element, (...args) => this.props.onWillShowContextMenu(...args));
  }

  render() {
    return <div ref={e => { this.element = e; }}>{this.props.children}</div>;
  }

  componentWillUnmount() {
    ContextMenuInterceptor.registration.delete(this.element);
  }
}

function contextMenuHandler(event) {
  ContextMenuInterceptor.handle(event);
}
