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
    currentSegment.lastIndex = 0
    segments = [currentSegment]
    nextBreak = breakIndices.shift()
    for token in @highlighter.tokensForRow(row)
      if currentSegment.lastIndex >= nextBreak
        nextBreak = breakIndices.shift()
        newSegment = []
        newSegment.lastIndex = currentSegment.lastIndex
        newSegment.textLength = 0
        segments.push(newSegment)
        currentSegment = newSegment
      currentSegment.push token
      currentSegment.lastIndex += token.value.length
      currentSegment.textLength += token.value.length

    segments
