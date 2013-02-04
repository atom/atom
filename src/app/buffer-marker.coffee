_ = require 'underscore'
Point = require 'point'
Range = require 'range'

module.exports =
class BufferMarker
  headPosition: null
  tailPosition: null
  headPositionObservers: null
  rangeObservers: null
  disableRangeChanged: false
  stayValid: false

  constructor: ({@id, @buffer, range, @stayValid, noTail, reverse}) ->
    @headPositionObservers = []
    @rangeObservers = []
    @setRange(range, {noTail, reverse})

  setRange: (range, options={}) ->
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

  getTailPosition: -> @tailPosition

  setHeadPosition: (headPosition, options={}) ->
    oldPosition = @headPosition
    oldRange = @getRange()
    @headPosition = Point.fromObject(headPosition)
    @headPosition = @buffer.clipPosition(@headPosition) if options.clip ? true
    newPosition = @headPosition
    newRange = @getRange()
    bufferChanged = !!options.bufferChanged
    unless newPosition.isEqual(oldPosition)
      @headPositionChanged({oldPosition, newPosition, bufferChanged})
      @rangeChanged({oldRange, newRange, bufferChanged})
    @headPosition

  headPositionChanged: ({oldPosition, newPosition, bufferChanged}) ->
    observer({oldPosition, newPosition, bufferChanged}) for observer in @getHeadPositionObservers()

  getHeadPositionObservers: ->
    new Array(@headPositionObservers...)

  rangeChanged: ({oldRange, newRange, bufferChanged}) ->
    unless @disableRangeChanged
      observer({oldRange, newRange, bufferChanged}) for observer in @getRangeObservers()

  getRangeObservers: ->
    new Array(@rangeObservers...)

  setTailPosition: (tailPosition, options={}) ->
    oldRange = @getRange()
    @tailPosition = Point.fromObject(tailPosition)
    @tailPosition = @buffer.clipPosition(@tailPosition) if options.clip ? true
    newRange = @getRange()
    bufferChanged = !!options.bufferChanged
    @rangeChanged({oldRange, newRange, bufferChanged}) unless newRange.isEqual(oldRange)
    @tailPosition

  getStartPosition: ->
    @getRange().start

  getEndPosition: ->
    @getRange().end

  placeTail: ->
    @setTailPosition(@headPosition) unless @tailPosition

  clearTail: ->
    @tailPosition = null

  observeHeadPosition: (callback) ->
    @headPositionObservers.push(callback)
    cancel: => @unobserveHeadPosition(callback)

  unobserveHeadPosition: (callback) ->
    _.remove(@headPositionObservers, callback)

  observeRange: (callback) ->
    @rangeObservers.push(callback)
    cancel: => @unobserveRange(callback)

  unobserveRange: (callback) ->
    _.remove(@rangeObservers, callback)

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
    @disableRangeChanged = true
    oldRange = @getRange()
    @setHeadPosition(@updatePosition(@headPosition, bufferChange, false), clip: false, bufferChanged: true)
    @setTailPosition(@updatePosition(@tailPosition, bufferChange, true), clip: false, bufferChanged: true) if @tailPosition
    newRange = @getRange()
    @disableRangeChanged = false
    @rangeChanged({oldRange, newRange, bufferChanged: true}) unless newRange.isEqual(oldRange)

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

  invalidate: (preserve) ->
    delete @buffer.validMarkers[@id]
    @buffer.invalidMarkers[@id] = this
