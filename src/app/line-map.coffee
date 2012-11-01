Point = require 'point'
Range = require 'range'

module.exports =
class LineMap
  constructor: ->
    @screenLines = []

  insertAtScreenRow: (bufferRow, screenLines) ->
    @spliceAtScreenRow(bufferRow, 0, screenLines)

  replaceScreenRows: (start, end, screenLines) ->
    @spliceAtScreenRow(start, end - start + 1, screenLines)

  spliceAtScreenRow: (startRow, rowCount, screenLines) ->
    @screenLines.splice(startRow, rowCount, screenLines...)

  lineForScreenRow: (row) ->
    @linesForScreenRows(row, row)[0]

  linesForScreenRows: (startRow, endRow) ->
    @screenLines[startRow..endRow]

  bufferRowsForScreenRows: (startRow, endRow=@lastScreenRow()) ->
    bufferRows = []
    bufferRow = 0
    for screenLine, screenRow in @screenLines
      break if screenRow > endRow
      bufferRows.push(bufferRow) if screenRow >= startRow
      bufferRow += screenLine.bufferRows

    bufferRows

  screenLineCount: ->
    @screenLines.length

  lastScreenRow: ->
    @screenLineCount() - 1

  maxScreenLineLength: ->
    maxLength = 0
    for screenLine in @screenLines
      maxLength = Math.max(maxLength, screenLine.text.length)
    maxLength

  clipScreenPosition: (screenPosition, options={}) ->
    { wrapBeyondNewlines, wrapAtSoftNewlines } = options
    { row, column } = Point.fromObject(screenPosition)

    if row < 0
      row = 0
      column = 0
    else if row > @lastScreenRow()
      row = @lastScreenRow()
      column = Infinity
    else if column < 0
      column = 0

    screenLine = @lineForScreenRow(row)
    maxScreenColumn = screenLine.getMaxScreenColumn()

    if screenLine.isSoftWrapped() and column >= maxScreenColumn
      if wrapAtSoftNewlines
        row++
        column = 0
      else
        column = screenLine.clipScreenColumn(maxScreenColumn - 1)
    else if wrapBeyondNewlines and column > maxScreenColumn and row < @lastScreenRow()
      row++
      column = 0
    else
      column = screenLine.clipScreenColumn(column, options)
    new Point(row, column)

  screenPositionForBufferPosition: (bufferPosition, options={}) ->
    { wrapBeyondNewlines, wrapAtSoftNewlines } = options
    { row, column } = Point.fromObject(bufferPosition)

    [screenRow, screenLines] = @screenRowAndScreenLinesForBufferRow(row)

    for screenLine in screenLines
      maxBufferColumn = screenLine.getMaxBufferColumn()
      if screenLine.isSoftWrapped()
        if column <= maxBufferColumn
          if column == maxBufferColumn
            if wrapAtSoftNewlines
              screenRow++
              screenColumn = 0
            else
              screenColumn = screenLine.screenColumnForBufferColumn(column - 1, options)
          else
            screenColumn = screenLine.screenColumnForBufferColumn(column, options)
          break
        else
          screenRow++
      else
        if wrapBeyondNewlines and column > maxBufferColumn and screenRow < @lastScreenRow()
          screenRow++
          screenColumn = 0
        else
          screenColumn = screenLine.screenColumnForBufferColumn(column)
        break

    new Point(screenRow, screenColumn)

  screenRowAndScreenLinesForBufferRow: (bufferRow) ->
    screenLines = []
    screenRow = 0
    currentBufferRow = 0
    for screenLine in @screenLines
      nextBufferRow = currentBufferRow + screenLine.bufferRows
      if currentBufferRow > bufferRow
        break
      else if currentBufferRow == bufferRow or currentBufferRow <= bufferRow < nextBufferRow
        screenLines.push(screenLine)
      else
        screenRow++
      currentBufferRow = nextBufferRow

    [screenRow, screenLines]

  bufferPositionForScreenPosition: (screenPosition, options) ->
    { row, column } = Point.fromObject(screenPosition)
    [bufferRow, screenLine] = @bufferRowAndScreenLineForScreenRow(row)
    bufferColumn = screenLine.bufferColumnForScreenColumn(column)
    new Point(bufferRow, bufferColumn)

  bufferRowAndScreenLineForScreenRow: (screenRow) ->
    bufferRow = 0
    for screenLine, currentScreenRow in @screenLines
      if currentScreenRow == screenRow
        break
      else
        bufferRow += screenLine.bufferRows

    [bufferRow, screenLine]

  screenRangeForBufferRange: (bufferRange) ->
    bufferRange = Range.fromObject(bufferRange)
    start = @screenPositionForBufferPosition(bufferRange.start)
    end = @screenPositionForBufferPosition(bufferRange.end)
    new Range(start, end)

  bufferRangeForScreenRange: (screenRange) ->
    start = @bufferPositionForScreenPosition(screenRange.start)
    end = @bufferPositionForScreenPosition(screenRange.end)
    new Range(start, end)

  logLines: (start=0, end=@screenLineCount() - 1)->
    for row in [start..end]
      line = @lineForScreenRow(row).text
      console.log row, line, line.length

