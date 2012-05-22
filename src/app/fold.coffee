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

  getBufferDelta: ->
    new Point(@endRow - @startRow + 1, 0)

  handleBufferChange: (event) ->
    oldStartRow = @startRow

    { oldRange } = event
    if oldRange.start.row <= @startRow and oldRange.end.row >= @endRow
      @renderer.unregisterFold(oldStartRow, this)
      return

    changeInsideFold = @startRow <= oldRange.start.row and @endRow >= oldRange.end.row
    @updateStartRow(event)
    @updateEndRow(event)

    if @startRow != oldStartRow
      @renderer.unregisterFold(oldStartRow, this)
      @renderer.registerFold(@startRow, this)

    changeInsideFold

  updateStartRow: (event) ->
    { newRange, oldRange } = event
    return if oldRange.start.row >= @startRow

    deltaFromOldRangeEndRow = @startRow - oldRange.end.row
    @startRow = newRange.end.row + deltaFromOldRangeEndRow

  updateEndRow: (event) ->
    { newRange, oldRange } = event
    return if oldRange.start.row > @endRow

    deltaFromOldRangeEndRow = @endRow - oldRange.end.row
    @endRow = newRange.end.row + deltaFromOldRangeEndRow
