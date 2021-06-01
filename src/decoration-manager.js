const { Emitter } = require('event-kit');
const Decoration = require('./decoration');
const LayerDecoration = require('./layer-decoration');

module.exports = class DecorationManager {
  constructor(editor) {
    this.editor = editor;
    this.displayLayer = this.editor.displayLayer;

    this.emitter = new Emitter();
    this.decorationCountsByLayer = new Map();
    this.markerDecorationCountsByLayer = new Map();
    this.decorationsByMarker = new Map();
    this.layerDecorationsByMarkerLayer = new Map();
    this.overlayDecorations = new Set();
    this.layerUpdateDisposablesByLayer = new WeakMap();
  }

  observeDecorations(callback) {
    const decorations = this.getDecorations();
    for (let i = 0; i < decorations.length; i++) {
      callback(decorations[i]);
    }
    return this.onDidAddDecoration(callback);
  }

  onDidAddDecoration(callback) {
    return this.emitter.on('did-add-decoration', callback);
  }

  onDidRemoveDecoration(callback) {
    return this.emitter.on('did-remove-decoration', callback);
  }

  onDidUpdateDecorations(callback) {
    return this.emitter.on('did-update-decorations', callback);
  }

  getDecorations(propertyFilter) {
    let allDecorations = [];

    this.decorationsByMarker.forEach(decorations => {
      decorations.forEach(decoration => allDecorations.push(decoration));
    });
    if (propertyFilter != null) {
      allDecorations = allDecorations.filter(function(decoration) {
        for (let key in propertyFilter) {
          const value = propertyFilter[key];
          if (decoration.properties[key] !== value) return false;
        }
        return true;
      });
    }
    return allDecorations;
  }

  getLineDecorations(propertyFilter) {
    return this.getDecorations(propertyFilter).filter(decoration =>
      decoration.isType('line')
    );
  }

  getLineNumberDecorations(propertyFilter) {
    return this.getDecorations(propertyFilter).filter(decoration =>
      decoration.isType('line-number')
    );
  }

  getHighlightDecorations(propertyFilter) {
    return this.getDecorations(propertyFilter).filter(decoration =>
      decoration.isType('highlight')
    );
  }

  getOverlayDecorations(propertyFilter) {
    const result = [];
    result.push(...Array.from(this.overlayDecorations));
    if (propertyFilter != null) {
      return result.filter(function(decoration) {
        for (let key in propertyFilter) {
          const value = propertyFilter[key];
          if (decoration.properties[key] !== value) {
            return false;
          }
        }
        return true;
      });
    } else {
      return result;
    }
  }

  decorationPropertiesByMarkerForScreenRowRange(startScreenRow, endScreenRow) {
    const decorationPropertiesByMarker = new Map();

    this.decorationCountsByLayer.forEach((count, markerLayer) => {
      const markers = markerLayer.findMarkers({
        intersectsScreenRowRange: [startScreenRow, endScreenRow - 1]
      });
      const layerDecorations = this.layerDecorationsByMarkerLayer.get(
        markerLayer
      );
      const hasMarkerDecorations =
        this.markerDecorationCountsByLayer.get(markerLayer) > 0;

      for (let i = 0; i < markers.length; i++) {
        const marker = markers[i];
        if (!marker.isValid()) continue;

        let decorationPropertiesForMarker = decorationPropertiesByMarker.get(
          marker
        );
        if (decorationPropertiesForMarker == null) {
          decorationPropertiesForMarker = [];
          decorationPropertiesByMarker.set(
            marker,
            decorationPropertiesForMarker
          );
        }

        if (layerDecorations) {
          layerDecorations.forEach(layerDecoration => {
            const properties =
              layerDecoration.getPropertiesForMarker(marker) ||
              layerDecoration.getProperties();
            decorationPropertiesForMarker.push(properties);
          });
        }

        if (hasMarkerDecorations) {
          const decorationsForMarker = this.decorationsByMarker.get(marker);
          if (decorationsForMarker) {
            decorationsForMarker.forEach(decoration => {
              decorationPropertiesForMarker.push(decoration.getProperties());
            });
          }
        }
      }
    });

    return decorationPropertiesByMarker;
  }

  decorationsForScreenRowRange(startScreenRow, endScreenRow) {
    const decorationsByMarkerId = {};
    for (const layer of this.decorationCountsByLayer.keys()) {
      for (const marker of layer.findMarkers({
        intersectsScreenRowRange: [startScreenRow, endScreenRow]
      })) {
        const decorations = this.decorationsByMarker.get(marker);
        if (decorations) {
          decorationsByMarkerId[marker.id] = Array.from(decorations);
        }
      }
    }
    return decorationsByMarkerId;
  }

  decorationsStateForScreenRowRange(startScreenRow, endScreenRow) {
    const decorationsState = {};

    for (const layer of this.decorationCountsByLayer.keys()) {
      for (const marker of layer.findMarkers({
        intersectsScreenRowRange: [startScreenRow, endScreenRow]
      })) {
        if (marker.isValid()) {
          const screenRange = marker.getScreenRange();
          const bufferRange = marker.getBufferRange();
          const rangeIsReversed = marker.isReversed();

          const decorations = this.decorationsByMarker.get(marker);
          if (decorations) {
            decorations.forEach(decoration => {
              decorationsState[decoration.id] = {
                properties: decoration.properties,
                screenRange,
                bufferRange,
                rangeIsReversed
              };
            });
          }

          const layerDecorations = this.layerDecorationsByMarkerLayer.get(
            layer
          );
          if (layerDecorations) {
            layerDecorations.forEach(layerDecoration => {
              const properties =
                layerDecoration.getPropertiesForMarker(marker) ||
                layerDecoration.getProperties();
              decorationsState[`${layerDecoration.id}-${marker.id}`] = {
                properties,
                screenRange,
                bufferRange,
                rangeIsReversed
              };
            });
          }
        }
      }
    }

    return decorationsState;
  }

  decorateMarker(marker, decorationParams) {
    if (marker.isDestroyed()) {
      const error = new Error('Cannot decorate a destroyed marker');
      error.metadata = { markerLayerIsDestroyed: marker.layer.isDestroyed() };
      if (marker.destroyStackTrace != null) {
        error.metadata.destroyStackTrace = marker.destroyStackTrace;
      }
      if (
        marker.bufferMarker != null &&
        marker.bufferMarker.destroyStackTrace != null
      ) {
        error.metadata.destroyStackTrace =
          marker.bufferMarker.destroyStackTrace;
      }
      throw error;
    }
    marker = this.displayLayer
      .getMarkerLayer(marker.layer.id)
      .getMarker(marker.id);
    const decoration = new Decoration(marker, this, decorationParams);
    let decorationsForMarker = this.decorationsByMarker.get(marker);
    if (!decorationsForMarker) {
      decorationsForMarker = new Set();
      this.decorationsByMarker.set(marker, decorationsForMarker);
    }
    decorationsForMarker.add(decoration);
    if (decoration.isType('overlay')) this.overlayDecorations.add(decoration);
    this.observeDecoratedLayer(marker.layer, true);
    this.editor.didAddDecoration(decoration);
    this.emitDidUpdateDecorations();
    this.emitter.emit('did-add-decoration', decoration);
    return decoration;
  }

  decorateMarkerLayer(markerLayer, decorationParams) {
    if (markerLayer.isDestroyed()) {
      throw new Error('Cannot decorate a destroyed marker layer');
    }
    markerLayer = this.displayLayer.getMarkerLayer(markerLayer.id);
    const decoration = new LayerDecoration(markerLayer, this, decorationParams);
    let layerDecorations = this.layerDecorationsByMarkerLayer.get(markerLayer);
    if (layerDecorations == null) {
      layerDecorations = new Set();
      this.layerDecorationsByMarkerLayer.set(markerLayer, layerDecorations);
    }
    layerDecorations.add(decoration);
    this.observeDecoratedLayer(markerLayer, false);
    this.emitDidUpdateDecorations();
    return decoration;
  }

  emitDidUpdateDecorations() {
    this.editor.scheduleComponentUpdate();
    this.emitter.emit('did-update-decorations');
  }

  decorationDidChangeType(decoration) {
    if (decoration.isType('overlay')) {
      this.overlayDecorations.add(decoration);
    } else {
      this.overlayDecorations.delete(decoration);
    }
  }

  didDestroyMarkerDecoration(decoration) {
    const { marker } = decoration;
    const decorations = this.decorationsByMarker.get(marker);
    if (decorations && decorations.has(decoration)) {
      decorations.delete(decoration);
      if (decorations.size === 0) this.decorationsByMarker.delete(marker);
      this.overlayDecorations.delete(decoration);
      this.unobserveDecoratedLayer(marker.layer, true);
      this.emitter.emit('did-remove-decoration', decoration);
      this.emitDidUpdateDecorations();
    }
  }

  didDestroyLayerDecoration(decoration) {
    const { markerLayer } = decoration;
    const decorations = this.layerDecorationsByMarkerLayer.get(markerLayer);

    if (decorations && decorations.has(decoration)) {
      decorations.delete(decoration);
      if (decorations.size === 0) {
        this.layerDecorationsByMarkerLayer.delete(markerLayer);
      }
      this.unobserveDecoratedLayer(markerLayer, true);
      this.emitDidUpdateDecorations();
    }
  }

  observeDecoratedLayer(layer, isMarkerDecoration) {
    const newCount = (this.decorationCountsByLayer.get(layer) || 0) + 1;
    this.decorationCountsByLayer.set(layer, newCount);
    if (newCount === 1) {
      this.layerUpdateDisposablesByLayer.set(
        layer,
        layer.onDidUpdate(this.emitDidUpdateDecorations.bind(this))
      );
    }
    if (isMarkerDecoration) {
      this.markerDecorationCountsByLayer.set(
        layer,
        (this.markerDecorationCountsByLayer.get(layer) || 0) + 1
      );
    }
  }

  unobserveDecoratedLayer(layer, isMarkerDecoration) {
    const newCount = this.decorationCountsByLayer.get(layer) - 1;
    if (newCount === 0) {
      this.layerUpdateDisposablesByLayer.get(layer).dispose();
      this.decorationCountsByLayer.delete(layer);
    } else {
      this.decorationCountsByLayer.set(layer, newCount);
    }
    if (isMarkerDecoration) {
      this.markerDecorationCountsByLayer.set(
        this.markerDecorationCountsByLayer.get(layer) - 1
      );
    }
  }
};
