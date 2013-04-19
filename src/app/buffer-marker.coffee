_ = require 'underscore'
Point = require 'point'
Range = require 'range'
EventEmitter = require 'event-emitter'

module.exports =
class BufferMarker
  headPosition: null
  tailPosition: null
  suppressObserverNotification: false
  invalidationStrategy: null

  ###
  # Internal #
  ###
  constructor: ({@id, @buffer, range, @invalidationStrategy, noTail, reverse}) ->
    @invalidationStrategy ?= 'contains'
    @setRange(range, {noTail, reverse})

  ###
  # Public #
  ###

  # Public: Sets the marker's range, potentialy modifying both its head and tail.
  #
  # range - The new {Range} the marker should cover
  # options - A hash of options with the following keys:
  #           :reverse - if `true`, the marker is reversed; that is, its tail is "above" the head
  #           :noTail - if `true`, the marker doesn't have a tail
  setRange: (range, options={}) ->
    @consolidateObserverNotifications false, =>
      range = Range.fromObject(range)
      if options.reverse
        @setTailPosition(range.end) unless options.noTail
        @setHeadPosition(range.start)
      else
        @setTailPosition(range.start) unless options.noTail
        @setHeadPosition(range.end)

  # Public: Identifies if the ending position of a marker is greater than the starting position.
  #
  # This can happen when, for example, you highlight text "up" in a {Buffer}.
  #
  # Returns a {Boolean}.
  isReversed: ->
    @tailPosition? and @headPosition.isLessThan(@tailPosition)

  # Public: Identifies if the marker's head position is equal to its tail.
  #
  # Returns a {Boolean}.
  isRangeEmpty: ->
    @getHeadPosition().isEqual(@getTailPosition())

  # Public: Retrieves the {Range} between a marker's head and its tail. 
  # 
  # Returns a {Range}.
  getRange: ->
    if @tailPosition
      new Range(@tailPosition, @headPosition)
    else
      new Range(@headPosition, @headPosition)

  # Public: Retrieves the position of the marker's head.
  #
  # Returns a {Point}.
  getHeadPosition: -> @headPosition

  # Public: Retrieves the position of the marker's tail.
  #
  # Returns a {Point}.
  getTailPosition: -> @tailPosition ? @getHeadPosition()

  # Public: Sets the position of the marker's head.
  #
  # newHeadPosition - The new {Point} to place the head
  # options - A hash with the following keys:
  #         :clip - if `true`, the point is [clipped]{Buffer.clipPosition}
  #         :bufferChanged - if `true`, indicates that the {Buffer} should trigger an event that it's changed
  #
  # Returns a {Point} representing the new head position.
  setHeadPosition: (newHeadPosition, options={}) ->
    oldHeadPosition = @getHeadPosition()
    newHeadPosition = Point.fromObject(newHeadPosition)
    newHeadPosition = @buffer.clipPosition(newHeadPosition) if options.clip ? true
    return if newHeadPosition.isEqual(@headPosition)
    @headPosition = newHeadPosition
    bufferChanged = !!options.bufferChanged
    @notifyObservers({oldHeadPosition, newHeadPosition, bufferChanged})
    @headPosition

  # Public: Sets the position of the marker's tail.
  #
  # newHeadPosition - The new {Point} to place the tail
  # options - A hash with the following keys:
  #         :clip - if `true`, the point is [clipped]{Buffer.clipPosition}
  #         :bufferChanged - if `true`, indicates that the {Buffer} should trigger an event that it's changed
  #
  # Returns a {Point} representing the new tail position.
  setTailPosition: (newTailPosition, options={}) ->
    oldTailPosition = @getTailPosition()
    newTailPosition = Point.fromObject(newTailPosition)
    newTailPosition = @buffer.clipPosition(newTailPosition) if options.clip ? true
    return if newTailPosition.isEqual(@tailPosition)
    @tailPosition = newTailPosition
    bufferChanged = !!options.bufferChanged
    @notifyObservers({oldTailPosition, newTailPosition, bufferChanged})
    @tailPosition

  # Public: Retrieves the starting position of the marker.
  #
  # Returns a {Point}.
  getStartPosition: ->
    @getRange().start

  # Public: Retrieves the ending position of the marker.
  #
  # Returns a {Point}.
  getEndPosition: ->
    @getRange().end

  # Public: Sets the marker's tail to the same position as the marker's head.
  #
  # This only works if there isn't already a tail position.
  #
  # Returns a {Point} representing the new tail position.
  placeTail: ->
    @setTailPosition(@getHeadPosition()) unless @tailPosition

  # Public: Removes the tail from the marker.
  clearTail: ->
    oldTailPosition = @getTailPosition()
    @tailPosition = null
    newTailPosition = @getTailPosition()
    @notifyObservers({oldTailPosition, newTailPosition, bufferChanged: false})

  # Public: Identifies if a {Point} is within the marker.
  #
  # Returns a {Boolean}.
  containsPoint: (point) ->
    @getRange().containsPoint(point)

  # Public: Sets a callback to be fired whenever a marker is changed.
  observe: (callback) ->
    @on 'changed', callback
    cancel: => @unobserve(callback)

  # Public: Removes the fired callback whenever a marker changes.
  unobserve: (callback) ->
    @off 'changed', callback

  ###
  # Internal #
  ###

  tryToInvalidate: (changedRange) ->
    betweenStartAndEnd = @getRange().containsRange(changedRange, exclusive: false)
    containsStart = changedRange.containsPoint(@getStartPosition(), exclusive: true)
    containsEnd = changedRange.containsPoint(@getEndPosition(), exclusive: true)

    switch @invalidationStrategy
      when 'between'
        if betweenStartAndEnd or containsStart or containsEnd
          @invalidate()
          [@id]
      when 'contains'
        if containsStart or containsEnd
          @invalidate()
          [@id]
      when 'never'
        if containsStart or containsEnd
          previousRange = @getRange()
          if containsStart and containsEnd
            @setRange([changedRange.end, changedRange.end])
          else if containsStart
            @setRange([changedRange.end, @getEndPosition()])
          else
            @setRange([@getStartPosition(), changedRange.start])
          [@id, previousRange]

  handleBufferChange: (bufferChange) ->
    @consolidateObserverNotifications true, =>
      @setHeadPosition(@updatePosition(@headPosition, bufferChange, true), clip: false, bufferChanged: true)
      @setTailPosition(@updatePosition(@tailPosition, bufferChange, false), clip: false, bufferChanged: true) if @tailPosition

  updatePosition: (position, bufferChange, isHead) ->
    { oldRange, newRange } = bufferChange

    return position if not isHead and oldRange.start.isEqual(position)
    return position if position.isLessThan(oldRange.end)

    newRow = newRange.end.row
    newColumn = newRange.end.column

    if position.row == oldRange.end.row
      newColumn += position.column - oldRange.end.column
    else
      newColumn = position.column
      newRow += position.row - oldRange.end.row

    [newRow, newColumn]

  notifyObservers: ({oldHeadPosition, newHeadPosition, oldTailPosition, newTailPosition, bufferChanged} = {}) ->
    return if @suppressObserverNotification

    if newHeadPosition? and newTailPosition?
      return if _.isEqual(newHeadPosition, oldHeadPosition) and _.isEqual(newTailPosition, oldTailPosition)
    else if newHeadPosition?
      return if _.isEqual(newHeadPosition, oldHeadPosition)
    else if newTailPosition?
      return if _.isEqual(newTailPosition, oldTailPosition)

    oldHeadPosition ?= @getHeadPosition()
    newHeadPosition ?= @getHeadPosition()
    oldTailPosition ?= @getTailPosition()
    newTailPosition ?= @getTailPosition()
    valid = @buffer.validMarkers[@id]?
    @trigger 'changed', {oldHeadPosition, newHeadPosition, oldTailPosition, newTailPosition, bufferChanged, valid}

  consolidateObserverNotifications: (bufferChanged, fn) ->
    @suppressObserverNotification = true
    oldHeadPosition = @getHeadPosition()
    oldTailPosition = @getTailPosition()
    fn()
    newHeadPosition = @getHeadPosition()
    newTailPosition = @getTailPosition()
    @suppressObserverNotification = false
    @notifyObservers({oldHeadPosition, newHeadPosition, oldTailPosition, newTailPosition, bufferChanged})

  invalidate: ->
    delete @buffer.validMarkers[@id]
    @buffer.invalidMarkers[@id] = this
    @notifyObservers(bufferChanged: true)

  revalidate: ->
    delete @buffer.invalidMarkers[@id]
    @buffer.validMarkers[@id] = this
    @notifyObservers(bufferChanged: true)

_.extend BufferMarker.prototype, EventEmitter
