Range = require 'range'

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
    # new Range([@startRow, 0], @endRow)
    throw "Don't worry about this yet -- sobo"

  handleBufferChange: (event) ->
    # oldStartRow = @start.row

    # { oldRange } = event
    # if oldRange.start.isLessThanOrEqual(@start) and oldRange.end.isGreaterThanOrEqual(@end)
    #   @renderer.unregisterFold(oldStartRow, this)
    #   return

    # changeInsideFold = @start.isLessThanOrEqual(oldRange.start) and @end.isGreaterThan(oldRange.end)

    # @start = @updateAnchorPoint(@start, event)
    # @end = @updateAnchorPoint(@end, event, false)

    # if @start.row != oldStartRow
    #   @renderer.unregisterFold(oldStartRow, this)
    #   @lineFolder.registerFold(@start.row, this)

    # changeInsideFold

  updateAnchorPoint: (point, event, inclusive=true) ->
    # { newRange, oldRange } = event
    # if inclusive
    #   return point if oldRange.end.isGreaterThan(point)
    # else
    #   return point if oldRange.end.isGreaterThanOrEqual(point)

    # newRange.end.add(point.subtract(oldRange.end))

  compare: (other) ->
    other
    # startComparison = @start.compare(other.start)
    # if startComparison == 0
    #   other.end.compare(@end)
    # else
    #   startComparison
