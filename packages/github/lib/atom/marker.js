import React from 'react';
import PropTypes from 'prop-types';
import {CompositeDisposable, Disposable} from 'event-kit';

import {autobind, extractProps} from '../helpers';
import {RefHolderPropType, RangePropType} from '../prop-types';
import RefHolder from '../models/ref-holder';
import {TextEditorContext} from './atom-text-editor';
import {MarkerLayerContext} from './marker-layer';

const MarkablePropType = PropTypes.shape({
  markBufferRange: PropTypes.func.isRequired,
});

const markerProps = {
  exclusive: PropTypes.bool,
  reversed: PropTypes.bool,
  invalidate: PropTypes.oneOf(['never', 'surround', 'overlap', 'inside', 'touch']),
};

export const MarkerContext = React.createContext();

export const DecorableContext = React.createContext();

class BareMarker extends React.Component {
  static propTypes = {
    ...markerProps,
    id: PropTypes.number,
    bufferRange: RangePropType,
    markableHolder: RefHolderPropType,
    children: PropTypes.node,
    onDidChange: PropTypes.func,
    handleID: PropTypes.func,
    handleMarker: PropTypes.func,
  }

  static defaultProps = {
    onDidChange: () => {},
    handleID: () => {},
    handleMarker: () => {},
  }

  constructor(props) {
    super(props);

    autobind(this, 'createMarker', 'didChange');

    this.markerSubs = new CompositeDisposable();
    this.subs = new CompositeDisposable();

    this.markerHolder = new RefHolder();
    this.markerHolder.observe(marker => {
      this.props.handleMarker(marker);
    });

    this.decorable = {
      holder: this.markerHolder,
      decorateMethod: 'decorateMarker',
    };
  }

  componentDidMount() {
    this.observeMarkable();
  }

  render() {
    return (
      <MarkerContext.Provider value={this.markerHolder}>
        <DecorableContext.Provider value={this.decorable}>
          {this.props.children}
        </DecorableContext.Provider>
      </MarkerContext.Provider>
    );
  }

  componentDidUpdate(prevProps) {
    if (prevProps.markableHolder !== this.props.markableHolder) {
      this.observeMarkable();
    }

    if (Object.keys(markerProps).some(key => prevProps[key] !== this.props[key])) {
      this.markerHolder.map(marker => marker.setProperties(extractProps(this.props, markerProps)));
    }

    this.updateMarkerPosition();
  }

  componentWillUnmount() {
    this.subs.dispose();
  }

  observeMarkable() {
    this.subs.dispose();
    this.subs = new CompositeDisposable();
    this.subs.add(this.props.markableHolder.observe(this.createMarker));
  }

  createMarker() {
    this.markerSubs.dispose();
    this.markerSubs = new CompositeDisposable();
    this.subs.add(this.markerSubs);

    const options = extractProps(this.props, markerProps);

    this.props.markableHolder.map(markable => {
      let marker;

      if (this.props.id !== undefined) {
        marker = markable.getMarker(this.props.id);
        if (!marker) {
          throw new Error(`Invalid marker ID: ${this.props.id}`);
        }
        marker.setProperties(options);
      } else {
        marker = markable.markBufferRange(this.props.bufferRange, options);
        this.markerSubs.add(new Disposable(() => marker.destroy()));
      }

      this.markerSubs.add(marker.onDidChange(this.didChange));
      this.markerHolder.setter(marker);
      this.props.handleID(marker.id);
      return null;
    });
  }

  updateMarkerPosition() {
    this.markerHolder.map(marker => marker.setBufferRange(this.props.bufferRange));
  }

  didChange(event) {
    const reversed = this.markerHolder.map(marker => marker.isReversed()).getOr(false);

    const oldBufferStartPosition = reversed ? event.oldHeadBufferPosition : event.oldTailBufferPosition;
    const oldBufferEndPosition = reversed ? event.oldTailBufferPosition : event.oldHeadBufferPosition;

    const newBufferStartPosition = reversed ? event.newHeadBufferPosition : event.newTailBufferPosition;
    const newBufferEndPosition = reversed ? event.newTailBufferPosition : event.newHeadBufferPosition;

    this.props.onDidChange({
      oldRange: new Range(oldBufferStartPosition, oldBufferEndPosition),
      newRange: new Range(newBufferStartPosition, newBufferEndPosition),
      ...event,
    });
  }
}

export default class Marker extends React.Component {
  static propTypes = {
    editor: MarkablePropType,
    layer: MarkablePropType,
  }

  constructor(props) {
    super(props);

    this.state = {
      markableHolder: RefHolder.on(props.layer || props.editor),
    };
  }

  static getDerivedStateFromProps(props, state) {
    const markable = props.layer || props.editor;

    if (state.markableHolder.map(m => m === markable).getOr(markable === undefined)) {
      return {};
    }

    return {
      markableHolder: RefHolder.on(markable),
    };
  }

  render() {
    if (!this.state.markableHolder.isEmpty()) {
      return <BareMarker {...this.props} markableHolder={this.state.markableHolder} />;
    }

    return (
      <MarkerLayerContext.Consumer>
        {layerHolder => {
          if (layerHolder) {
            return <BareMarker {...this.props} markableHolder={layerHolder} />;
          } else {
            return (
              <TextEditorContext.Consumer>
                {editorHolder => <BareMarker {...this.props} markableHolder={editorHolder} />}
              </TextEditorContext.Consumer>
            );
          }
        }}
      </MarkerLayerContext.Consumer>
    );
  }
}
