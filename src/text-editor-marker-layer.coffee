TextEditorMarker = require './text-editor-marker'

# Public: *Experimental:* A container for a related set of markers at the
# {TextEditor} level. Wraps an underlying {MarkerLayer} on the editor's
# {TextBuffer}.
#
# This API is experimental and subject to change on any release.
module.exports =
class TextEditorMarkerLayer
  constructor: (@displayBuffer, @bufferMarkerLayer, @isDefaultLayer) ->
    @id = @bufferMarkerLayer.id
    @markersById = {}

  ###
  Section: Lifecycle
  ###

  # Essential: Destroy this layer.
  destroy: ->
    if @isDefaultLayer
      marker.destroy() for id, marker of @markersById
    else
      @bufferMarkerLayer.destroy()

  ###
  Section: Querying
  ###

  # Essential: Get an existing marker by its id.
  #
  # Returns a {TextEditorMarker}.
  getMarker: (id) ->
    if editorMarker = @markersById[id]
      editorMarker
    else if bufferMarker = @bufferMarkerLayer.getMarker(id)
      @markersById[id] = new TextEditorMarker(this, bufferMarker)

  # Essential: Get all markers in the layer.
  #
  # Returns an {Array} of {TextEditorMarker}s.
  getMarkers: ->
    @bufferMarkerLayer.getMarkers().map ({id}) => @getMarker(id)

  # Public: Get the number of markers in the marker layer.
  #
  # Returns a {Number}.
  getMarkerCount: ->
    @bufferMarkerLayer.getMarkerCount()

  # Public: Find markers in the layer conforming to the given parameters.
  #
  # See the documentation for {TextEditor::findMarkers}.
  findMarkers: (params) ->
    params = @translateToBufferMarkerParams(params)
    @bufferMarkerLayer.findMarkers(params).map (stringMarker) => @getMarker(stringMarker.id)

  ###
  Section: Marker creation
  ###

  # Essential: Create a marker on this layer with the given range in buffer
  # coordinates.
  #
  # See the documentation for {TextEditor::markBufferRange}
  markBufferRange: (bufferRange, options) ->
    @getMarker(@bufferMarkerLayer.markRange(bufferRange, options).id)

  # Essential: Create a marker on this layer with the given range in screen
  # coordinates.
  #
  # See the documentation for {TextEditor::markScreenRange}
  markScreenRange: (screenRange, options) ->
    bufferRange = @displayBuffer.bufferRangeForScreenRange(screenRange)
    @markBufferRange(bufferRange, options)

  # Public: Create a marker on this layer with the given buffer position and no
  # tail.
  #
  # See the documentation for {TextEditor::markBufferPosition}
  markBufferPosition: (bufferPosition, options) ->
    @getMarker(@bufferMarkerLayer.markPosition(bufferPosition, options).id)

  # Public: Create a marker on this layer with the given screen position and no
  # tail.
  #
  # See the documentation for {TextEditor::markScreenPosition}
  markScreenPosition: (screenPosition, options) ->
    bufferPosition = @displayBuffer.bufferPositionForScreenPosition(screenPosition)
    @markBufferPosition(bufferPosition, options)

  ###
  Section: Event Subscription
  ###

  # Public: Subscribe to be notified asynchronously whenever markers are
  # created, updated, or destroyed on this layer. *Prefer this method for
  # optimal performance when interacting with layers that could contain large
  # numbers of markers.*
  #
  # * `callback` A {Function} that will be called with no arguments when changes
  #   occur on this layer.
  #
  # Subscribers are notified once, asynchronously when any number of changes
  # occur in a given tick of the event loop. You should re-query the layer
  # to determine the state of markers in which you're interested in. It may
  # be counter-intuitive, but this is much more efficient than subscribing to
  # events on individual markers, which are expensive to deliver.
  #
  # Returns a {Disposable}.
  onDidUpdate: (callback) ->
    @bufferMarkerLayer.onDidUpdate(callback)

  # Public: Subscribe to be notified synchronously whenever markers are created
  # on this layer. *Avoid this method for optimal performance when interacting
  # with layers that could contain large numbers of markers.*
  #
  # * `callback` A {Function} that will be called with a {TextEditorMarker}
  #   whenever a new marker is created.
  #
  # You should prefer {onDidUpdate} when synchronous notifications aren't
  # absolutely necessary.
  #
  # Returns a {Disposable}.
  onDidCreateMarker: (callback) ->
    @bufferMarkerLayer.onDidCreateMarker (bufferMarker) =>
      callback(@getMarker(bufferMarker.id))

  # Public: Subscribe to be notified synchronously when this layer is destroyed.
  #
  # Returns a {Disposable}.
  onDidDestroy: (callback) ->
    @bufferMarkerLayer.onDidDestroy(callback)

  ###
  Section: Private
  ###

  refreshMarkerScreenPositions: ->
    for marker in @getMarkers()
      marker.notifyObservers(textChanged: false)
    return

  didDestroyMarker: (marker) ->
    delete @markersById[marker.id]

  translateToBufferMarkerParams: (params) ->
    bufferMarkerParams = {}
    for key, value of params
      switch key
        when 'startBufferPosition'
          key = 'startPosition'
        when 'endBufferPosition'
          key = 'endPosition'
        when 'startScreenPosition'
          key = 'startPosition'
          value = @displayBuffer.bufferPositionForScreenPosition(value)
        when 'endScreenPosition'
          key = 'endPosition'
          value = @displayBuffer.bufferPositionForScreenPosition(value)
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
