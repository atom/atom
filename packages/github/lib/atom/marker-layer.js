import React from 'react';
import PropTypes from 'prop-types';
import {CompositeDisposable, Disposable} from 'event-kit';

import {autobind, extractProps} from '../helpers';
import RefHolder from '../models/ref-holder';
import {TextEditorContext} from './atom-text-editor';
import {DecorableContext} from './marker';

const markerLayerProps = {
  maintainHistory: PropTypes.bool,
  persistent: PropTypes.bool,
};

export const MarkerLayerContext = React.createContext();

class BareMarkerLayer extends React.Component {
  static propTypes = {
    ...markerLayerProps,
    editor: PropTypes.object,
    external: PropTypes.shape({
      id: PropTypes.string.isRequired,
    }),
    children: PropTypes.node,
    handleID: PropTypes.func,
    handleLayer: PropTypes.func,
  };

  static defaultProps = {
    handleID: () => {},
    handleLayer: () => {},
  }

  constructor(props) {
    super(props);

    autobind(this, 'createLayer');

    this.subs = new CompositeDisposable();
    this.layerSub = new Disposable();

    this.layerHolder = new RefHolder();
    this.state = {
      editorHolder: RefHolder.on(this.props.editor),
    };

    this.decorable = {
      holder: this.layerHolder,
      decorateMethod: 'decorateMarkerLayer',
    };
  }

  static getDerivedStateFromProps(props, state) {
    if (state.editorHolder.map(e => e === props.editor).getOr(props.editor === undefined)) {
      return null;
    }

    return {
      editorHolder: RefHolder.on(props.editor),
    };
  }

  componentDidMount() {
    this.observeEditor();
  }

  render() {
    return (
      <MarkerLayerContext.Provider value={this.layerHolder}>
        <DecorableContext.Provider value={this.decorable}>
          {this.props.children}
        </DecorableContext.Provider>
      </MarkerLayerContext.Provider>
    );
  }

  componentDidUpdate(prevProps, prevState) {
    if (this.state.editorHolder !== prevState.editorHolder) {
      this.observeEditor();
    }
  }

  componentWillUnmount() {
    this.subs.dispose();
  }

  observeEditor() {
    this.subs.dispose();
    this.subs = new CompositeDisposable();
    this.subs.add(this.state.editorHolder.observe(this.createLayer));
  }

  createLayer() {
    this.subs.remove(this.layerSub);
    this.layerSub.dispose();

    this.state.editorHolder.map(editor => {
      const options = extractProps(this.props, markerLayerProps);
      let layer;
      if (this.props.external !== undefined) {
        layer = editor.getMarkerLayer(this.props.external.id);
        if (!layer) {
          return null;
        }
        if (layer !== this.props.external && layer.bufferMarkerLayer !== this.props.external) {
          // Oops, same layer ID on a different TextEditor
          return null;
        }
        this.layerSub = new Disposable();
      } else {
        layer = editor.addMarkerLayer(options);
        this.layerSub = new Disposable(() => {
          layer.destroy();
          this.props.handleLayer(undefined);
          this.props.handleID(undefined);
        });
      }
      this.layerHolder.setter(layer);

      this.props.handleLayer(layer);
      this.props.handleID(layer.id);

      this.subs.add(this.layerSub);

      return null;
    });
  }
}

export default class MarkerLayer extends React.Component {
  render() {
    return (
      <TextEditorContext.Consumer>
        {editor => <BareMarkerLayer editor={editor} {...this.props} />}
      </TextEditorContext.Consumer>
    );
  }
}
