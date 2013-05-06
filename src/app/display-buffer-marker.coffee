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

  constructor: ({@bufferMarker, @displayBuffer}) ->
    @id = @bufferMarker.id
    @observeBufferMarker()

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
    @bufferMarker.getRange()

  # Modifies the buffer range of the display marker.
  #
  # screenRange - The new {Range} to use
  # options - A hash of options matching those found in {BufferMarker.setRange}
  setBufferRange: (bufferRange, options) ->
    @bufferMarker.setRange(bufferRange, options)

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
    @bufferMarker.getHeadPosition()

  # Sets the buffer position of the marker's head.
  #
  # screenRange - The new {Point} to use
  # options - A hash of options matching those found in {DisplayBuffer.bufferPositionForScreenPosition}
  setHeadBufferPosition: (bufferPosition) ->
    @bufferMarker.setHeadPosition(bufferPosition)

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
    @bufferMarker.getTailPosition()

  # Sets the buffer position of the marker's tail.
  #
  # screenRange - The new {Point} to use
  # options - A hash of options matching those found in {DisplayBuffer.bufferPositionForScreenPosition}
  setTailBufferPosition: (bufferPosition) ->
    @bufferMarker.setTailPosition(bufferPosition)

  # Sets the marker's tail to the same position as the marker's head.
  #
  # This only works if there isn't already a tail position.
  #
  # Returns a {Point} representing the new tail position.
  placeTail: ->
    @bufferMarker.placeTail()

  # Removes the tail from the marker.
  clearTail: ->
    @bufferMarker.clearTail()

  # Returns whether the head precedes the tail in the buffer
  isReversed: ->
    @bufferMarker.isReversed()

  # Returns a {Boolean} indicating whether the marker is valid. Markers can be
  # invalidated when a region surrounding them in the buffer is changed.
  isValid: ->
    @bufferMarker.isValid()

  # Returns a {Boolean} indicating whether the marker has been destroyed. A marker
  # can be invalid without being destroyed, in which case undoing the invalidating
  # operation would restore the marker. Once a marker is destroyed by calling
  # {BufferMarker.destroy}, no undo/redo operation can ever bring it back.
  isDestroyed: ->
    @bufferMarker.isDestroyed()

  matchesAttributes: (attributes) ->
    @bufferMarker.matchesAttributes(attributes)

  # Destroys the marker
  destroy: ->
    @bufferMarker.destroy()

  # Returns a {String} representation of the marker
  inspect: ->
    "DisplayBufferMarker(id: #{@id}, bufferRange: #{@getBufferRange().inspect()})"

  ### Internal ###

  destroyed: ->
    delete @displayBuffer.markers[@id]
    @trigger 'destroyed'

  observeBufferMarker: ->
    @bufferMarker.on 'destroyed', => @destroyed()

    @getHeadScreenPosition() # memoize current value
    @getTailScreenPosition() # memoize current value
    @bufferMarker.on 'changed', ({oldHeadPosition, newHeadPosition, oldTailPosition, newTailPosition, bufferChanged, valid}) =>
      @notifyObservers
        oldHeadBufferPosition: oldHeadPosition
        newHeadBufferPosition: newHeadPosition
        oldTailBufferPosition: oldTailPosition
        newTailBufferPosition: newTailPosition
        bufferChanged: bufferChanged
        valid: valid

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
