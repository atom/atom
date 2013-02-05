Point = require 'point'
Range = require 'range'

module.exports =
class LineMap
  maxScreenLineLength: 0

  constructor: ->
    @screenLines = []

  insertAtScreenRow: (bufferRow, screenLines) ->
    @spliceAtScreenRow(bufferRow, 0, screenLines)

  replaceScreenRows: (start, end, screenLines) ->
    @spliceAtScreenRow(start, end - start + 1, screenLines)

  spliceAtScreenRow: (startRow, rowCount, screenLines) ->
    maxLengthCandidates =  screenLines
    for screenLine in @screenLines[startRow...startRow+rowCount]
      if screenLine.text.length == @maxScreenLineLength
        @maxScreenLineLength = 0
        maxLengthCandidates = @screenLines

    @screenLines.splice(startRow, rowCount, screenLines...)

    for screenLine in maxLengthCandidates
      @maxScreenLineLength = Math.max(@maxScreenLineLength, screenLine.text.length)

  lineForScreenRow: (row) ->
    @screenLines[row]

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

    screenLine = options.screenLine ? @lineForScreenRow(row)
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
    { row, column } = Point.fromObject(bufferPosition)
    [screenRow, screenLines] = @screenRowAndScreenLinesForBufferRow(row)
    for screenLine in screenLines
      maxBufferColumn = screenLine.getMaxBufferColumn()
      if screenLine.isSoftWrapped() and column > maxBufferColumn
        screenRow++
      else
        if column <= maxBufferColumn
          screenColumn = screenLine.screenColumnForBufferColumn(column)
        else
          screenColumn = Infinity
        break

    options.screenLine = screenLine
    @clipScreenPosition([screenRow, screenColumn], options)

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
    screenRange = Range.fromObject(screenRange)
    start = @bufferPositionForScreenPosition(screenRange.start)
    end = @bufferPositionForScreenPosition(screenRange.end)
    new Range(start, end)

  logLines: (start=0, end=@screenLineCount() - 1)->
    for row in [start..end]
      line = @lineForScreenRow(row).text
      console.log row, line, line.length
