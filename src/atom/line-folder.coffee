SpanIndex = require 'span-index'

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
    @index.replace(startRow, 1, @buildScreenLineForBufferRow(startRow))
    @index.updateSpans(startRow + 1, endRow, 0)

  buildScreenLineForBufferRow: (bufferRow) ->
    if fold = @activeFolds[bufferRow]
      { start, end } = fold.range
      endRow = fold.range.end.row
      prefix = @highlighter.screenLineForRow(start.row).splitAt(start.column)[0]
      suffix = @highlighter.screenLineForRow(end.row).splitAt(end.column)[1]
      prefix.pushToken(type: 'placeholder', value: '...')
      prefix.concat(suffix)

class Fold
  constructor: (@lineFolder, @range) ->
    @lineFolder.activeFolds[@range.start.row] = this
    @lineFolder.foldRows(@range.start.row, @range.end.row)
