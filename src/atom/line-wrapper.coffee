_ = require 'underscore'
EventEmitter = require 'event-emitter'
Point = require 'point'
Range = require 'range'

module.exports =
class LineWrapper
  constructor: (@maxLength, @highlighter) ->
    @buffer = @highlighter.buffer
    @buildWrappedLines()
    @highlighter.on 'change', (e) =>
      oldCount = @wrappedLines[e.oldRange.start.row].screenLines.length
      @wrappedLines[e.oldRange.start.row] = @buildWrappedLineForBufferRow(e.newRange.start.row)
      newCount = @wrappedLines[e.oldRange.start.row].screenLines.length

      oldRange = @screenRangeFromBufferRange(e.oldRange)
      newRange = @screenRangeFromBufferRange(e.newRange)

      if newCount > oldCount
        newRange.end.row += newCount - oldCount
        newRange.end.column = @tokensForScreenRow(newRange.end.row).textLength

      @trigger 'change', { oldRange, newRange }

  setMaxLength: (@maxLength) ->
    @buildWrappedLines()

  buildWrappedLines: ->
    @wrappedLines = @buildWrappedLinesForBufferRows(0, @buffer.lastRow())

  buildWrappedLinesForBufferRows: (start, end) ->
    for row in [start..end]
      @buildWrappedLineForBufferRow(row)

  buildWrappedLineForBufferRow: (bufferRow) ->
    { screenLines: @splitTokens(@highlighter.tokensForRow(bufferRow)) }

  splitTokens: (tokens, startColumn = 0) ->
    return [] unless tokens.length

    textLength = 0
    screenLine = []
    while tokens.length
      nextToken = tokens[0]
      if textLength + nextToken.value.length > @maxLength
        tokenFragments = @splitBoundaryToken(nextToken, @maxLength - textLength)
        [token1, token2] = tokenFragments
        tokens[0..0] = _.compact(tokenFragments)
        break unless token1
      nextToken = tokens.shift()
      textLength += nextToken.value.length
      screenLine.push nextToken

    _.extend(screenLine, { startColumn, textLength, endColumn: startColumn + textLength })
    [screenLine].concat @splitTokens(tokens, screenLine.endColumn)

  splitBoundaryToken: (token, boundaryIndex) ->
    { value } = token

    # if no whitespace, split it all to next line if it will fit.
    # if it's longer than the max width, chop it without regard for whitespace.
    hasNoWhitespace = not /\s/.test(value)
    if hasNoWhitespace
      if value.length > @maxLength
        return @splitTokenAt(token, boundaryIndex)
      else
        return [null, token]

    # if only whitespace, keep it all on current line.
    return [token, null] unless /\w/.test(value)

    # if words + whitespace, try to split on start of word closest to the boundary
    wordStart = /\b\w/g

    while match = wordStart.exec(value)
      break if match.index > boundaryIndex
      splitIndex = match.index

    # if the only word start is at the beginning of the token, put the whole token on the next line
    return [null, token] if splitIndex == 0

    @splitTokenAt(token, splitIndex)

  splitTokenAt: (token, splitIndex) ->
    { type, value } = token
    value1 = value.substring(0, splitIndex)
    value2 = value.substring(splitIndex)
    [{value: value1, type }, {value: value2, type}]



  screenRangeFromBufferRange: (bufferRange) ->
    start = @screenPositionFromBufferPosition(bufferRange.start)
    end = @screenPositionFromBufferPosition(bufferRange.end)
    new Range(start,end)

  screenPositionFromBufferPosition: (bufferPosition) ->
    bufferPosition = Point.fromObject(bufferPosition)
    row = 0
    for wrappedLine in @wrappedLines[0...bufferPosition.row]
      row += wrappedLine.screenLines.length

    column = bufferPosition.column
    for screenLine in @wrappedLines[bufferPosition.row].screenLines
      break if screenLine.endColumn > bufferPosition.column
      column -= screenLine.textLength
      row++

    new Point(row, column)

  bufferPositionFromScreenPosition: (screenPosition) ->
    screenPosition = Point.fromObject(screenPosition)
    bufferRow = 0
    currentScreenRow = 0
    for wrappedLine in @wrappedLines
      for screenLine in wrappedLine.screenLines
        if currentScreenRow == screenPosition.row
          return new Point(bufferRow, screenLine.startColumn + screenPosition.column)
        currentScreenRow++
      bufferRow++

  tokensForScreenRow: (screenRow) ->
    currentScreenRow = 0
    for wrappedLine in @wrappedLines
      for screenLine in wrappedLine.screenLines
        return screenLine if currentScreenRow == screenRow
        currentScreenRow++

_.extend(LineWrapper.prototype, EventEmitter)
