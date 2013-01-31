_ = require 'underscore'
Point = require 'point'
Range = require 'range'

module.exports =
class BufferMarker
  headPosition: null
  tailPosition: null
  stayValid: false

  constructor: ({@id, @buffer, range, @stayValid, noTail, reverse}) ->
    @setRange(range, {noTail, reverse})

  setRange: (range, options={}) ->
    range = @buffer.clipRange(range)
    if options.reverse
      @tailPosition = range.end unless options.noTail
      @headPosition = range.start
    else
      @tailPosition = range.start unless options.noTail
      @headPosition = range.end

  isReversed: ->
    @tailPosition? and @headPosition.isLessThan(@tailPosition)

  getRange: ->
    if @tailPosition
      new Range(@tailPosition, @headPosition)
    else
      new Range(@headPosition, @headPosition)

  getHeadPosition: -> @headPosition

  getTailPosition: -> @tailPosition

  getStartPosition: ->
    @getRange().start

  getEndPosition: ->
    @getRange().end

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
    @setTailPosition(@updatePosition(@tailPosition, bufferChange, true), clip: false)
    @setHeadPosition(@updatePosition(@headPosition, bufferChange, false), clip: false)

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

  setTailPosition: (tailPosition, options={}) ->
    @tailPosition = Point.fromObject(tailPosition)
    @tailPosition = @buffer.clipPosition(@tailPosition) if options.clip ? true

  setHeadPosition: (headPosition, options={}) ->
    @headPosition = Point.fromObject(headPosition)
    @headPosition = @buffer.clipPosition(@headPosition) if options.clip ? true

  getPosition: ->
    @position

  invalidate: (preserve) ->
    delete @buffer.validMarkers[@id]
    @buffer.invalidMarkers[@id] = this
