SpanIndex = require 'span-index'
Point = require 'point'

module.exports =
class LineFolder
  constructor: (@highlighter) ->
    @activeFolds = {}
    @buildIndex()

  buildIndex: ->
    @index = new SpanIndex
    @index.insert 0, 1, @highlighter.screenLines

  createFold: (range) ->
    new Fold(this, range)

  screenLinesForRows: (startRow, endRow) ->
    @index.sliceBySpan(startRow, endRow).values

  foldRows: (startRow, endRow) ->
    @refreshScreenRow(@screenRowForBufferRow(startRow))
    if endRow > startRow
      @index.updateSpans(startRow + 1, endRow, 0)

  refreshScreenRow: (screenRow) ->
    bufferRow = @bufferRowForScreenRow(screenRow)
    @index.replace(bufferRow, 1, @buildScreenLineForBufferRow(bufferRow))

  buildScreenLineForBufferRow: (bufferRow, startColumn=0) ->
    screenLine = @highlighter.screenLineForRow(bufferRow)
    screenLine = screenLine.splitAt(startColumn)[1] if startColumn

    fold = @activeFolds[bufferRow]
    if fold and fold.range.start.column >= startColumn
      { start, end } = fold.range
      prefix = screenLine.splitAt(start.column - startColumn)[0]
      suffix = @buildScreenLineForBufferRow(end.row, end.column)
      prefix.pushToken(type: 'placeholder', value: '...')
      return prefix.concat(suffix)
    screenLine

  screenRowForBufferRow: (bufferRow) ->
    @index.spanForIndex(bufferRow) - 1

  bufferRowForScreenRow: (screenRow) ->
    @index.indexForSpan(screenRow).index

  screenPositionForBufferPosition: (bufferPosition) ->
    bufferPosition = Point.fromObject(bufferPosition)
    screenRow = 0
    screenColumn = 0
    bufferRow = 0

    while bufferRow < bufferPosition.row
      console.log "HI", bufferRow, screenColumn
      if fold = @maximalFoldStartingAtBufferRow(bufferRow)
        bufferRow = fold.range.end.row
        screenColumn += fold.range.start.column + 3 + bufferPosition.column - fold.range.end.column
      else
        bufferRow++
        screenRow++
        if bufferRow == bufferPosition.row
          screenColumn = bufferPosition.column
        else
          screenColumn = 0

    new Point(screenRow, screenColumn)

  maximalFoldStartingAtBufferRow: (bufferRow) ->
    @activeFolds[bufferRow]


class Fold
  constructor: (@lineFolder, @range) ->
    @lineFolder.activeFolds[@range.start.row] = this
    @lineFolder.foldRows(@range.start.row, @range.end.row)
