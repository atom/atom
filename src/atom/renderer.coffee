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
  idCounter: 1
  lineMap: null
  highlighter: null
  activeFolds: null
  foldsById: null
  lastHighlighterChangeEvent: null
  foldPlaceholderLength: 3

  constructor: (@buffer) ->
    @id = @constructor.idCounter++
    @highlighter = new Highlighter(@buffer)
    @maxLineLength = Infinity
    @activeFolds = {}
    @foldsById = {}
    @buildLineMap()
    @highlighter.on 'change', (e) => @lastHighlighterChangeEvent = e
    @buffer.on "change.renderer#{@id}", (e) => @handleBufferChange(e)

  buildLineMap: ->
    @lineMap = new LineMap
    @lineMap.insertAtBufferRow 0, @buildLinesForBufferRows(0, @buffer.lastRow())

  setMaxLineLength: (@maxLineLength) ->
    oldRange = @rangeForAllLines()
    @buildLineMap()
    newRange = @rangeForAllLines()
    @trigger 'change', { oldRange, newRange }

  lineForRow: (row) ->
    @lineMap.lineForScreenRow(row)

  linesForRows: (startRow, endRow) ->
    @lineMap.linesForScreenRows(startRow, endRow)

  getLines: ->
    @lineMap.linesForScreenRows(0, @lineMap.lastScreenRow())

  bufferRowsForScreenRows: ->
    @lineMap.bufferRowsForScreenRows()

  createFold: (bufferRange) ->
    bufferRange = Range.fromObject(bufferRange)
    return if bufferRange.isEmpty()

    fold = new Fold(this, bufferRange)
    @registerFold(bufferRange.start.row, fold)

    oldScreenRange = @screenLineRangeForBufferRange(bufferRange)
    lines = @buildLineForBufferRow(bufferRange.start.row)
    @lineMap.replaceScreenRows(
      oldScreenRange.start.row,
      oldScreenRange.end.row,
      lines)
    newScreenRange = @expandScreenRangeToLineEnds(
      new Range(oldScreenRange.start.copy(), oldScreenRange.start.copy()))

    @trigger 'change', oldRange: oldScreenRange, newRange: newScreenRange
    @trigger 'fold', bufferRange
    fold

  destroyFold: (fold) ->
    bufferRange = fold.getRange()
    @unregisterFold(bufferRange.start.row, fold)
    startScreenRow = @screenRowForBufferRow(bufferRange.start.row)

    oldScreenRange = @expandScreenRangeToLineEnds(new Range([startScreenRow, 0], [startScreenRow, 0]))
    @lineMap.replaceScreenRow(startScreenRow,
      @buildLinesForBufferRows(bufferRange.start.row, bufferRange.end.row))
    newScreenRange = @screenLineRangeForBufferRange(bufferRange)

    @trigger 'change', oldRange: oldScreenRange, newRange: newScreenRange
    @trigger 'unfold', fold.getRange()

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

  lastRow: ->
    @lineCount() - 1

  logLines: ->
    @lineMap.logLines()

  screenPositionForBufferPosition: (position) ->
    @lineMap.screenPositionForBufferPosition(position)

  bufferPositionForScreenPosition: (position) ->
    @lineMap.bufferPositionForScreenPosition(position)

  clipScreenPosition: (position, options={}) ->
    @lineMap.clipScreenPosition(position, options)

  handleBufferChange: (e) ->
    for row, folds of @activeFolds
      for fold in folds
        changeInsideFold = true if fold.handleBufferChange(e)

    unless changeInsideFold
      @handleHighlighterChange(@lastHighlighterChangeEvent)

  handleHighlighterChange: (e) ->
    oldBufferRange = e.oldRange
    newBufferRange = e.newRange

    oldScreenRange = @screenLineRangeForBufferRange(oldBufferRange)
    newScreenLines = @buildLinesForBufferRows(newBufferRange.start.row, newBufferRange.end.row)
    @lineMap.replaceScreenRows oldScreenRange.start.row, oldScreenRange.end.row, newScreenLines
    newScreenRange = @screenLineRangeForBufferRange(newBufferRange)

    @trigger 'change', { oldRange: oldScreenRange, newRange: newScreenRange, bufferChanged: true }

  buildLineForBufferRow: (bufferRow) ->
    @buildLinesForBufferRows(bufferRow, bufferRow)

  buildLinesForBufferRows: (startRow, endRow) ->
    buildLinesForBufferRows = (startRow, endRow, startColumn, currentScreenLineLength=0) =>
      return [] if startRow > endRow and not startColumn?

      startColumn ?= 0
      line = @highlighter.lineForRow(startRow).splitAt(startColumn)[1]

      wrapColumn = @findWrapColumn(line.text, @maxLineLength - currentScreenLineLength)

      for fold in @foldsForBufferRow(startRow)
        if fold.start.column >= startColumn
          if fold.start.column > wrapColumn - foldPlaceholderLength
            wrapColumn = Math.min(wrapColumn, fold.start.column)
            break
          prefix = line.splitAt(fold.start.column - startColumn)[0]
          placeholder = @buildFoldPlaceholder(fold)
          currentScreenLineLength = currentScreenLineLength + (prefix?.text.length ? 0) + foldPlaceholderLength
          suffix = buildLinesForBufferRows(fold.end.row, endRow, fold.end.column, currentScreenLineLength)
          return _.compact _.flatten [prefix, placeholder, suffix]

      if wrapColumn?
        line = line.splitAt(wrapColumn)[0]
        line.screenDelta = new Point(1, 0)
        [line].concat buildLinesForBufferRows(startRow, endRow, startColumn + wrapColumn)
      else
        [line].concat buildLinesForBufferRows(startRow + 1, endRow)

    buildLinesForBufferRows(@foldStartRowForBufferRow(startRow), endRow)

  foldStartRowForBufferRow: (bufferRow) ->
    @bufferRowForScreenRow(@screenRowForBufferRow(bufferRow))

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

  buildFoldPlaceholder: (fold) ->
    token = { value: '...', type: 'fold-placeholder', fold }
    new ScreenLineFragment([token], '...', [0, 3], fold.getRange().toDelta(), isAtomic: true)

  screenLineRangeForBufferRange: (bufferRange) ->
    @expandScreenRangeToLineEnds(
      @lineMap.screenRangeForBufferRange(
        @expandBufferRangeToLineEnds(bufferRange)))

  expandScreenRangeToLineEnds: (screenRange) ->
    { start, end } = screenRange
    new Range([start.row, 0], [end.row, @lineMap.lineForScreenRow(end.row).text.length])

  expandBufferRangeToLineEnds: (bufferRange) ->
    { start, end } = bufferRange
    new Range([start.row, 0], [end.row, @lineMap.lineForBufferRow(end.row).text.length])

  rangeForAllLines: ->
    new Range([0, 0], @clipScreenPosition([Infinity, Infinity]))

  destroy: ->
    @highlighter.destroy()
    @buffer.off ".renderer#{@id}"

_.extend Renderer.prototype, EventEmitter
