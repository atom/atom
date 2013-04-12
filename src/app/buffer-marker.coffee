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

  constructor: ({@id, @buffer, range, @invalidationStrategy, noTail, reverse}) ->
    @invalidationStrategy ?= 'contains'
    @setRange(range, {noTail, reverse})

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

  isRangeEmpty: ->
    @getHeadPosition().isEqual(@getTailPosition())

  getRange: ->
    if @tailPosition
      new Range(@tailPosition, @headPosition)
    else
      new Range(@headPosition, @headPosition)

  getHeadPosition: -> @headPosition

  getTailPosition: -> @tailPosition ? @getHeadPosition()

  setHeadPosition: (newHeadPosition, options={}) ->
    oldHeadPosition = @getHeadPosition()
    newHeadPosition = Point.fromObject(newHeadPosition)
    newHeadPosition = @buffer.clipPosition(newHeadPosition) if options.clip ? true
    return if newHeadPosition.isEqual(@headPosition)
    @headPosition = newHeadPosition
    bufferChanged = !!options.bufferChanged
    @notifyObservers({oldHeadPosition, newHeadPosition, bufferChanged})
    @headPosition

  setTailPosition: (newTailPosition, options={}) ->
    oldTailPosition = @getTailPosition()
    newTailPosition = Point.fromObject(newTailPosition)
    newTailPosition = @buffer.clipPosition(newTailPosition) if options.clip ? true
    return if newTailPosition.isEqual(@tailPosition)
    @tailPosition = newTailPosition
    bufferChanged = !!options.bufferChanged
    @notifyObservers({oldTailPosition, newTailPosition, bufferChanged})
    @tailPosition

  getStartPosition: ->
    @getRange().start

  getEndPosition: ->
    @getRange().end

  placeTail: ->
    @setTailPosition(@getHeadPosition()) unless @tailPosition

  clearTail: ->
    oldTailPosition = @getTailPosition()
    @tailPosition = null
    newTailPosition = @getTailPosition()
    @notifyObservers({oldTailPosition, newTailPosition, bufferChanged: false})

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
      @setHeadPosition(@updatePosition(@headPosition, bufferChange, false), clip: false, bufferChanged: true)
      @setTailPosition(@updatePosition(@tailPosition, bufferChange, true), clip: false, bufferChanged: true) if @tailPosition

  updatePosition: (position, bufferChange, isFirstPoint) ->
    { oldRange, newRange } = bufferChange

    return position if oldRange.containsPoint(position, exclusive: true)
    return position if isFirstPoint and oldRange.start.isEqual(position)
    return position if position.isLessThan(oldRange.end)

    newRow = newRange.end.row
    newColumn = newRange.end.column

    if position.row == oldRange.end.row
      newColumn += position.column - oldRange.end.column
    else
      newColumn = position.column
      newRow += position.row - oldRange.end.row

    [newRow, newColumn]

  observe: (callback) ->
    @on 'changed', callback
    cancel: => @unobserve(callback)

  unobserve: (callback) ->
    @off 'changed', callback

  containsPoint: (point) ->
    @getRange().containsPoint(point)

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
