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

  getRange: ->
    throw "Don't worry about this yet -- sobo"

  getBufferDelta: ->
    new Point(@endRow - @startRow + 1, 0)

  handleBufferChange: (event) ->
    oldStartRow = @startRow

    { oldRange } = event
    if oldRange.start.row <= @startRow and oldRange.end.row >= @endRow
      @renderer.unregisterFold(oldStartRow, this)
      return

    changeInsideFold = @startRow <= oldRange.start.row and @endRow >= oldRange.end.row
    @startRow = @updateAnchorRow(@startRow, event)
    @endRow = @updateAnchorRow(@endRow, event)

    if @startRow != oldStartRow
      @renderer.unregisterFold(oldStartRow, this)
      @renderer.registerFold(@startRow, this)

    changeInsideFold

  updateAnchorRow: (row, event) ->
    { newRange, oldRange } = event
    return row if row < oldRange.start.row

    deltaFromOldRangeEndRow = row - oldRange.end.row
    newRange.end.row + deltaFromOldRangeEndRow

  compare: (other) ->
    other
    # startComparison = @start.compare(other.start)
    # if startComparison == 0
    #   other.end.compare(@end)
    # else
    #   startComparison
