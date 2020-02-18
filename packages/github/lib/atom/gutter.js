import React from 'react';
import PropTypes from 'prop-types';
import {Disposable} from 'event-kit';

import {autobind, extractProps} from '../helpers';
import {RefHolderPropType} from '../prop-types';
import {TextEditorContext} from './atom-text-editor';
import RefHolder from '../models/ref-holder';

const gutterProps = {
  name: PropTypes.string.isRequired,
  priority: PropTypes.number.isRequired,
  visible: PropTypes.bool,
  type: PropTypes.oneOf(['line-number', 'decorated']),
  labelFn: PropTypes.func,
  onMouseDown: PropTypes.func,
  onMouseMove: PropTypes.func,
};

class BareGutter extends React.Component {
  static propTypes = {
    editorHolder: RefHolderPropType.isRequired,
    className: PropTypes.string,
    ...gutterProps,
  }

  static defaultProps = {
    visible: true,
    type: 'decorated',
    labelFn: () => {},
  }

  constructor(props) {
    super(props);
    autobind(this, 'observeEditor', 'forceUpdate');

    this.state = {
      gutter: null,
    };

    this.sub = new Disposable();
  }

  componentDidMount() {
    this.sub = this.props.editorHolder.observe(this.observeEditor);
  }

  componentDidUpdate(prevProps) {
    if (this.props.editorHolder !== prevProps.editorHolder) {
      this.sub.dispose();
      this.sub = this.props.editorHolder.observe(this.observeEditor);
    }
  }

  componentWillUnmount() {
    if (this.state.gutter !== null) {
      try {
        this.state.gutter.destroy();
      } catch (e) {
        // Gutter already destroyed. Disregard.
      }
    }
    this.sub.dispose();
  }

  render() {
    return null;
  }

  observeEditor(editor) {
    this.setState((prevState, props) => {
      if (prevState.gutter !== null) {
        prevState.gutter.destroy();
      }

      const options = extractProps(props, gutterProps);
      options.class = props.className;
      return {gutter: editor.addGutter(options)};
    });
  }
}

export default class Gutter extends React.Component {
  static propTypes = {
    editor: PropTypes.object,
  }

  constructor(props) {
    super(props);
    this.state = {
      editorHolder: RefHolder.on(this.props.editor),
    };
  }

  static getDerivedStateFromProps(props, state) {
    const editorChanged = state.editorHolder.map(editor => editor !== props.editor).getOr(props.editor !== undefined);
    return editorChanged ? RefHolder.on(props.editor) : null;
  }

  render() {
    if (!this.state.editorHolder.isEmpty()) {
      return <BareGutter {...this.props} editorHolder={this.state.editorHolder} />;
    }

    return (
      <TextEditorContext.Consumer>
        {editorHolder => (
          <BareGutter {...this.props} editorHolder={editorHolder} />
        )}
      </TextEditorContext.Consumer>
    );
  }
}
