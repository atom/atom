TextEditorMarker = require './text-editor-marker'

module.exports =
class TextEditorMarkerLayer
  constructor: (@displayBuffer, @bufferMarkerLayer, @isDefaultLayer) ->
    @markersById = {}

  getMarker: (id) ->
    if editorMarker = @markersById[id]
      editorMarker
    else if bufferMarker = @bufferMarkerLayer.getMarker(id)
      @markersById[id] = new TextEditorMarker(this, bufferMarker)

  getMarkers: ->
    @bufferMarkerLayer.getMarkers().map ({id}) => @getMarker(id)

  markBufferRange: (bufferRange, options) ->
    @getMarker(@bufferMarkerLayer.markRange(bufferRange, options).id)

  markScreenRange: (screenRange, options) ->
    bufferRange = @displayBuffer.bufferRangeForScreenRange(screenRange)
    @markBufferRange(bufferRange, options)

  markBufferPosition: (bufferPosition, options) ->
    @getMarker(@bufferMarkerLayer.markPosition(bufferPosition, options).id)

  markScreenPosition: (screenPosition, options) ->
    bufferPosition = @displayBuffer.bufferPositionForScreenPosition(screenPosition)
    @markBufferPosition(bufferPosition, options)

  findMarkers: (params) ->
    params = @translateToBufferMarkerParams(params)
    @bufferMarkerLayer.findMarkers(params).map (stringMarker) => @getMarker(stringMarker.id)

  destroy: ->
    if @isDefaultLayer
      marker.destroy() for id, marker of @markersById
    else
      @bufferMarkerLayer.destroy()

  didDestroyMarker: (marker) ->
    delete @markersById[marker.id]

  translateToBufferMarkerParams: (params) ->
    bufferMarkerParams = {}
    for key, value of params
      switch key
        when 'startBufferRow'
          key = 'startRow'
        when 'endBufferRow'
          key = 'endRow'
        when 'startScreenRow'
          key = 'startRow'
          value = @displayBuffer.bufferRowForScreenRow(value)
        when 'endScreenRow'
          key = 'endRow'
          value = @displayBuffer.bufferRowForScreenRow(value)
        when 'intersectsBufferRowRange'
          key = 'intersectsRowRange'
        when 'intersectsScreenRowRange'
          key = 'intersectsRowRange'
          [startRow, endRow] = value
          value = [@displayBuffer.bufferRowForScreenRow(startRow), @displayBuffer.bufferRowForScreenRow(endRow)]
        when 'containsBufferRange'
          key = 'containsRange'
        when 'containsBufferPosition'
          key = 'containsPosition'
        when 'containedInBufferRange'
          key = 'containedInRange'
        when 'containedInScreenRange'
          key = 'containedInRange'
          value = @displayBuffer.bufferRangeForScreenRange(value)
        when 'intersectsBufferRange'
          key = 'intersectsRange'
        when 'intersectsScreenRange'
          key = 'intersectsRange'
          value = @displayBuffer.bufferRangeForScreenRange(value)
      bufferMarkerParams[key] = value

    bufferMarkerParams
