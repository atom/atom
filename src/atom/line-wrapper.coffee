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

    splitColumn = @findSplitColumn(tokens)
    screenLine = []
    textLength = 0
    while tokens.length
      nextToken = tokens[0]
      if textLength + nextToken.value.length > splitColumn
        tokenFragments = @splitTokenAt(nextToken, splitColumn - textLength)
        [token1, token2] = tokenFragments
        tokens[0..0] = _.compact(tokenFragments)
        break unless token1
      nextToken = tokens.shift()
      textLength += nextToken.value.length
      screenLine.push nextToken

    endColumn = startColumn + textLength
    _.extend(screenLine, { textLength, startColumn, endColumn })
    [screenLine].concat @splitTokens(tokens, endColumn)

  findSplitColumn: (tokens) ->
    lineText = _.pluck(tokens, 'value').join('')
    lineLength = lineText.length
    return lineLength unless lineLength > @maxLength

    if /\s/.test(tokensText[@maxLength])
      # search forward for the start of a word past the boundary
      for column in [@maxLength..lineLength]
        return column if /\S/.test(lineText[column])
      return lineLength
    else
      # search backward for the start of the word on the boundary
      for column in [@maxLength..0]
        return column + 1 if /\s/.test(lineText[column])
      return @maxLength

  splitTokenAt: (token, splitIndex) ->
    { type, value } = token
    switch splitIndex
      when 0
        [null, token]
      when value.length
        [token, null]
      else
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
