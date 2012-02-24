_ = require 'underscore'
Point = require 'point'
Range = require 'range'
LineMap = require 'line-map'
ScreenLineFragment = require 'screen-line-fragment'
EventEmitter = require 'event-emitter'

module.exports =
class LineFolder
  lineMap: null
  lastHighlighterChangeEvent: null

  constructor: (@highlighter) ->
    @activeFolds = {}
    @buildLineMap()
    @highlighter.buffer.on 'change', (e) => @handleBufferChange(e)
    @highlighter.on 'change', (e) => @lastHighlighterChangeEvent = e

  buildLineMap: ->
    @lineMap = new LineMap
    @lineMap.insertAtBufferRow(0, @highlighter.screenLines)

  logLines: (start=0, end=@lastRow())->
    for row in [start..end]
      console.log row, @lineForScreenRow(row).text

  createFold: (bufferRange) ->
    fold = new Fold(this, bufferRange)
    @registerFold(bufferRange.start.row, fold)
    oldScreenRange = @expandScreenRangeToLineEnds(@screenRangeForBufferRange(bufferRange))

    lineWithFold = @buildLine(oldScreenRange.start.row)
    @lineMap.replaceScreenRows(oldScreenRange.start.row, oldScreenRange.end.row, lineWithFold)

    newScreenRange = oldScreenRange.copy()
    newScreenRange.end = _.clone(newScreenRange.start)
    for fragment in lineWithFold
      newScreenRange.end.column += fragment.text.length

    @trigger 'change', oldRange: oldScreenRange, newRange: newScreenRange
    fold

  destroyFold: (fold) ->
    bufferRange = fold.getRange()
    @unregisterFold(bufferRange.start.row, fold)
    startScreenRow = @screenRowForBufferRow(bufferRange.start.row)

    oldScreenRange = new Range()
    oldScreenRange.start.row = startScreenRow
    oldScreenRange.end.row = startScreenRow
    oldScreenRange.end.column = @lineMap.lineForScreenRow(startScreenRow).text.length

    @lineMap.replaceScreenRow(startScreenRow, @buildLinesForBufferRows(bufferRange.start.row, bufferRange.end.row))

    newScreenRange = @expandScreenRangeToLineEnds(@screenRangeForBufferRange(bufferRange))

    @trigger 'change', oldRange: oldScreenRange, newRange: newScreenRange

  registerFold: (bufferRow, fold) ->
    @activeFolds[bufferRow] ?= []
    @activeFolds[bufferRow].push(fold)

  unregisterFold: (bufferRow, fold) ->
    folds = @activeFolds[bufferRow]
    folds.splice(folds.indexOf(fold), 1)

  handleBufferChange: (e) ->
    for row, folds of @activeFolds
      fold.handleBufferChange(e) for fold in folds
    @handleHighlighterChange(@lastHighlighterChangeEvent)

  handleHighlighterChange: (e) ->
    oldScreenRange = @expandScreenRangeToLineEnds(@screenRangeForBufferRange(e.oldRange))
    lines = @buildLinesForBufferRows(e.newRange.start.row, e.newRange.end.row)
    @lineMap.replaceScreenRows(oldScreenRange.start.row, oldScreenRange.end.row, lines)
    newScreenRange = @expandScreenRangeToLineEnds(@screenRangeForBufferRange(e.newRange))

    @trigger 'change', oldRange: oldScreenRange, newRange: newScreenRange

  buildLinesForBufferRows: (start, end) ->
    lines = [@buildLine(@screenRowForBufferRow(start))]
    if end > start
      for row in [start + 1..end]
        lines.push @buildLineForBufferRow(row)
    _.flatten(lines)

  buildLine: (screenRow) ->
    @buildLineForBufferRow(@bufferRowForScreenRow(screenRow))

  buildLineForBufferRow: (bufferRow, startColumn=0) ->
    screenLine = @highlighter.lineForScreenRow(bufferRow).splitAt(startColumn)[1]
    for fold in @foldsForBufferRow(bufferRow)
      { start, end } = fold.getRange()
      if start.column > startColumn
        prefix = screenLine.splitAt(start.column - startColumn)[0]
        suffix = @buildLineForBufferRow(end.row, end.column)
        return _.flatten([prefix, @buildFoldPlaceholder(fold), suffix])
    screenLine

  buildFoldPlaceholder: (fold) ->
    new ScreenLineFragment([{value: '...', type: 'fold-placeholder'}], '...', [0, 3], fold.getRange().toDelta(), isAtomic: true)

  foldsForBufferRow: (bufferRow) ->
    @activeFolds[bufferRow] or []

  linesForScreenRows: (startRow, endRow) ->
    @lineMap.linesForScreenRows(startRow, endRow)

  lineForScreenRow: (screenRow) ->
    @lineMap.lineForScreenRow(screenRow)

  getLines: ->
    @lineMap.getScreenLines()

  lineCount: ->
    @lineMap.screenLineCount()

  lastRow: ->
    @lineCount() - 1

  screenRowForBufferRow: (bufferRow) ->
    @screenPositionForBufferPosition([bufferRow, 0]).row

  bufferRowForScreenRow: (screenRow) ->
    @bufferPositionForScreenPosition([screenRow, 0]).row

  screenPositionForBufferPosition: (bufferPosition) ->
    @lineMap.screenPositionForBufferPosition(bufferPosition)

  bufferPositionForScreenPosition: (screenPosition) ->
    @lineMap.bufferPositionForScreenPosition(screenPosition)

  screenRangeForBufferRange: (bufferRange) ->
    @lineMap.screenRangeForBufferRange(bufferRange)

  expandScreenRangeToLineEnds: (screenRange) ->
    { start, end } = screenRange
    new Range([start.row, 0], [end.row, @lineMap.lineForScreenRow(end.row).text.length])

_.extend LineFolder.prototype, EventEmitter

class Fold
  constructor: (@lineFolder, {@start, @end}) ->

  destroy: ->
    @lineFolder.destroyFold(this)

  getRange: ->
    new Range(@start, @end)

  handleBufferChange: (event) ->
    oldStartRow = @start.row
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

