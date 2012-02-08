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
    currentSegment.lastIndex = 0
    currentSegment.textLength = 0
    segments = [currentSegment]
    nextBreak = breakIndices.shift()
    for token in @highlighter.tokensForRow(row)
      if currentSegment.lastIndex >= nextBreak
        nextBreak = breakIndices.shift()
        newSegment = []
        newSegment.startColumn = currentSegment.lastIndex
        newSegment.lastIndex = currentSegment.lastIndex
        newSegment.textLength = 0
        segments.push(newSegment)
        currentSegment = newSegment
      currentSegment.push token
      currentSegment.lastIndex += token.value.length
      currentSegment.textLength += token.value.length

    segments

  displayPositionFromBufferPosition: (bufferPosition) ->
    row = 0
    for segments in @lines[0...bufferPosition.row]
      row += segments.length

    column = bufferPosition.column
    for segment in @lines[bufferPosition.row]
      break if segment.lastIndex > bufferPosition.column
      column -= segment.textLength
      row++

    { row, column }


  bufferPositionFromDisplayPosition: (displayPosition) ->
    bufferRow = 0
    currentScreenRow = 0
    for screenLines in @lines
      for screenLine in screenLines
        if currentScreenRow == displayPosition.row
          return { row: bufferRow, column: screenLine.startColumn + displayPosition.column }
        currentScreenRow++
      bufferRow++
