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

  getBufferRowCount: ->
    @endRow - @startRow + 1

  handleBufferChange: (event) ->
    oldStartRow = @startRow

    if @isContainedByRange(event.oldRange)
      @displayBuffer.unregisterFold(@startRow, this)
      return

    @startRow += @getRowDelta(event, @startRow)
    @endRow += @getRowDelta(event, @endRow)

    if @startRow != oldStartRow
      @displayBuffer.unregisterFold(oldStartRow, this)
      @displayBuffer.registerFold(this)

  isContainedByRange: (range) ->
    range.start.row <= @startRow and @endRow <= range.end.row

  isContainedByFold: (fold) ->
    @isContainedByRange(fold.getBufferRange())

  getRowDelta: (event, row) ->
    { newRange, oldRange } = event

    if oldRange.end.row <= row
      newRange.end.row - oldRange.end.row
    else if newRange.end.row < row
      newRange.end.row - row
    else
      0
