Range = require 'range'
_ = require 'underscore'

module.exports =
class DisplayBufferMarker
  observers: null
  bufferMarkerSubscription: null
  headScreenPosition: null
  tailScreenPosition: null

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
    @tailScreenPosition ?= @displayBuffer.screenPositionForBufferPosition(@getTailBufferPosition(), wrapAtSoftNewlines: true)

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

  observe: (callback) ->
    @observeBufferMarkerIfNeeded()
    @observers.push(callback)
    cancel: => @unobserve(callback)

  unobserve: (callback) ->
    _.remove(@observers, callback)
    @unobserveBufferMarkerIfNeeded()

  observeBufferMarkerIfNeeded: ->
    return if @observers
    @observers = []
    @getHeadScreenPosition() # memoize current value
    @getTailScreenPosition() # memoize current value
    @bufferMarkerSubscription =
      @buffer.observeMarker @id, ({oldHeadPosition, newHeadPosition, oldTailPosition, newTailPosition, bufferChanged}) =>
        @notifyObservers
          oldHeadBufferPosition: oldHeadPosition
          newHeadBufferPosition: newHeadPosition
          oldTailBufferPosition: oldTailPosition
          newTailBufferPosition: newTailPosition
          bufferChanged: bufferChanged
    @displayBuffer.markers[@id] = this

  unobserveBufferMarkerIfNeeded: ->
    return if @observers.length
    @observers = null
    @bufferMarkerSubscription.cancel()
    delete @displayBuffer.markers[@id]

  notifyObservers: ({oldHeadBufferPosition, oldTailBufferPosition, bufferChanged}) ->
    oldHeadScreenPosition = @getHeadScreenPosition()
    @headScreenPosition = null
    newHeadScreenPosition = @getHeadScreenPosition()

    oldTailScreenPosition = @getTailScreenPosition()
    @tailScreenPosition = null
    newTailScreenPosition = @getTailScreenPosition()

    return if _.isEqual(newHeadScreenPosition, oldHeadScreenPosition) and _.isEqual(newTailScreenPosition, oldTailScreenPosition)

    oldHeadBufferPosition ?= @getHeadBufferPosition()
    newHeadBufferPosition = @getHeadBufferPosition()
    oldTailBufferPosition ?= @getTailBufferPosition()
    newTailBufferPosition = @getTailBufferPosition()

    for observer in @getObservers()
      observer({
        oldHeadScreenPosition, newHeadScreenPosition,
        oldTailScreenPosition, newTailScreenPosition,
        oldHeadBufferPosition, newHeadBufferPosition,
        oldTailBufferPosition, newTailBufferPosition,
        bufferChanged
      })

  getObservers: ->
    new Array(@observers...)
