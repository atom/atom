{Emitter} = require 'event-kit'
Model = require './model'
Decoration = require './decoration'
LayerDecoration = require './layer-decoration'

module.exports =
class DecorationManager extends Model
  didUpdateDecorationsEventScheduled: false
  updatedSynchronously: false

  constructor: (@displayLayer) ->
    super

    @emitter = new Emitter
    @decorationsById = {}
    @decorationsByMarkerId = {}
    @overlayDecorationsById = {}
    @layerDecorationsByMarkerLayerId = {}
    @decorationCountsByLayerId = {}
    @layerUpdateDisposablesByLayerId = {}

  observeDecorations: (callback) ->
    callback(decoration) for decoration in @getDecorations()
    @onDidAddDecoration(callback)

  onDidAddDecoration: (callback) ->
    @emitter.on 'did-add-decoration', callback

  onDidRemoveDecoration: (callback) ->
    @emitter.on 'did-remove-decoration', callback

  onDidUpdateDecorations: (callback) ->
    @emitter.on 'did-update-decorations', callback

  setUpdatedSynchronously: (@updatedSynchronously) ->

  decorationForId: (id) ->
    @decorationsById[id]

  getDecorations: (propertyFilter) ->
    allDecorations = []
    for markerId, decorations of @decorationsByMarkerId
      allDecorations.push(decorations...) if decorations?
    if propertyFilter?
      allDecorations = allDecorations.filter (decoration) ->
        for key, value of propertyFilter
          return false unless decoration.properties[key] is value
        true
    allDecorations

  getLineDecorations: (propertyFilter) ->
    @getDecorations(propertyFilter).filter (decoration) -> decoration.isType('line')

  getLineNumberDecorations: (propertyFilter) ->
    @getDecorations(propertyFilter).filter (decoration) -> decoration.isType('line-number')

  getHighlightDecorations: (propertyFilter) ->
    @getDecorations(propertyFilter).filter (decoration) -> decoration.isType('highlight')

  getOverlayDecorations: (propertyFilter) ->
    result = []
    for id, decoration of @overlayDecorationsById
      result.push(decoration)
    if propertyFilter?
      result.filter (decoration) ->
        for key, value of propertyFilter
          return false unless decoration.properties[key] is value
        true
    else
      result

  decorationsForScreenRowRange: (startScreenRow, endScreenRow) ->
    decorationsByMarkerId = {}
    for layerId of @decorationCountsByLayerId
      layer = @displayLayer.getMarkerLayer(layerId)
      for marker in layer.findMarkers(intersectsScreenRowRange: [startScreenRow, endScreenRow])
        if decorations = @decorationsByMarkerId[marker.id]
          decorationsByMarkerId[marker.id] = decorations
    decorationsByMarkerId

  decorationsStateForScreenRowRange: (startScreenRow, endScreenRow) ->
    decorationsState = {}

    for layerId of @decorationCountsByLayerId
      layer = @displayLayer.getMarkerLayer(layerId)

      for marker in layer.findMarkers(intersectsScreenRowRange: [startScreenRow, endScreenRow]) when marker.isValid()
        screenRange = marker.getScreenRange()
        bufferRange = marker.getBufferRange()
        rangeIsReversed = marker.isReversed()

        if decorations = @decorationsByMarkerId[marker.id]
          for decoration in decorations
            decorationsState[decoration.id] = {
              properties: decoration.properties
              screenRange, bufferRange, rangeIsReversed
            }

        if layerDecorations = @layerDecorationsByMarkerLayerId[layerId]
          for layerDecoration in layerDecorations
            decorationsState["#{layerDecoration.id}-#{marker.id}"] = {
              properties: layerDecoration.overridePropertiesByMarkerId[marker.id] ? layerDecoration.properties
              screenRange, bufferRange, rangeIsReversed
            }

    decorationsState

  decorateMarker: (marker, decorationParams) ->
    if marker.isDestroyed()
      error = new Error("Cannot decorate a destroyed marker")
      error.metadata = {markerLayerIsDestroyed: marker.layer.isDestroyed()}
      if marker.destroyStackTrace?
        error.metadata.destroyStackTrace = marker.destroyStackTrace
      if marker.bufferMarker?.destroyStackTrace?
        error.metadata.destroyStackTrace = marker.bufferMarker?.destroyStackTrace
      throw error
    marker = @displayLayer.getMarkerLayer(marker.layer.id).getMarker(marker.id)
    decoration = new Decoration(marker, this, decorationParams)
    @decorationsByMarkerId[marker.id] ?= []
    @decorationsByMarkerId[marker.id].push(decoration)
    @overlayDecorationsById[decoration.id] = decoration if decoration.isType('overlay')
    @decorationsById[decoration.id] = decoration
    @observeDecoratedLayer(marker.layer)
    @scheduleUpdateDecorationsEvent()
    @emitter.emit 'did-add-decoration', decoration
    decoration

  decorateMarkerLayer: (markerLayer, decorationParams) ->
    throw new Error("Cannot decorate a destroyed marker layer") if markerLayer.isDestroyed()
    decoration = new LayerDecoration(markerLayer, this, decorationParams)
    @layerDecorationsByMarkerLayerId[markerLayer.id] ?= []
    @layerDecorationsByMarkerLayerId[markerLayer.id].push(decoration)
    @observeDecoratedLayer(markerLayer)
    @scheduleUpdateDecorationsEvent()
    decoration

  decorationsForMarkerId: (markerId) ->
    @decorationsByMarkerId[markerId]

  scheduleUpdateDecorationsEvent: ->
    if @updatedSynchronously
      @emitter.emit 'did-update-decorations'
      return

    unless @didUpdateDecorationsEventScheduled
      @didUpdateDecorationsEventScheduled = true
      process.nextTick =>
        @didUpdateDecorationsEventScheduled = false
        @emitter.emit 'did-update-decorations'

  decorationDidChangeType: (decoration) ->
    if decoration.isType('overlay')
      @overlayDecorationsById[decoration.id] = decoration
    else
      delete @overlayDecorationsById[decoration.id]

  didDestroyMarkerDecoration: (decoration) ->
    {marker} = decoration
    return unless decorations = @decorationsByMarkerId[marker.id]
    index = decorations.indexOf(decoration)

    if index > -1
      decorations.splice(index, 1)
      delete @decorationsById[decoration.id]
      @emitter.emit 'did-remove-decoration', decoration
      delete @decorationsByMarkerId[marker.id] if decorations.length is 0
      delete @overlayDecorationsById[decoration.id]
      @unobserveDecoratedLayer(marker.layer)
    @scheduleUpdateDecorationsEvent()

  didDestroyLayerDecoration: (decoration) ->
    {markerLayer} = decoration
    return unless decorations = @layerDecorationsByMarkerLayerId[markerLayer.id]
    index = decorations.indexOf(decoration)

    if index > -1
      decorations.splice(index, 1)
      delete @layerDecorationsByMarkerLayerId[markerLayer.id] if decorations.length is 0
      @unobserveDecoratedLayer(markerLayer)
    @scheduleUpdateDecorationsEvent()

  observeDecoratedLayer: (layer) ->
    @decorationCountsByLayerId[layer.id] ?= 0
    if ++@decorationCountsByLayerId[layer.id] is 1
      @layerUpdateDisposablesByLayerId[layer.id] = layer.onDidUpdate(@scheduleUpdateDecorationsEvent.bind(this))

  unobserveDecoratedLayer: (layer) ->
    if --@decorationCountsByLayerId[layer.id] is 0
      @layerUpdateDisposablesByLayerId[layer.id].dispose()
      delete @decorationCountsByLayerId[layer.id]
      delete @layerUpdateDisposablesByLayerId[layer.id]
