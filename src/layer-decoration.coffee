idCounter = 0
nextId = -> idCounter++

# Essential: Represents a decoration that applies to every marker on a given
# layer. Created via {TextEditor::decorateMarkerLayer}.
module.exports =
class LayerDecoration
  constructor: (@markerLayer, @decorationManager, @properties) ->
    @id = nextId()
    @destroyed = false
    @markerLayerDestroyedDisposable = @markerLayer.onDidDestroy => @destroy()
    @overridePropertiesByMarker = null

  # Essential: Destroys the decoration.
  destroy: ->
    return if @destroyed
    @markerLayerDestroyedDisposable.dispose()
    @markerLayerDestroyedDisposable = null
    @destroyed = true
    @decorationManager.didDestroyLayerDecoration(this)

  # Essential: Determine whether this decoration is destroyed.
  #
  # Returns a {Boolean}.
  isDestroyed: -> @destroyed

  getId: -> @id

  getMarkerLayer: -> @markerLayer

  # Essential: Get this decoration's properties.
  #
  # Returns an {Object}.
  getProperties: ->
    @properties

  # Essential: Set this decoration's properties.
  #
  # * `newProperties` See {TextEditor::decorateMarker} for more information on
  #   the properties. The `type` of `gutter` and `overlay` are not supported on
  #   layer decorations.
  setProperties: (newProperties) ->
    return if @destroyed
    @properties = newProperties
    @decorationManager.emitDidUpdateDecorations()

  # Essential: Override the decoration properties for a specific marker.
  #
  # * `marker` The {DisplayMarker} or {Marker} for which to override
  #   properties.
  # * `properties` An {Object} containing properties to apply to this marker.
  #   Pass `null` to clear the override.
  setPropertiesForMarker: (marker, properties) ->
    return if @destroyed
    @overridePropertiesByMarker ?= new Map()
    marker = @markerLayer.getMarker(marker.id)
    if properties?
      @overridePropertiesByMarker.set(marker, properties)
    else
      @overridePropertiesByMarker.delete(marker)
    @decorationManager.emitDidUpdateDecorations()

  getPropertiesForMarker: (marker) ->
    @overridePropertiesByMarker?.get(marker)
