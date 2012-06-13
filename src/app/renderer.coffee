_ = require 'underscore'
LanguageMode = require 'language-mode'
FoldSuggester = require 'fold-suggester'
LineMap = require 'line-map'
Point = require 'point'
EventEmitter = require 'event-emitter'
Range = require 'range'
Fold = require 'fold'
ScreenLine = require 'screen-line'
Token = require 'token'
LineCommenter = require 'line-commenter'

module.exports =
class Renderer
  @idCounter: 1
  lineMap: null
  languageMode: null
  activeFolds: null
  lineCommenter: null
  foldsById: null
  lastLanguageModeChangeEvent: null

  constructor: (@buffer, options={}) ->
    @id = @constructor.idCounter++
    @languageMode = new LanguageMode(@buffer, options.tabText ? '  ')
    @lineCommenter = new LineCommenter(@languageMode)
    @foldSuggester = new FoldSuggester(@languageMode)
    @softWrapColumn = options.softWrapColumn ? Infinity
    @activeFolds = {}
    @foldsById = {}
    @buildLineMap()
    @languageMode.on 'change', (e) => @lastLanguageModeChangeEvent = e
    @buffer.on "change.renderer#{@id}", (e) => @handleBufferChange(e)

  buildLineMap: ->
    @lineMap = new LineMap
    @lineMap.insertAtBufferRow 0, @buildLinesForBufferRows(0, @buffer.getLastRow())

  setSoftWrapColumn: (@softWrapColumn) ->
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
    for currentRow in [0..@buffer.getLastRow()]
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

  isFoldContainedByActiveFold: (fold) ->
    for row, folds of @activeFolds
      for otherFold in folds
        return otherFold if fold != otherFold and fold.isContainedByFold(otherFold)

  foldFor: (startRow, endRow) ->
    _.find @activeFolds[startRow] ? [], (fold) ->
      fold.startRow == startRow and fold.endRow == endRow

  createFold: (startRow, endRow) ->
    return fold if fold = @foldFor(startRow, endRow)
    fold = new Fold(this, startRow, endRow)
    @registerFold(fold)

    unless @isFoldContainedByActiveFold(fold)
      bufferRange = new Range([startRow, 0], [endRow, @buffer.lineLengthForRow(endRow)])
      oldScreenRange = @screenLineRangeForBufferRange(bufferRange)

      lines = @buildLineForBufferRow(startRow)
      @lineMap.replaceScreenRows(oldScreenRange.start.row, oldScreenRange.end.row, lines)
      newScreenRange = @screenLineRangeForBufferRange(bufferRange)

      @trigger 'change', oldRange: oldScreenRange, newRange: newScreenRange, lineNumbersChanged: true

    fold

  destroyFold: (fold) ->
    @unregisterFold(fold.startRow, fold)

    unless @isFoldContainedByActiveFold(fold)
      { startRow, endRow } = fold
      bufferRange = new Range([startRow, 0], [endRow, @buffer.lineLengthForRow(endRow)])
      oldScreenRange = @screenLineRangeForBufferRange(bufferRange)
      lines = @buildLinesForBufferRows(startRow, endRow)
      @lineMap.replaceScreenRows(oldScreenRange.start.row, oldScreenRange.end.row, lines)
      newScreenRange = @screenLineRangeForBufferRange(bufferRange)

      @trigger 'change', oldRange: oldScreenRange, newRange: newScreenRange, lineNumbersChanged: true

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

  getLastRow: ->
    @lineCount() - 1

  maxLineLength: ->
    @lineMap.maxScreenLineLength()

  screenPositionForBufferPosition: (position, options) ->
    @lineMap.screenPositionForBufferPosition(position, options)

  bufferPositionForScreenPosition: (position, options) ->
    @lineMap.bufferPositionForScreenPosition(position, options)

  stateForScreenRow: (screenRow) ->
    @languageMode.stateForRow(screenRow)

  clipScreenPosition: (position, options) ->
    @lineMap.clipScreenPosition(position, options)

  handleBufferChange: (e) ->
    allFolds = [] # Folds can modify @activeFolds, so first make sure we have a stable array of folds
    allFolds.push(folds...) for row, folds of @activeFolds
    fold.handleBufferChange(e) for fold in allFolds

    @handleLanguageModeChange(@lastLanguageModeChangeEvent)

  handleLanguageModeChange: (e) ->
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
      screenLine = @languageMode.lineForScreenRow(currentBufferRow)
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
      wrapScreenColumn = @findWrapColumn(screenLine.text, @softWrapColumn)
      if wrapScreenColumn?
        screenLine = screenLine.splitAt(wrapScreenColumn)[0]
        screenLine.screenDelta = new Point(1, 0)
        startBufferColumn += wrapScreenColumn
      else
        currentBufferRow++
        startBufferColumn = 0

      lineFragments.push(screenLine)

    lineFragments

  findWrapColumn: (line, softWrapColumn) ->
    return unless line.length > softWrapColumn

    if /\s/.test(line[softWrapColumn])
      # search forward for the start of a word past the boundary
      for column in [softWrapColumn..line.length]
        return column if /\S/.test(line[column])
      return line.length
    else
      # search backward for the start of the word on the boundary
      for column in [softWrapColumn..0]
        return column + 1 if /\s/.test(line[column])
      return softWrapColumn

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
    @languageMode.destroy()
    @buffer.off ".renderer#{@id}"

  logLines: (start, end) ->
    @lineMap.logLines(start, end)

  toggleLineCommentsInRange: (range) ->
    @lineCommenter.toggleLineCommentsInRange(range)

_.extend Renderer.prototype, EventEmitter
