_ = require 'underscore'
Highlighter = require 'highlighter'
FoldSuggester = require 'fold-suggester'
LineMap = require 'line-map'
Point = require 'point'
EventEmitter = require 'event-emitter'
Range = require 'range'
Fold = require 'fold'
ScreenLineFragment = require 'screen-line-fragment'
Token = require 'token'
foldPlaceholderLength = 3

module.exports =
class Renderer
  @idCounter: 1
  lineMap: null
  highlighter: null
  activeFolds: null
  foldsById: null
  lastHighlighterChangeEvent: null
  foldPlaceholderLength: 3

  constructor: (@buffer, options={}) ->
    @id = @constructor.idCounter++
    @highlighter = new Highlighter(@buffer, options.tabText ? '  ')
    @foldSuggester = new FoldSuggester(@highlighter)
    @maxLineLength = options.maxLineLength ? Infinity
    @activeFolds = {}
    @foldsById = {}
    @buildLineMap()
    @highlighter.on 'change', (e) => @lastHighlighterChangeEvent = e
    @buffer.on "change.renderer#{@id}", (e) => @handleBufferChange(e)

  buildLineMap: ->
    @lineMap = new LineMap
    @lineMap.insertAtBufferRow 0, @buildLinesForBufferRows(0, @buffer.getLastRow())

  setMaxLineLength: (@maxLineLength) ->
    oldRange = @rangeForAllLines()
    @buildLineMap()
    newRange = @rangeForAllLines()
    @trigger 'change', { oldRange, newRange, lineNumbersChanged: true }

  lineForRow: (row) ->
    @lineMap.lineForScreenRow(row)

  linesForRows: (startRow, endRow) ->
    @lineMap.linesForScreenRows(startRow, endRow)

  getLines: ->
    @lineMap.linesForScreenRows(0, @lineMap.lastScreenRow())

  bufferRowsForScreenRows: (startRow, endRow) ->
    @lineMap.bufferRowsForScreenRows(startRow, endRow)

  foldAll: ->
    for currentRow in [@buffer.getLastRow()..0]
      [startRow, endRow] = @foldSuggester.rowRangeForFoldAtBufferRow(currentRow) ? []
      continue unless startRow?

      @createFold(startRow, endRow)

  toggleFoldAtBufferRow: (bufferRow) ->
    for currentRow in [bufferRow..0]
      [startRow, endRow] = @foldSuggester.rowRangeForFoldAtBufferRow(currentRow) ? []
      continue unless startRow? and startRow <= bufferRow <= endRow

      if fold = @largestFoldForBufferRow(startRow)
        fold.destroy()
      else
        @createFold(startRow, endRow)

      break

  foldFor: (startRow, endRow) ->
    _.find @activeFolds[startRow] ? [], (fold) ->
      fold.startRow == startRow and fold.endRow == endRow

  createFold: (startRow, endRow) ->
    return fold if fold = @foldFor(startRow, endRow)
    fold = new Fold(this, startRow, endRow)
    @registerFold(fold)

    bufferRange = new Range([startRow, 0], [endRow, @buffer.lineLengthForRow(endRow)])
    oldScreenRange = @screenLineRangeForBufferRange(bufferRange)

    lines = @buildLineForBufferRow(startRow)
    @lineMap.replaceScreenRows(oldScreenRange.start.row, oldScreenRange.end.row, lines)
    newScreenRange = @screenLineRangeForBufferRange(bufferRange)

    @trigger 'change', oldRange: oldScreenRange, newRange: newScreenRange, lineNumbersChanged: true
    @trigger 'fold', bufferRange
    fold

  destroyFold: (fold) ->
    @unregisterFold(fold.startRow, fold)

    { startRow, endRow } = fold
    bufferRange = new Range([startRow, 0], [endRow, @buffer.lineLengthForRow(endRow)])
    oldScreenRange = @screenLineRangeForBufferRange(bufferRange)
    lines = @buildLinesForBufferRows(startRow, endRow)
    @lineMap.replaceScreenRows(oldScreenRange.start.row, oldScreenRange.end.row, lines)
    newScreenRange = @screenLineRangeForBufferRange(bufferRange)

    @trigger 'change', oldRange: oldScreenRange, newRange: newScreenRange, lineNumbersChanged: true
    @trigger 'unfold', bufferRange

  destroyFoldsContainingBufferRow: (bufferRow) ->
    folds = @activeFolds[bufferRow] ? []
    fold.destroy() for fold in new Array(folds...)

  registerFold: (fold) ->
    @activeFolds[fold.startRow] ?= []
    @activeFolds[fold.startRow].push(fold)
    @foldsById[fold.id] = fold

  unregisterFold: (bufferRow, fold) ->
    folds = @activeFolds[bufferRow]
    _.remove(folds, fold)
    delete @foldsById[fold.id]

  largestFoldForBufferRow: (bufferRow) ->
    return unless folds = @activeFolds[bufferRow]
    (folds.sort (a, b) -> b.endRow - a.endRow)[0]

  screenLineRangeForBufferRange: (bufferRange) ->
    @expandScreenRangeToLineEnds(
      @lineMap.screenRangeForBufferRange(
        @expandBufferRangeToLineEnds(bufferRange)))

  screenRowForBufferRow: (bufferRow) ->
    @lineMap.screenPositionForBufferPosition([bufferRow, 0]).row

  bufferRowForScreenRow: (screenRow) ->
    @lineMap.bufferPositionForScreenPosition([screenRow, 0]).row

  screenRangeForBufferRange: (bufferRange) ->
    @lineMap.screenRangeForBufferRange(bufferRange)

  bufferRangeForScreenRange: (screenRange) ->
    @lineMap.bufferRangeForScreenRange(screenRange)

  lineCount: ->
    @lineMap.screenLineCount()

  screenPositionForBufferPosition: (position, options) ->
    @lineMap.screenPositionForBufferPosition(position, options)

  bufferPositionForScreenPosition: (position, options) ->
    @lineMap.bufferPositionForScreenPosition(position, options)

  clipScreenPosition: (position, options={}) ->
    @lineMap.clipScreenPosition(position, options)

  handleBufferChange: (e) ->
    allFolds = [] # Folds can modify @activeFolds, so first make sure we have a stable array of folds
    allFolds.push(folds...) for row, folds of @activeFolds
    fold.handleBufferChange(e) for fold in allFolds

    @handleHighlighterChange(@lastHighlighterChangeEvent)

  handleHighlighterChange: (e) ->
    newRange = e.newRange.copy()
    newRange.start.row = @bufferRowForScreenRow(@screenRowForBufferRow(newRange.start.row))

    oldScreenRange = @screenLineRangeForBufferRange(e.oldRange)

    newScreenLines = @buildLinesForBufferRows(newRange.start.row, newRange.end.row)
    @lineMap.replaceScreenRows oldScreenRange.start.row, oldScreenRange.end.row, newScreenLines
    newScreenRange = @screenLineRangeForBufferRange(newRange)

    @trigger 'change',
      oldRange: oldScreenRange
      newRange: newScreenRange
      bufferChanged: true
      lineNumbersChanged: !e.oldRange.coversSameRows(newRange) or !oldScreenRange.coversSameRows(newScreenRange)

  buildLineForBufferRow: (bufferRow) ->
    @buildLinesForBufferRows(bufferRow, bufferRow)

  buildLinesForBufferRows: (startBufferRow, endBufferRow) ->
    lineFragments = []
    startBufferColumn = null
    currentBufferRow = startBufferRow
    currentScreenLineLength = 0

    startBufferColumn = 0
    while currentBufferRow <= endBufferRow
      screenLine = @highlighter.screenLineForRow(currentBufferRow)
      screenLine.foldable = @foldSuggester.isBufferRowFoldable(currentBufferRow)

      if fold = @largestFoldForBufferRow(currentBufferRow)
        screenLine = screenLine.copy()
        screenLine.fold = fold
        screenLine.bufferDelta = fold.getBufferDelta()
        lineFragments.push(screenLine)
        currentBufferRow = fold.endRow + 1
        continue

      startBufferColumn ?= 0
      screenLine = screenLine.splitAt(startBufferColumn)[1] if startBufferColumn > 0
      wrapScreenColumn = @findWrapColumn(screenLine.text, @maxLineLength)
      if wrapScreenColumn?
        screenLine = screenLine.splitAt(wrapScreenColumn)[0]
        screenLine.screenDelta = new Point(1, 0)
        startBufferColumn += wrapScreenColumn
      else
        currentBufferRow++
        startBufferColumn = 0

      lineFragments.push(screenLine)

    lineFragments

  findWrapColumn: (line, maxLineLength) ->
    return unless line.length > maxLineLength

    if /\s/.test(line[maxLineLength])
      # search forward for the start of a word past the boundary
      for column in [maxLineLength..line.length]
        return column if /\S/.test(line[column])
      return line.length
    else
      # search backward for the start of the word on the boundary
      for column in [maxLineLength..0]
        return column + 1 if /\s/.test(line[column])
      return maxLineLength

  expandScreenRangeToLineEnds: (screenRange) ->
    screenRange = Range.fromObject(screenRange)
    { start, end } = screenRange
    new Range([start.row, 0], [end.row, @lineMap.lineForScreenRow(end.row).text.length])

  expandBufferRangeToLineEnds: (bufferRange) ->
    bufferRange = Range.fromObject(bufferRange)
    { start, end } = bufferRange
    new Range([start.row, 0], [end.row, Infinity])

  rangeForAllLines: ->
    new Range([0, 0], @clipScreenPosition([Infinity, Infinity]))

  destroy: ->
    @highlighter.destroy()
    @buffer.off ".renderer#{@id}"

  logLines: (start, end) ->
    @lineMap.logLines(start, end)

_.extend Renderer.prototype, EventEmitter
