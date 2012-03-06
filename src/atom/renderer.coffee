_ = require 'underscore'
Highlighter = require 'highlighter'
LineMap = require 'line-map'
Point = require 'point'
EventEmitter = require 'event-emitter'
Range = require 'range'
Fold = require 'fold'
ScreenLineFragment = require 'screen-line-fragment'
foldPlaceholderLength = 3

module.exports =
class Renderer
  lineMap: null
  highlighter: null
  activeFolds: null
  foldsById: null
  foldPlaceholderLength: 3

  constructor: (@buffer) ->
    @highlighter = new Highlighter(@buffer)
    @maxLineLength = Infinity
    @activeFolds = {}
    @foldsById = {}
    @buildLineMap()

  buildLineMap: ->
    @lineMap = new LineMap
    @lineMap.insertAtInputRow 0, @buildLinesForBufferRows(0, @buffer.lastRow())

  setMaxLineLength: (@maxLineLength) ->
    @buildLineMap()

  lineForRow: (row) ->
    @lineMap.lineForOutputRow(row)

  createFold: (bufferRange) ->
    bufferRange = Range.fromObject(bufferRange)
    return if bufferRange.isEmpty()

    fold = new Fold(this, bufferRange)
    @registerFold(bufferRange.start.row, fold)

    oldScreenRange = @expandScreenRangeToLineEnds(@screenRangeForBufferRange(bufferRange))
    @lineMap.replaceOutputRows(
      oldScreenRange.start.row,
      oldScreenRange.end.row,
      @buildLineForBufferRow(bufferRange.start.row))
    newScreenRange = @expandScreenRangeToLineEnds(
      new Range(_.clone(oldScreenRange.start), _.clone(oldScreenRange.start)))

    @trigger 'change', oldRange: oldScreenRange, newRange: newScreenRange
    @trigger 'fold', bufferRange
    fold

  destroyFold: (fold) ->
    bufferRange = fold.getRange()
    @unregisterFold(bufferRange.start.row, fold)
    startScreenRow = @screenRowForBufferRow(bufferRange.start.row)

    oldScreenRange = @expandScreenRangeToLineEnds(new Range([startScreenRow, 0], [startScreenRow, 0]))
    @lineMap.replaceOutputRow(startScreenRow,
      @buildLinesForBufferRows(bufferRange.start.row, bufferRange.end.row))
    newScreenRange = @expandScreenRangeToLineEnds(@screenRangeForBufferRange(bufferRange))

    @trigger 'change', oldRange: oldScreenRange, newRange: newScreenRange
    @trigger 'unfold', fold.getRange()

  screenRowForBufferRow: (bufferRow) ->
    @lineMap.outputPositionForInputPosition([bufferRow, 0]).row

  screenRangeForBufferRange: (bufferRange) ->
    @lineMap.outputRangeForInputRange(bufferRange)

  logLines: ->
    @lineMap.logLines()

  buildLineForBufferRow: (bufferRow) ->
    @buildLinesForBufferRows(bufferRow, bufferRow)

  buildLinesForBufferRows: (startRow, endRow, startColumn) ->
    return [] if startRow > endRow and not startColumn?

    startColumn ?= 0
    line = @highlighter.lineForRow(startRow).splitAt(startColumn)[1]

    wrapColumn = @findWrapColumn(line.text)

    for fold in @foldsForBufferRow(startRow)
      if fold.start.column >= startColumn
        break if fold.start.column > wrapColumn - foldPlaceholderLength
        prefix = line.splitAt(fold.start.column - startColumn)[0]
        placeholder = @buildFoldPlaceholder(fold)
        suffix = @buildLinesForBufferRows(fold.end.row, endRow, fold.end.column)
        return _.compact _.flatten [prefix, placeholder, suffix]

    if wrapColumn
      line = line.splitAt(wrapColumn)[0]
      line.outputDelta = new Point(1, 0)
      [line].concat @buildLinesForBufferRows(startRow, endRow, startColumn + wrapColumn)
    else
      [line].concat @buildLinesForBufferRows(startRow + 1, endRow)

  buildFoldPlaceholder: (fold) ->
    token = {value: '...', type: 'fold-placeholder', fold, isAtomic: true}
    new ScreenLineFragment([token], '...', [0, 3], fold.getRange().toDelta(), isAtomic: true)

  findWrapColumn: (line) ->
    return unless line.length > @maxLineLength

    if /\s/.test(line[@maxLineLength])
      # search forward for the start of a word past the boundary
      for column in [@maxLineLength..line.length]
        return column if /\S/.test(line[column])
      return line.length
    else
      # search backward for the start of the word on the boundary
      for column in [@maxLineLength..0]
        return column + 1 if /\s/.test(line[column])
      return @maxLineLength

  registerFold: (bufferRow, fold) ->
    @activeFolds[bufferRow] ?= []
    @activeFolds[bufferRow].push(fold)
    @foldsById[fold.id] = fold

  unregisterFold: (bufferRow, fold) ->
    folds = @activeFolds[bufferRow]
    folds.splice(folds.indexOf(fold), 1)
    delete @foldsById[fold.id]

  foldsForBufferRow: (bufferRow) ->
    folds = @activeFolds[bufferRow] or []
    folds.sort (a, b) -> a.compare(b)

  expandScreenRangeToLineEnds: (screenRange) ->
    { start, end } = screenRange
    new Range([start.row, 0], [end.row, @lineMap.lineForOutputRow(end.row).text.length])

_.extend Renderer.prototype, EventEmitter
