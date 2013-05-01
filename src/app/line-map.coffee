Point = require 'point'
Range = require 'range'
_ = require 'underscore'

# Internal: Responsible for doing the translations between screen positions and buffer positions.
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

    _.spliceWithArray(@screenLines, startRow, rowCount, screenLines)

    for screenLine in maxLengthCandidates
      @maxScreenLineLength = Math.max(@maxScreenLineLength, screenLine.text.length)

  ### Public ###

  # Gets the line for the given screen row.
  #
  # screenRow - A {Number} indicating the screen row.
  #
  # Returns a {ScreenLine}.
  lineForScreenRow: (row) ->
    @screenLines[row]

  # Gets the lines for the given screen row boundaries.
  #
  # start - A {Number} indicating the beginning screen row.
  # end - A {Number} indicating the ending screen row.
  #
  # Returns an {Array} of {ScreenLine}s.
  linesForScreenRows: (startRow, endRow) ->
    @screenLines[startRow..endRow]

  # Given starting and ending screen rows, this returns an array of the
  # buffer rows corresponding to every screen row in the range
  #
  # startRow - The screen row {Number} to start at
  # endRow - The screen row {Integer} to end at (default: {.lastScreenRow})
  #
  # Returns an {Array} of buffer rows as {Integers}s.
  bufferRowsForScreenRows: (startRow, endRow=@lastScreenRow()) ->
    bufferRows = []
    bufferRow = 0
    for screenLine, screenRow in @screenLines
      break if screenRow > endRow
      bufferRows.push(bufferRow) if screenRow >= startRow
      bufferRow += screenLine.bufferRows

    bufferRows

  getScreenLineCount: ->
    @screenLines.length

  # Retrieves the last screen row in the buffer.
  #
  # Returns an {Integer}.
  lastScreenRow: ->
    @getScreenLineCount() - 1

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

  # Given a buffer position, this converts it into a screen position.
  #
  # bufferPosition - An object that represents a buffer position. It can be either
  #                  an {Object} (`{row, column}`), {Array} (`[row, column]`), or {Point}
  # options - The same options available to {.clipScreenPosition}.
  #
  # Returns a {Point}.
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

  # Given a buffer range, this converts it into a screen position.
  #
  # screenPosition - An object that represents a buffer position. It can be either
  #                  an {Object} (`{row, column}`), {Array} (`[row, column]`), or {Point}
  # options - The same options available to {.clipScreenPosition}.
  #
  # Returns a {Point}.
  bufferPositionForScreenPosition: (screenPosition, options) ->
    { row, column } = @clipScreenPosition(Point.fromObject(screenPosition), options)
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

  # Given a buffer range, this converts it into a screen position.
  #
  # bufferRange - The {Range} to convert
  #
  # Returns a {Range}.
  screenRangeForBufferRange: (bufferRange) ->
    bufferRange = Range.fromObject(bufferRange)
    start = @screenPositionForBufferPosition(bufferRange.start)
    end = @screenPositionForBufferPosition(bufferRange.end)
    new Range(start, end)

  # Given a screen range, this converts it into a buffer position.
  #
  # screenRange - The {Range} to convert
  #
  # Returns a {Range}.
  bufferRangeForScreenRange: (screenRange) ->
    screenRange = Range.fromObject(screenRange)
    start = @bufferPositionForScreenPosition(screenRange.start)
    end = @bufferPositionForScreenPosition(screenRange.end)
    new Range(start, end)

  ### Internal ###

  logLines: (start=0, end=@screenLineCount() - 1)->
    for row in [start..end]
      line = @lineForScreenRow(row).text
      console.log row, line, line.length
