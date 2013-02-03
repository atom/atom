_ = require 'underscore'

module.exports =
class DisplayBufferMarker
  constructor: ({@id, @displayBuffer}) ->
    @buffer = @displayBuffer.buffer

  getScreenRange: ->
    @displayBuffer.screenRangeForBufferRange(@getBufferRange(), wrapAtSoftNewlines: true)

  setScreenRange: (screenRange, options) ->
    @setBufferRange(@displayBuffer.bufferRangeForScreenRange(screenRange, options), options)

  getBufferRange: ->
    @buffer.getMarkerRange(@id)

  setBufferRange: (bufferRange, options) ->
    @buffer.setMarkerRange(@id, bufferRange, options)

  getHeadScreenPosition: ->
    @headScreenPosition ?= @displayBuffer.screenPositionForBufferPosition(@getHeadBufferPosition(), wrapAtSoftNewlines: true)

  setHeadScreenPosition: (screenPosition, options) ->
    screenPosition = @displayBuffer.clipScreenPosition(screenPosition, options)
    @setHeadBufferPosition(@displayBuffer.bufferPositionForScreenPosition(screenPosition, options))

  getHeadBufferPosition: ->
    @buffer.getMarkerHeadPosition(@id)

  setHeadBufferPosition: (bufferPosition) ->
    @buffer.setMarkerHeadPosition(@id, bufferPosition)

  getTailScreenPosition: ->
    @getMarker(@id).getTailScreenPosition()

  setTailScreenPosition: (screenPosition, options) ->
    screenPosition = @displayBuffer.clipScreenPosition(screenPosition, options)
    @setTailBufferPosition(@displayBuffer.bufferPositionForScreenPosition(screenPosition, options))

  getTailBufferPosition: ->
    @buffer.getMarkerTailPosition(@id)

  setTailBufferPosition: (bufferPosition) ->
    @buffer.setMarkerTailPosition(@id, bufferPosition)

  placeTail: ->
    @buffer.placeMarkerTail(@id)

  clearTail: ->
    @buffer.clearMarkerTail(@id)

  observeHeadPosition: (callback) ->
    unless @headObservers
      @observeBufferMarkerHeadPosition()
      @displayBuffer.markers[@id] = this
      @headObservers = []
    @headObservers.push(callback)
    cancel: => @unobserveHeadPosition(callback)

  unobserveHeadPosition: (callback) ->
    _.remove(@headObservers, callback)
    @unsubscribe() unless @headObservers.length

  observeBufferMarkerHeadPosition: ->
    @getHeadScreenPosition()
    @bufferMarkerHeadSubscription =
      @buffer.observeMarkerHeadPosition @id, (e) =>
        bufferChanged = e.bufferChanged
        oldBufferPosition = e.oldPosition
        newBufferPosition = e.newPosition
        @refreshHeadScreenPosition({bufferChanged, oldBufferPosition, newBufferPosition})

  refreshHeadScreenPosition: ({bufferChanged, oldBufferPosition, newBufferPosition}={}) ->
    unless bufferChanged
      oldBufferPosition ?= @getHeadBufferPosition()
      newBufferPosition ?= oldBufferPosition
    oldScreenPosition = @getHeadScreenPosition()
    @headScreenPosition = null
    newScreenPosition = @getHeadScreenPosition()

    unless newScreenPosition.isEqual(oldScreenPosition)
      @notifyHeadObservers({ oldBufferPosition, newBufferPosition, oldScreenPosition, newScreenPosition, bufferChanged })

  notifyHeadObservers: (event) ->
    observer(event) for observer in @getHeadObservers()

  getHeadObservers: ->
    new Array(@headObservers...)

  unsubscribe: ->
    @bufferMarkerHeadSubscription.cancel()
    delete @displayBuffer.markers[@id]
