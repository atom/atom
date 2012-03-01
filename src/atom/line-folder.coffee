_ = require 'underscore'
Point = require 'point'
Range = require 'range'
LineMap = require 'line-map'
ScreenLineFragment = require 'screen-line-fragment'
EventEmitter = require 'event-emitter'

module.exports =
class LineFolder
  activeFolds: null
  foldsById: null
  lineMap: null
  lastHighlighterChangeEvent: null

  constructor: (@highlighter) ->
    @activeFolds = {}
    @foldsById = {}
    @buildLineMap()
    @highlighter.buffer.on 'change', (e) => @handleBufferChange(e)
    @highlighter.on 'change', (e) => @lastHighlighterChangeEvent = e

  buildLineMap: ->
    @lineMap = new LineMap
    @lineMap.insertAtInputRow(0, @highlighter.screenLines)

  logLines: (start=0, end=@lastRow())->
    @lineMap.logLines(start, end)

  createFold: (bufferRange) ->
    return if bufferRange.isEmpty()
    fold = new Fold(this, bufferRange)
    @registerFold(bufferRange.start.row, fold)
    oldScreenRange = @expandScreenRangeToLineEnds(@screenRangeForBufferRange(bufferRange))

    lineWithFold = @buildLineForBufferRow(bufferRange.start.row)
    @lineMap.replaceOutputRows(oldScreenRange.start.row, oldScreenRange.end.row, lineWithFold)

    newScreenRange = oldScreenRange.copy()
    newScreenRange.end = _.clone(newScreenRange.start)
    for fragment in lineWithFold
      newScreenRange.end.column += fragment.text.length

    @trigger 'change', oldRange: oldScreenRange, newRange: newScreenRange
    @trigger 'fold', bufferRange
    fold

  destroyFold: (fold) ->
    bufferRange = fold.getRange()
    @unregisterFold(bufferRange.start.row, fold)
    startScreenRow = @screenRowForBufferRow(bufferRange.start.row)

    oldScreenRange = new Range()
    oldScreenRange.start.row = startScreenRow
    oldScreenRange.end.row = startScreenRow
    oldScreenRange.end.column = @lineMap.lineForOutputRow(startScreenRow).text.length

    @lineMap.replaceOutputRow(startScreenRow, @buildLinesForBufferRows(bufferRange.start.row, bufferRange.end.row))

    newScreenRange = @expandScreenRangeToLineEnds(@screenRangeForBufferRange(bufferRange))

    @trigger 'change', oldRange: oldScreenRange, newRange: newScreenRange
    @trigger 'unfold', fold.getRange()

  registerFold: (bufferRow, fold) ->
    @activeFolds[bufferRow] ?= []
    @activeFolds[bufferRow].push(fold)
    @foldsById[fold.id] = fold

  unregisterFold: (bufferRow, fold) ->
    folds = @activeFolds[bufferRow]
    folds.splice(folds.indexOf(fold), 1)
    delete @foldsById[fold.id]

  handleBufferChange: (e) ->
    for row, folds of @activeFolds
      fold.handleBufferChange(e) for fold in folds
    @handleHighlighterChange(@lastHighlighterChangeEvent)

  handleHighlighterChange: (e) ->
    oldScreenRange = @screenRangeForBufferRange(e.oldRange)
    expandedOldScreenRange = @expandScreenRangeToLineEnds(oldScreenRange)
    lines = @buildLinesForBufferRows(e.newRange.start.row, e.newRange.end.row)
    @lineMap.replaceOutputRows(oldScreenRange.start.row, oldScreenRange.end.row, lines)
    newScreenRange = @screenRangeForBufferRange(e.newRange)
    expandedNewScreenRange = @expandScreenRangeToLineEnds(newScreenRange)

    unless oldScreenRange.isEmpty() and newScreenRange.isEmpty()
      @trigger 'change', oldRange: expandedOldScreenRange, newRange: expandedNewScreenRange

  buildLineForBufferRow: (bufferRow) ->
    @buildLinesForBufferRows(bufferRow, bufferRow)

  buildLinesForBufferRows: (startRow, endRow) ->
    @$buildLinesForBufferRows(@foldStartRowForBufferRow(startRow), endRow)

  $buildLinesForBufferRows: (startRow, endRow, startColumn) ->
    return [] if startRow > endRow and not startColumn?
    startColumn ?= 0

    screenLine = @highlighter.lineForScreenRow(startRow).splitAt(startColumn)[1]

    for fold in @foldsForBufferRow(startRow)
      { start, end } = fold.getRange()
      if start.column >= startColumn
        prefix = screenLine.splitAt(start.column - startColumn)[0]
        suffix = @$buildLinesForBufferRows(end.row, endRow, end.column)
        return _.compact(_.flatten([prefix, @buildFoldPlaceholder(fold), suffix]))

    [screenLine].concat(@$buildLinesForBufferRows(startRow + 1, endRow))

  foldStartRowForBufferRow: (bufferRow) ->
    @bufferRowForScreenRow(@screenRowForBufferRow(bufferRow))

  buildFoldPlaceholder: (fold) ->
    new ScreenLineFragment([{value: '...', type: 'fold-placeholder', fold}], '...', [0, 3], fold.getRange().toDelta(), isAtomic: true)

  foldsForBufferRow: (bufferRow) ->
    folds = @activeFolds[bufferRow] or []
    folds.sort (a, b) -> a.compare(b)

  linesForScreenRows: (startRow, endRow) ->
    @lineMap.linesForOutputRows(startRow, endRow)

  lineForScreenRow: (screenRow) ->
    @lineMap.lineForOutputRow(screenRow)

  getLines: ->
    @lineMap.linesForOutputRows(0, @lastRow())

  lineCount: ->
    @lineMap.outputLineCount()

  lastRow: ->
    @lineCount() - 1

  screenRowForBufferRow: (bufferRow) ->
    @screenPositionForBufferPosition([bufferRow, 0]).row

  bufferRowForScreenRow: (screenRow) ->
    @bufferPositionForScreenPosition([screenRow, 0]).row

  screenPositionForBufferPosition: (bufferPosition) ->
    @lineMap.outputPositionForInputPosition(bufferPosition)

  bufferPositionForScreenPosition: (screenPosition) ->
    @lineMap.inputPositionForOutputPosition(screenPosition)

  clipScreenPosition: (screenPosition, options={}) ->
    @lineMap.clipOutputPosition(screenPosition, options)

  screenRangeForBufferRange: (bufferRange) ->
    @lineMap.outputRangeForInputRange(bufferRange)

  bufferRangeForScreenRange: (screenRange) ->
    @lineMap.inputRangeForOutputRange(screenRange)

  expandScreenRangeToLineEnds: (screenRange) ->
    { start, end } = screenRange
    new Range([start.row, 0], [end.row, @lineMap.lineForOutputRow(end.row).text.length])

_.extend LineFolder.prototype, EventEmitter

class Fold
  @idCounter: 1

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


