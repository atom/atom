const {Emitter} = require('event-kit')
const Decoration = require('./decoration')
const LayerDecoration = require('./layer-decoration')

module.exports =
class DecorationManager {
  constructor(displayLayer) {
    this.displayLayer = displayLayer

    this.emitter = new Emitter
    this.didUpdateDecorationsEventScheduled = false
    this.updatedSynchronously = false
    this.decorationsById = {}
    this.decorationsByMarkerId = {}
    this.overlayDecorationsById = {}
    this.layerDecorationsByMarkerLayerId = {}
    this.decorationCountsByLayerId = {}
    this.layerUpdateDisposablesByLayerId = {}
  }

  observeDecorations(callback) {
    for (let decoration of this.getDecorations()) { callback(decoration); }
    return this.onDidAddDecoration(callback)
  }

  onDidAddDecoration(callback) {
    return this.emitter.on('did-add-decoration', callback)
  }

  onDidRemoveDecoration(callback) {
    return this.emitter.on('did-remove-decoration', callback)
  }

  onDidUpdateDecorations(callback) {
    return this.emitter.on('did-update-decorations', callback)
  }

  setUpdatedSynchronously(updatedSynchronously) {
    this.updatedSynchronously = updatedSynchronously
  }

  decorationForId(id) {
    return this.decorationsById[id]
  }

  getDecorations(propertyFilter) {
    let allDecorations = []
    for (let markerId in this.decorationsByMarkerId) {
      const decorations = this.decorationsByMarkerId[markerId]
      if (decorations != null) {
        allDecorations.push(...decorations)
      }
    }
    if (propertyFilter != null) {
      allDecorations = allDecorations.filter(function(decoration) {
        for (let key in propertyFilter) {
          const value = propertyFilter[key]
          if (decoration.properties[key] !== value) return false
        }
        return true
      })
    }
    return allDecorations
  }

  getLineDecorations(propertyFilter) {
    return this.getDecorations(propertyFilter).filter(decoration => decoration.isType('line'))
  }

  getLineNumberDecorations(propertyFilter) {
    return this.getDecorations(propertyFilter).filter(decoration => decoration.isType('line-number'))
  }

  getHighlightDecorations(propertyFilter) {
    return this.getDecorations(propertyFilter).filter(decoration => decoration.isType('highlight'))
  }

  getOverlayDecorations(propertyFilter) {
    const result = []
    for (let id in this.overlayDecorationsById) {
      const decoration = this.overlayDecorationsById[id]
      result.push(decoration)
    }
    if (propertyFilter != null) {
      return result.filter(function(decoration) {
        for (let key in propertyFilter) {
          const value = propertyFilter[key]
          if (decoration.properties[key] !== value) {
            return false
          }
        }
        return true
      })
    } else {
      return result
    }
  }

  decorationsForScreenRowRange(startScreenRow, endScreenRow) {
    const decorationsByMarkerId = {}
    for (let layerId in this.decorationCountsByLayerId) {
      const layer = this.displayLayer.getMarkerLayer(layerId)
      for (let marker of layer.findMarkers({intersectsScreenRowRange: [startScreenRow, endScreenRow]})) {
        const decorations = this.decorationsByMarkerId[marker.id]
        if (decorations) {
          decorationsByMarkerId[marker.id] = decorations
        }
      }
    }
    return decorationsByMarkerId
  }

  decorationsStateForScreenRowRange(startScreenRow, endScreenRow) {
    const decorationsState = {}

    for (let layerId in this.decorationCountsByLayerId) {
      const layer = this.displayLayer.getMarkerLayer(layerId)

      for (let marker of layer.findMarkers({intersectsScreenRowRange: [startScreenRow, endScreenRow]})) {
        if (marker.isValid()) {
          const screenRange = marker.getScreenRange()
          const bufferRange = marker.getBufferRange()
          const rangeIsReversed = marker.isReversed()

          const decorations = this.decorationsByMarkerId[marker.id]
          if (decorations) {
            for (let decoration of decorations) {
              decorationsState[decoration.id] = {
                properties: decoration.properties,
                screenRange, bufferRange, rangeIsReversed
              }
            }
          }

          const layerDecorations = this.layerDecorationsByMarkerLayerId[layerId]
          if (layerDecorations) {
            for (let layerDecoration of layerDecorations) {
              decorationsState[`${layerDecoration.id}-${marker.id}`] = {
                properties: layerDecoration.overridePropertiesByMarkerId[marker.id] != null ? layerDecoration.overridePropertiesByMarkerId[marker.id] : layerDecoration.properties,
                screenRange, bufferRange, rangeIsReversed
              }
            }
          }
        }
      }
    }

    return decorationsState
  }

  decorateMarker(marker, decorationParams) {
    if (marker.isDestroyed()) {
      const error = new Error("Cannot decorate a destroyed marker")
      error.metadata = {markerLayerIsDestroyed: marker.layer.isDestroyed()}
      if (marker.destroyStackTrace != null) {
        error.metadata.destroyStackTrace = marker.destroyStackTrace
      }
      if (marker.bufferMarker != null && marker.bufferMarker.destroyStackTrace != null) {
        error.metadata.destroyStackTrace = marker.bufferMarker.destroyStackTrace
      }
      throw error
    }
    marker = this.displayLayer.getMarkerLayer(marker.layer.id).getMarker(marker.id)
    const decoration = new Decoration(marker, this, decorationParams)
    if (this.decorationsByMarkerId[marker.id] == null) {
      this.decorationsByMarkerId[marker.id] = []
    }
    this.decorationsByMarkerId[marker.id].push(decoration)
    if (decoration.isType('overlay')) {
      this.overlayDecorationsById[decoration.id] = decoration
    }
    this.decorationsById[decoration.id] = decoration
    this.observeDecoratedLayer(marker.layer)
    this.scheduleUpdateDecorationsEvent()
    this.emitter.emit('did-add-decoration', decoration)
    return decoration
  }

  decorateMarkerLayer(markerLayer, decorationParams) {
    if (markerLayer.isDestroyed()) {
      throw new Error("Cannot decorate a destroyed marker layer")
    }
    const decoration = new LayerDecoration(markerLayer, this, decorationParams)
    if (this.layerDecorationsByMarkerLayerId[markerLayer.id] == null) {
      this.layerDecorationsByMarkerLayerId[markerLayer.id] = []
    }
    this.layerDecorationsByMarkerLayerId[markerLayer.id].push(decoration)
    this.observeDecoratedLayer(markerLayer)
    this.scheduleUpdateDecorationsEvent()
    return decoration
  }

  decorationsForMarkerId(markerId) {
    return this.decorationsByMarkerId[markerId]
  }

  scheduleUpdateDecorationsEvent() {
    if (this.updatedSynchronously) {
      this.emitter.emit('did-update-decorations')
      return
    }

    if (!this.didUpdateDecorationsEventScheduled) {
      this.didUpdateDecorationsEventScheduled = true
      return process.nextTick(() => {
        this.didUpdateDecorationsEventScheduled = false
        return this.emitter.emit('did-update-decorations')
      }
      )
    }
  }

  decorationDidChangeType(decoration) {
    if (decoration.isType('overlay')) {
      return this.overlayDecorationsById[decoration.id] = decoration
    } else {
      return delete this.overlayDecorationsById[decoration.id]
    }
  }

  didDestroyMarkerDecoration(decoration) {
    let decorations
    const {marker} = decoration
    if (!(decorations = this.decorationsByMarkerId[marker.id])) return
    const index = decorations.indexOf(decoration)

    if (index > -1) {
      decorations.splice(index, 1)
      delete this.decorationsById[decoration.id]
      this.emitter.emit('did-remove-decoration', decoration)
      if (decorations.length === 0) {
        delete this.decorationsByMarkerId[marker.id]
      }
      delete this.overlayDecorationsById[decoration.id]
      this.unobserveDecoratedLayer(marker.layer)
    }
    return this.scheduleUpdateDecorationsEvent()
  }

  didDestroyLayerDecoration(decoration) {
    let decorations
    const {markerLayer} = decoration
    if (!(decorations = this.layerDecorationsByMarkerLayerId[markerLayer.id])) return
    const index = decorations.indexOf(decoration)

    if (index > -1) {
      decorations.splice(index, 1)
      if (decorations.length === 0) {
        delete this.layerDecorationsByMarkerLayerId[markerLayer.id]
      }
      this.unobserveDecoratedLayer(markerLayer)
    }
    return this.scheduleUpdateDecorationsEvent()
  }

  observeDecoratedLayer(layer) {
    if (this.decorationCountsByLayerId[layer.id] == null) {
      this.decorationCountsByLayerId[layer.id] = 0
    }
    if (++this.decorationCountsByLayerId[layer.id] === 1) {
      this.layerUpdateDisposablesByLayerId[layer.id] = layer.onDidUpdate(this.scheduleUpdateDecorationsEvent.bind(this))
    }
  }

  unobserveDecoratedLayer(layer) {
    if (--this.decorationCountsByLayerId[layer.id] === 0) {
      this.layerUpdateDisposablesByLayerId[layer.id].dispose()
      delete this.decorationCountsByLayerId[layer.id]
      delete this.layerUpdateDisposablesByLayerId[layer.id]
    }
  }
}
