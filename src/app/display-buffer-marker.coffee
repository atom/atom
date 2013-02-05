Range = require 'range'
_ = require 'underscore'

module.exports =
class DisplayBufferMarker
  observers: null
  bufferMarkerSubscription: null
  previousHeadScreenPosition: null
  previousTailScreenPosition: null

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
    @displayBuffer.screenPositionForBufferPosition(@getHeadBufferPosition(), wrapAtSoftNewlines: true)

  setHeadScreenPosition: (screenPosition, options) ->
    screenPosition = @displayBuffer.clipScreenPosition(screenPosition, options)
    @setHeadBufferPosition(@displayBuffer.bufferPositionForScreenPosition(screenPosition, options))

  getHeadBufferPosition: ->
    @buffer.getMarkerHeadPosition(@id)

  setHeadBufferPosition: (bufferPosition) ->
    @buffer.setMarkerHeadPosition(@id, bufferPosition)

  getTailScreenPosition: ->
    if tailBufferPosition = @getTailBufferPosition()
      @displayBuffer.screenPositionForBufferPosition(tailBufferPosition, wrapAtSoftNewlines: true)

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
    @previousHeadScreenPosition = @getHeadScreenPosition()
    @previousTailScreenPosition = @getTailScreenPosition()
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
    oldHeadScreenPosition = @previousHeadScreenPosition
    newHeadScreenPosition = @getHeadScreenPosition()
    @previousHeadScreenPosition = newHeadScreenPosition

    oldTailScreenPosition = @previousTailScreenPosition
    newTailScreenPosition = @getTailScreenPosition()
    @previousTailScreenPosition = newTailScreenPosition

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
