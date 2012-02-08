Point = require 'point'
getWordRegex = -> /\b[^\s]+/g

module.exports =
class LineWrapper
  constructor: (@maxLength, @highlighter) ->
    @buffer = @highlighter.buffer
    @segmentBuffer()

  setMaxLength: (@maxLength) ->
    @segmentBuffer()

  segmentBuffer: ->
    @lines = @segmentRows(0, @buffer.lastRow())

  segmentsForRow: (row) ->
    @lines[row]

  segmentRows: (start, end) ->
    for row in [start..end]
      @segmentRow(row)

  segmentRow: (row) ->
    wordRegex = getWordRegex()
    line = @buffer.getLine(row)

    breakIndices = []
    lastBreakIndex = 0

    while match = wordRegex.exec(line)
      startIndex = match.index
      endIndex = startIndex + match[0].length
      if endIndex - lastBreakIndex > @maxLength
        breakIndices.push(startIndex)
        lastBreakIndex = startIndex

    currentSegment = []
    currentSegment.startColumn = 0
    currentSegment.endColumn = 0
    currentSegment.textLength = 0
    segments = [currentSegment]
    nextBreak = breakIndices.shift()
    for token in @highlighter.tokensForRow(row)
      if currentSegment.endColumn >= nextBreak
        nextBreak = breakIndices.shift()
        newSegment = []
        newSegment.startColumn = currentSegment.endColumn
        newSegment.endColumn = currentSegment.endColumn
        newSegment.textLength = 0
        segments.push(newSegment)
        currentSegment = newSegment
      currentSegment.push token
      currentSegment.endColumn += token.value.length
      currentSegment.textLength += token.value.length

    segments

  screenPositionFromBufferPosition: (bufferPosition) ->
    bufferPosition = Point.fromObject(bufferPosition)
    row = 0
    for segments in @lines[0...bufferPosition.row]
      row += segments.length

    column = bufferPosition.column
    for segment in @lines[bufferPosition.row]
      break if segment.endColumn > bufferPosition.column
      column -= segment.textLength
      row++

    new Point(row, column)

  bufferPositionFromScreenPosition: (screenPosition) ->
    screenPosition = Point.fromObject(screenPosition)
    bufferRow = 0
    currentScreenRow = 0
    for screenLines in @lines
      for screenLine in screenLines
        if currentScreenRow == screenPosition.row
          return new Point(bufferRow, screenLine.startColumn + screenPosition.column)
        currentScreenRow++
      bufferRow++

  tokensForScreenRow: (screenRow) ->
    currentScreenRow = 0
    for screenLines in @lines
      for screenLine in screenLines
        return screenLine if currentScreenRow == screenRow
        currentScreenRow++
