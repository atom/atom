Highlighter = require 'highlighter'
LineMap = require 'line-map'
Point = require 'point'

module.exports =
class Renderer
  lineMap: null
  highlighter: null

  constructor: (@buffer) ->
    @highlighter = new Highlighter(@buffer)

  buildLineMap: ->
    @lineMap = new LineMap
    @lineMap.insertAtInputRow 0, @buildLinesForBufferRows(0, @buffer.lastRow())

  setMaxLineLength: (@maxLineLength) ->
    @buildLineMap()

  lineForRow: (row) ->
    @lineMap.lineForOutputRow(row)

  logLines: ->
    @lineMap.logLines()

  buildLinesForBufferRows: (startRow, endRow, startColumn=0) ->
    return [] if startRow > endRow

    line = @highlighter.lineForRow(startRow).splitAt(startColumn)[1]
    if wrapColumn = @findWrapColumn(line.text)
      line = line.splitAt(wrapColumn)[0]
      line.outputDelta = new Point(1, 0)
      [line].concat @buildLinesForBufferRows(startRow, endRow, startColumn + wrapColumn)
    else
      [line].concat @buildLinesForBufferRows(startRow + 1, endRow)

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
