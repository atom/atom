Range = require 'range'
Point = require 'point'

module.exports =
class Fold
  @idCounter: 1

  displayBuffer: null
  startRow: null
  endRow: null

  constructor: (@displayBuffer, @startRow, @endRow) ->
    @id = @constructor.idCounter++

  destroy: ->
    @displayBuffer.destroyFold(this)

  inspect: ->
    "Fold(#{@startRow}, #{@endRow})"

  getBufferRange: ({includeNewline}={}) ->
    if includeNewline
      end = [@endRow + 1, 0]
    else
      end = [@endRow, Infinity]

    new Range([@startRow, 0], end)

  getBufferDelta: ->
    new Point(@endRow - @startRow + 1, 0)

  handleBufferChange: (event) ->
    oldStartRow = @startRow

    if @isContainedByRange(event.oldRange)
      @displayBuffer.unregisterFold(@startRow, this)
      return

    @updateStartRow(event)
    @updateEndRow(event)

    if @startRow != oldStartRow
      @displayBuffer.unregisterFold(oldStartRow, this)
      @displayBuffer.registerFold(this)

  isContainedByRange: (range) ->
    range.start.row <= @startRow and @endRow <= range.end.row

  isContainedByFold: (fold) ->
    @isContainedByRange(fold.getBufferRange())

  updateStartRow: (event) ->
    { newRange, oldRange } = event

    if oldRange.end.row < @startRow
      delta = newRange.end.row - oldRange.end.row
    else if newRange.end.row < @startRow
      delta = newRange.end.row - @startRow
    else
      delta = 0

    @startRow += delta

  updateEndRow: (event) ->
    { newRange, oldRange } = event

    if oldRange.end.row <= @endRow
      delta = newRange.end.row - oldRange.end.row
    else if newRange.end.row <= @endRow
      delta = newRange.end.row - @endRow
    else
      delta = 0

    @endRow += delta
