Range = require 'range'
_ = require 'underscore'
EventEmitter = require 'event-emitter'

module.exports =
class DisplayBufferMarker
  bufferMarkerSubscription: null
  headScreenPosition: null
  tailScreenPosition: null
  valid: true

  ###
  # Internal #
  ###

  constructor: ({@id, @displayBuffer}) ->
    @buffer = @displayBuffer.buffer

  ###
  # Public #
  ###

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

  ###
  # Internal #
  ###

  observe: (callback) ->
    @observeBufferMarkerIfNeeded()
    @on 'changed', callback
    cancel: => @unobserve(callback)

  unobserve: (callback) ->
    @off 'changed', callback
    @unobserveBufferMarkerIfNeeded()

  observeBufferMarkerIfNeeded: ->
    return if @subscriptionCount()
    @getHeadScreenPosition() # memoize current value
    @getTailScreenPosition() # memoize current value
    @bufferMarkerSubscription =
      @buffer.observeMarker @id, ({oldHeadPosition, newHeadPosition, oldTailPosition, newTailPosition, bufferChanged, valid}) =>
        @notifyObservers
          oldHeadBufferPosition: oldHeadPosition
          newHeadBufferPosition: newHeadPosition
          oldTailBufferPosition: oldTailPosition
          newTailBufferPosition: newTailPosition
          bufferChanged: bufferChanged
          valid: valid
    @displayBuffer.markers[@id] = this

  unobserveBufferMarkerIfNeeded: ->
    return if @subscriptionCount()
    @bufferMarkerSubscription.cancel()
    delete @displayBuffer.markers[@id]

  notifyObservers: ({oldHeadBufferPosition, oldTailBufferPosition, bufferChanged, valid} = {}) ->
    oldHeadScreenPosition = @getHeadScreenPosition()
    newHeadScreenPosition = oldHeadScreenPosition
    oldTailScreenPosition = @getTailScreenPosition()
    newTailScreenPosition = oldTailScreenPosition
    valid ?= true

    if valid
      @headScreenPosition = null
      newHeadScreenPosition = @getHeadScreenPosition()
      @tailScreenPosition = null
      newTailScreenPosition = @getTailScreenPosition()

    validChanged = valid isnt @valid
    headScreenPositionChanged = not _.isEqual(newHeadScreenPosition, oldHeadScreenPosition)
    tailScreenPositionChanged = not _.isEqual(newTailScreenPosition, oldTailScreenPosition)
    return unless validChanged or headScreenPositionChanged or tailScreenPositionChanged

    oldHeadBufferPosition ?= @getHeadBufferPosition()
    newHeadBufferPosition = @getHeadBufferPosition() ? oldHeadBufferPosition
    oldTailBufferPosition ?= @getTailBufferPosition()
    newTailBufferPosition = @getTailBufferPosition() ? oldTailBufferPosition
    @valid = valid

    @trigger 'changed', {
      oldHeadScreenPosition, newHeadScreenPosition,
      oldTailScreenPosition, newTailScreenPosition,
      oldHeadBufferPosition, newHeadBufferPosition,
      oldTailBufferPosition, newTailBufferPosition,
      bufferChanged
      valid
    }

_.extend DisplayBufferMarker.prototype, EventEmitter
