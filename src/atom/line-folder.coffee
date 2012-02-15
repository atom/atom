LineIndex = require 'line-index'

module.exports =
class LineFolder
  constructor: (@highlighter) ->
    @activeFolds = {}
    @lineIndex = new LineIndex
    @lineIndex.insertLines(0, 1, @highlighter.allScreenLines())

  createFold: (range) ->
    new Fold(this, range)
    @activeFolds[range.start.row] = { range }

  screenLineForRow: (screenRow) ->
    

  collapseRows: (startRow, endRow) ->
    @lineIndex.updateSpansForRows(startRow, endRow, 0)

class Fold
  constructor: (@lineFolder, @range) ->
    @lineFolder.collapseRows(@range.start.row, @range.end.row)
