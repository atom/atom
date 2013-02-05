_ = require 'underscore'
Point = require 'point'
Range = require 'range'

module.exports =
class BufferMarker
  headPosition: null
  tailPosition: null
  observers: null
  suppressObserverNotification: false
  stayValid: false

  constructor: ({@id, @buffer, range, @stayValid, noTail, reverse}) ->
    @headPositionObservers = []
    @observers = []
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

  isReversed: ->
    @tailPosition? and @headPosition.isLessThan(@tailPosition)

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

  tryToInvalidate: (oldRange) ->
    containsStart = oldRange.containsPoint(@getStartPosition(), exclusive: true)
    containsEnd = oldRange.containsPoint(@getEndPosition(), exclusive: true)
    return unless containsEnd or containsStart

    if @stayValid
      previousRange = @getRange()
      if containsStart and containsEnd
        @setRange([oldRange.end, oldRange.end])
      else if containsStart
        @setRange([oldRange.end, @getEndPosition()])
      else
        @setRange([@getStartPosition(), oldRange.start])
      [@id, previousRange]
    else
      @invalidate()
      [@id]

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
    @observers.push(callback)
    cancel: => @unobserve(callback)

  unobserve: (callback) ->
    _.remove(@observers, callback)

  containsPoint: (point) ->
    @getRange().containsPoint(point)

  notifyObservers: ({oldHeadPosition, newHeadPosition, oldTailPosition, newTailPosition, bufferChanged}) ->
    return if @suppressObserverNotification
    return if _.isEqual(newHeadPosition, oldHeadPosition) and _.isEqual(newTailPosition, oldTailPosition)
    oldHeadPosition ?= @getHeadPosition()
    newHeadPosition ?= @getHeadPosition()
    oldTailPosition ?= @getTailPosition()
    newTailPosition ?= @getTailPosition()
    for observer in @getObservers()
      observer({oldHeadPosition, newHeadPosition, oldTailPosition, newTailPosition, bufferChanged})

  getObservers: ->
    new Array(@observers...)

  consolidateObserverNotifications: (bufferChanged, fn) ->
    @suppressObserverNotification = true
    oldHeadPosition = @getHeadPosition()
    oldTailPosition = @getTailPosition()
    fn()
    newHeadPosition = @getHeadPosition()
    newTailPosition = @getTailPosition()
    @suppressObserverNotification = false
    @notifyObservers({oldHeadPosition, newHeadPosition, oldTailPosition, newTailPosition, bufferChanged})

  invalidate: (preserve) ->
    delete @buffer.validMarkers[@id]
    @buffer.invalidMarkers[@id] = this
