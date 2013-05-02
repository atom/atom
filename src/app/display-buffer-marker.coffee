Range = require 'range'
_ = require 'underscore'
EventEmitter = require 'event-emitter'

module.exports =
class DisplayBufferMarker
  bufferMarkerSubscription: null
  headScreenPosition: null
  tailScreenPosition: null
  valid: true

  ### Internal ###

  constructor: ({@id, @displayBuffer}) ->
    @buffer = @displayBuffer.buffer

  ### Public ###

  # Gets the screen range of the display marker.
  #
  # Returns a {Range}.
  getScreenRange: ->
    @displayBuffer.screenRangeForBufferRange(@getBufferRange(), wrapAtSoftNewlines: true)

  # Modifies the screen range of the display marker.
  #
  # screenRange - The new {Range} to use
  # options - A hash of options matching those found in {BufferMarker.setRange}
  setScreenRange: (screenRange, options) ->
    @setBufferRange(@displayBuffer.bufferRangeForScreenRange(screenRange), options)

  # Gets the buffer range of the display marker.
  #
  # Returns a {Range}.
  getBufferRange: ->
    @buffer.getMarkerRange(@id)

  # Modifies the buffer range of the display marker.
  #
  # screenRange - The new {Range} to use
  # options - A hash of options matching those found in {BufferMarker.setRange}
  setBufferRange: (bufferRange, options) ->
    @buffer.setMarkerRange(@id, bufferRange, options)

  # Retrieves the screen position of the marker's head.
  #
  # Returns a {Point}.
  getHeadScreenPosition: ->
    @headScreenPosition ?= @displayBuffer.screenPositionForBufferPosition(@getHeadBufferPosition(), wrapAtSoftNewlines: true)

  # Sets the screen position of the marker's head.
  #
  # screenRange - The new {Point} to use
  # options - A hash of options matching those found in {DisplayBuffer.bufferPositionForScreenPosition}
  setHeadScreenPosition: (screenPosition, options) ->
    screenPosition = @displayBuffer.clipScreenPosition(screenPosition, options)
    @setHeadBufferPosition(@displayBuffer.bufferPositionForScreenPosition(screenPosition, options))

  # Retrieves the buffer position of the marker's head.
  #
  # Returns a {Point}.
  getHeadBufferPosition: ->
    @buffer.getMarkerHeadPosition(@id)

  # Sets the buffer position of the marker's head.
  #
  # screenRange - The new {Point} to use
  # options - A hash of options matching those found in {DisplayBuffer.bufferPositionForScreenPosition}
  setHeadBufferPosition: (bufferPosition) ->
    @buffer.setMarkerHeadPosition(@id, bufferPosition)

  # Retrieves the screen position of the marker's tail.
  #
  # Returns a {Point}.
  getTailScreenPosition: ->
    @tailScreenPosition ?= @displayBuffer.screenPositionForBufferPosition(@getTailBufferPosition(), wrapAtSoftNewlines: true)
  
  # Sets the screen position of the marker's tail.
  #
  # screenRange - The new {Point} to use
  # options - A hash of options matching those found in {DisplayBuffer.bufferPositionForScreenPosition}
  setTailScreenPosition: (screenPosition, options) ->
    screenPosition = @displayBuffer.clipScreenPosition(screenPosition, options)
    @setTailBufferPosition(@displayBuffer.bufferPositionForScreenPosition(screenPosition, options))

  # Retrieves the buffer position of the marker's tail.
  #
  # Returns a {Point}.
  getTailBufferPosition: ->
    @buffer.getMarkerTailPosition(@id)
  
  # Sets the buffer position of the marker's tail.
  #
  # screenRange - The new {Point} to use
  # options - A hash of options matching those found in {DisplayBuffer.bufferPositionForScreenPosition}
  setTailBufferPosition: (bufferPosition) ->
    @buffer.setMarkerTailPosition(@id, bufferPosition)

  # Sets the marker's tail to the same position as the marker's head.
  #
  # This only works if there isn't already a tail position.
  #
  # Returns a {Point} representing the new tail position.
  placeTail: ->
    @buffer.placeMarkerTail(@id)

  # Removes the tail from the marker.
  clearTail: ->
    @buffer.clearMarkerTail(@id)

  # Sets a callback to be fired whenever the marker is changed.
  #
  # callback - A {Function} to execute
  observe: (callback) ->
    @observeBufferMarkerIfNeeded()
    @on 'changed', callback
    cancel: => @unobserve(callback)

  # Removes the callback that's fired whenever the marker changes.
  #
  # callback - A {Function} to remove
  unobserve: (callback) ->
    @off 'changed', callback
    @unobserveBufferMarkerIfNeeded()

  ### Internal ###

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
