Range = require 'range'

module.exports =
class Fold
  @idCounter: 1
  start: null
  end: null

  constructor: (@lineFolder, {@start, @end}) ->
    @id = @constructor.idCounter++

  destroy: ->
    @lineFolder.destroyFold(this)

  getRange: ->
    new Range(@start, @end)

  handleBufferChange: (event) ->
    oldStartRow = @start.row

    { oldRange } = event
    if oldRange.start.isLessThanOrEqual(@start) and oldRange.end.isGreaterThanOrEqual(@end)
      @lineFolder.unregisterFold(oldStartRow, this)
      return

    @start = @updateAnchorPoint(@start, event)
    @end = @updateAnchorPoint(@end, event, false)

    if @start.row != oldStartRow
      @lineFolder.unregisterFold(oldStartRow, this)
      @lineFolder.registerFold(@start.row, this)

  updateAnchorPoint: (point, event, inclusive=true) ->
    { newRange, oldRange } = event
    if inclusive
      return point if oldRange.end.isGreaterThan(point)
    else
      return point if oldRange.end.isGreaterThanOrEqual(point)

    newRange.end.add(point.subtract(oldRange.end))

  compare: (other) ->
    startComparison = @start.compare(other.start)
    if startComparison == 0
      other.end.compare(@end)
    else
      startComparison
