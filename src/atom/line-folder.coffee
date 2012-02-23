_ = require 'underscore'
Point = require 'point'
Range = require 'range'
LineMap = require 'line-map'
ScreenLineFragment = require 'screen-line-fragment'
EventEmitter = require 'event-emitter'

module.exports =
class LineFolder
  constructor: (@highlighter) ->
    @activeFolds = {}
    @buildLineMap()

  buildLineMap: ->
    @lineMap = new LineMap
    @lineMap.insertAtBufferRow(0, @highlighter.screenLines)

  createFold: (bufferRange) ->
    fold = new Fold(this, bufferRange)
    @activeFolds[bufferRange.start.row] ?= []
    @activeFolds[bufferRange.start.row].push(fold)
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
    bufferRange = fold.range
    folds = @activeFolds[bufferRange.start.row]
    foldIndex = folds.indexOf(fold)
    folds[foldIndex..foldIndex] = []

    startScreenRow = @screenRowForBufferRow(bufferRange.start.row)

    oldScreenRange = new Range()
    oldScreenRange.start.row = startScreenRow
    oldScreenRange.end.row = startScreenRow
    oldScreenRange.end.column = @lineMap.lineForScreenRow(startScreenRow).text.length

    @lineMap.replaceScreenRow(startScreenRow, @buildLinesForBufferRows(bufferRange.start.row, bufferRange.end.row))

    newScreenRange = @expandScreenRangeToLineEnds(@screenRangeForBufferRange(bufferRange))

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
      { start, end } = fold.range
      if start.column > startColumn
        prefix = screenLine.splitAt(start.column - startColumn)[0]
        suffix = @buildLineForBufferRow(end.row, end.column)
        return _.flatten([prefix, @buildFoldPlaceholder(fold), suffix])
    screenLine

  buildFoldPlaceholder: (fold) ->
    new ScreenLineFragment([{value: '...', type: 'fold-placeholder'}], '...', [0, 3], fold.range.toDelta(), isAtomic: true)

  foldsForBufferRow: (bufferRow) ->
    @activeFolds[bufferRow] or []

  linesForScreenRows: (startRow, endRow) ->
    @lineMap.linesForScreenRows(startRow, endRow)

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
  constructor: (@lineFolder, @range) ->

  destroy: ->
    @lineFolder.destroyFold(this)

