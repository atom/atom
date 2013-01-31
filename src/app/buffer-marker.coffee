_ = require 'underscore'
Point = require 'point'
Range = require 'range'

module.exports =
class BufferMarker
  headPosition: null
  tailPosition: null
  headPositionObservers: null
  stayValid: false

  constructor: ({@id, @buffer, range, @stayValid, noTail, reverse}) ->
    @headPositionObservers = []
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
    @headPosition = Point.fromObject(headPosition)
    @headPosition = @buffer.clipPosition(@headPosition) if options.clip ? true
    observer(@headPosition) for observer in @headPositionObservers
    @headPosition

  setTailPosition: (tailPosition, options={}) ->
    @tailPosition = Point.fromObject(tailPosition)
    @tailPosition = @buffer.clipPosition(@tailPosition) if options.clip ? true

  getStartPosition: ->
    @getRange().start

  getEndPosition: ->
    @getRange().end

  observeHeadPosition: (callback) ->
    @headPositionObservers.push(callback)
    cancel: =>
      _.remove(@headPositionObservers, callback)

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
    @setHeadPosition(@updatePosition(@headPosition, bufferChange, false), clip: false)
    @setTailPosition(@updatePosition(@tailPosition, bufferChange, true), clip: false) if @tailPosition

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
