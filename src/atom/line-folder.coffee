Point = require 'point'
LineMap = require 'line-map'
ScreenLineFragment = require 'screen-line-fragment'
_ = require 'underscore'

module.exports =
class LineFolder
  constructor: (@highlighter) ->
    @activeFolds = {}
    @buildLineMap()

  buildLineMap: ->
    @lineMap = new LineMap
    @lineMap.insertAtBufferRow(0, @highlighter.lineFragments())

  fold: (bufferRange) ->
    @activeFolds[bufferRange.start.row] ?= []
    @activeFolds[bufferRange.start.row].push(new Fold(this, bufferRange))
    screenRange = @screenRangeForBufferRange(bufferRange)
    @lineMap.replaceScreenRows(screenRange.start.row, screenRange.end.row, @renderScreenLine(screenRange.start.row))

  renderScreenLine: (screenRow) ->
    @renderScreenLineForBufferRow(@bufferRowForScreenRow(screenRow))

  renderScreenLineForBufferRow: (bufferRow, startColumn=0) ->
    screenLine = @highlighter.lineFragmentForRow(bufferRow).splitAt(startColumn)[1]
    for fold in @foldsForBufferRow(bufferRow)
      { start, end } = fold.range
      if start.column > startColumn
        prefix = screenLine.splitAt(start.column - startColumn)[0]
        suffix = @buildScreenLineForBufferRow(end.row, end.column)
        return _.flatten([prefix, @buildFoldPlaceholder(fold), suffix])
    screenLine

  buildScreenLineForBufferRow: (bufferRow, startColumn=0) ->
    screenLine = @highlighter.lineFragmentForRow(bufferRow).splitAt(startColumn)[1]
    for fold in @foldsForBufferRow(bufferRow)
      { start, end } = fold.range
      if start.column > startColumn
        prefix = screenLine.splitAt(start.column - startColumn)[0]
        suffix = @buildScreenLineForBufferRow(end.row, end.column)
        screenLine = _.flatten([prefix, @buildFoldPlaceholder(fold), suffix])
        return screenLine
    screenLine

  buildFoldPlaceholder: (fold) ->
    new ScreenLineFragment([{value: '...', type: 'fold-placeholder'}], '...', [0, 3], fold.range.toDelta())

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

class Fold
  constructor: (@lineFolder, @range) ->
