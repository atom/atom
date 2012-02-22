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

  fold: (bufferRange) ->
    fold = new Fold(this, bufferRange)
    @activeFolds[bufferRange.start.row] ?= []
    @activeFolds[bufferRange.start.row].push(fold)
    oldScreenRange = @expandScreenRangeToLineEnds(@screenRangeForBufferRange(bufferRange))

    lineWithFold = @renderScreenLine(oldScreenRange.start.row)
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

    @lineMap.replaceScreenRow(startScreenRow, @renderScreenLinesForBufferRows(bufferRange.start.row, bufferRange.end.row))

    newScreenRange = @expandScreenRangeToLineEnds(@screenRangeForBufferRange(bufferRange))

    @trigger 'change', oldRange: oldScreenRange, newRange: newScreenRange

  renderScreenLinesForBufferRows: (start, end) ->
    lines = [@renderScreenLine(@screenRowForBufferRow(start))]
    if end > start
      for row in [start + 1..end]
        lines.push @renderScreenLineForBufferRow(row)
    _.flatten(lines)

  renderScreenLine: (screenRow) ->
    @renderScreenLineForBufferRow(@bufferRowForScreenRow(screenRow))

  renderScreenLineForBufferRow: (bufferRow, startColumn=0) ->
    screenLine = @highlighter.screenLineForRow(bufferRow).splitAt(startColumn)[1]
    for fold in @foldsForBufferRow(bufferRow)
      { start, end } = fold.range
      if start.column > startColumn
        prefix = screenLine.splitAt(start.column - startColumn)[0]
        suffix = @renderScreenLineForBufferRow(end.row, end.column)
        return _.flatten([prefix, @buildFoldPlaceholder(fold), suffix])
    screenLine

  buildFoldPlaceholder: (fold) ->
    new ScreenLineFragment([{value: '...', type: 'fold-placeholder'}], '...', [0, 3], fold.range.toDelta(), isAtomic: true)

  foldsForBufferRow: (bufferRow) ->
    @activeFolds[bufferRow] or []

  linesForScreenRows: (startRow, endRow) ->
    @lineMap.linesForScreenRows(startRow, endRow)

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

