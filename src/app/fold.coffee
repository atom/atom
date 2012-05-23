Range = require 'range'
Point = require 'point'

module.exports =
class Fold
  @idCounter: 1

  renderer: null
  startRow: null
  endRow: null

  constructor: (@renderer, @startRow, @endRow) ->
    @id = @constructor.idCounter++

  destroy: ->
    @renderer.destroyFold(this)

  inspect: ->
    "Fold(#{@startRow}, #{@endRow})"

  getBufferDelta: ->
    new Point(@endRow - @startRow + 1, 0)

  handleBufferChange: (event) ->
    oldStartRow = @startRow

    if @isContainedByRange(event.oldRange)
      @renderer.unregisterFold(@startRow, this)
      return

    @updateStartRow(event)
    @updateEndRow(event)

    if @startRow != oldStartRow
      @renderer.unregisterFold(oldStartRow, this)
      @renderer.registerFold(@startRow, this)

  isContainedByRange: (range) ->
    range.start.row <= @startRow and @endRow <= range.end.row

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
