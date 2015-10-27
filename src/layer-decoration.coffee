_ = require 'underscore-plus'

idCounter = 0
nextId = -> idCounter++

module.exports =
class LayerDecoration
  constructor: (@markerLayer, @displayBuffer, @properties) ->
    @id = nextId()
    @destroyed = false
    @markerLayerDestroyedDisposable = @markerLayer.onDidDestroy => @destroy()

  destroy: ->
    return if @destroyed
    @markerLayerDestroyedDisposable.dispose()
    @markerLayerDestroyedDisposable = null
    @destroyed = true
    @displayBuffer.didDestroyLayerDecoration(this)

  isDestroyed: -> @destroyed

  getId: -> @id

  getMarkerLayer: -> @markerLayer

  getProperties: ->
    @properties

  setProperties: (newProperties) ->
    return if @destroyed
    @properties = newProperties
    @displayBuffer.scheduleUpdateDecorationsEvent()
