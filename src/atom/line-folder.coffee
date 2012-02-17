Point = require 'point'
LineMap = require 'line-map'

module.exports =
class LineFolder
  constructor: (@highlighter) ->
    @activeFolds = {}
    @buildLineMap()

  buildLineMap: ->
    @lineMap = new LineMap
    @lineMap.insertAtBufferRow(0, @highlighter.screenLines)

  fold: (range) ->
    { start, end } = range
    @activeFolds[start.row] ?= []
    @activeFolds[start.row].push(new Fold(this, range))

    screenRow = @screenRowForBufferRow(start.row)
    @lineMap.replaceBufferRows(start.row, end.row, @buildScreenLineForRow(screenRow))

  buildScreenLineForBufferRow: (bufferRow, startColumn) ->
    screenLine = @highlighter.screenLineForRow(bufferRow).splitAt(startColumn)[1]
    for fold in @foldsForBufferRow(bufferRow)
      if fold.start.column > startColumn
        prefix = screenLine.splitAt(fold.start.column - startColumn)[0]
        suffix = @buildScreenLineForBufferRow(fold.end.row, fold.end.column)
        return [prefix, @foldPlaceholder(fold), suffix]
    screenLine

  screenRowForBufferRow: (screenRow) ->
    @lineMap.screenPositionForBufferPosition([screenRow, 0]).row

  lineFragmentsForScreenRows: (startRow, endRow) ->
    @lineMap.lineFragmentsForScreenRows(startRow, endRow)

  screenPositionForBufferPosition: (bufferPosition) ->
    @lineMap.screenPositionForBufferPosition(bufferPosition)

class Fold
  constructor: (@lineFolder, @range) ->
