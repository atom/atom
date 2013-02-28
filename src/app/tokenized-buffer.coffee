_ = require 'underscore'
ScreenLine = require 'screen-line'
EventEmitter = require 'event-emitter'
Token = require 'token'
Range = require 'range'
Point = require 'point'

module.exports =
class TokenizedBuffer
  @idCounter: 1

  languageMode: null
  tabLength: null
  buffer: null
  aceAdaptor: null
  screenLines: null
  chunkSize: 50
  invalidRows: null
  visible: false

  constructor: (@buffer, { @languageMode, @tabLength }) ->
    @tabLength ?= 2
    @id = @constructor.idCounter++
    @resetScreenLines()
    @buffer.on "changed.tokenized-buffer#{@id}", (e) => @handleBufferChange(e)

  resetScreenLines: ->
    @screenLines = @buildPlaceholderScreenLinesForRows(0, @buffer.getLastRow())
    @invalidRows = []
    @invalidateRow(0)

  setVisible: (@visible) ->
    @tokenizeInBackground() if @visible

  getTabLength: ->
    @tabLength

  setTabLength: (@tabLength) ->
    lastRow = @buffer.getLastRow()
    @screenLines = @buildPlaceholderScreenLinesForRows(0, lastRow)
    @invalidateRow(0)
    @trigger "changed", { start: 0, end: lastRow, delta: 0 }

  tokenizeInBackground: ->
    return if not @visible or @pendingChunk
    @pendingChunk = true
    _.defer =>
      @pendingChunk = false
      @tokenizeNextChunk()

  tokenizeNextChunk: ->
    rowsRemaining = @chunkSize

    while @firstInvalidRow()? and rowsRemaining > 0
      invalidRow = @invalidRows.shift()
      lastRow = @getLastRow()
      continue if invalidRow > lastRow

      row = invalidRow
      loop
        previousStack = @stackForRow(row)
        @screenLines[row] = @buildTokenizedScreenLineForRow(row, @stackForRow(row - 1))
        if --rowsRemaining == 0
          filledRegion = false
          break
        if row == lastRow or _.isEqual(@stackForRow(row), previousStack)
          filledRegion = true
          break
        row++

      @validateRow(row)
      @invalidateRow(row + 1) unless filledRegion
      @trigger "changed", { start: invalidRow, end: row, delta: 0 }

    @tokenizeInBackground() if @firstInvalidRow()?

  firstInvalidRow: ->
    @invalidRows[0]

  validateRow: (row) ->
    @invalidRows.shift() while @invalidRows[0] <= row

  invalidateRow: (row) ->
    @invalidRows.push(row)
    @invalidRows.sort (a, b) -> a - b
    @tokenizeInBackground()

  updateInvalidRows: (start, end, delta) ->
    @invalidRows = @invalidRows.map (row) ->
      if row < start
        row
      else if start <= row <= end
        end + delta + 1
      else if row > end
        row + delta

  handleBufferChange: (e) ->
    {oldRange, newRange} = e
    start = oldRange.start.row
    end = oldRange.end.row
    delta = newRange.end.row - oldRange.end.row

    @updateInvalidRows(start, end, delta)
    previousEndStack = @stackForRow(end) # used in spill detection below
    @screenLines[start..end] = @buildScreenLinesForRows(start, end + delta, @stackForRow(start - 1))
    newEndStack = @stackForRow(end + delta)

    if newEndStack and not _.isEqual(newEndStack, previousEndStack)
      @invalidateRow(end + delta + 1)

    @trigger "changed", { start, end, delta, bufferChange: e }

  buildScreenLinesForRows: (startRow, endRow, startingStack) ->
    ruleStack = startingStack
    stopTokenizingAt = startRow + @chunkSize
    screenLines = for row in [startRow..endRow]
      if (ruleStack or row == 0) and row < stopTokenizingAt
        screenLine = @buildTokenizedScreenLineForRow(row, ruleStack)
        ruleStack = screenLine.ruleStack
      else
        screenLine = @buildPlaceholderScreenLineForRow(row)
      screenLine

    if endRow >= stopTokenizingAt
      @invalidateRow(stopTokenizingAt)
      @tokenizeInBackground()

    screenLines

  buildPlaceholderScreenLinesForRows: (startRow, endRow) ->
    @buildPlaceholderScreenLineForRow(row) for row in [startRow..endRow]

  buildPlaceholderScreenLineForRow: (row) ->
    line = @buffer.lineForRow(row)
    tokens = [new Token(value: line, scopes: [@languageMode.grammar.scopeName])]
    new ScreenLine({tokens, @tabLength})

  buildTokenizedScreenLineForRow: (row, ruleStack) ->
    line = @buffer.lineForRow(row)
    lineEnding = @buffer.lineEndingForRow(row)
    { tokens, ruleStack } = @languageMode.tokenizeLine(line, ruleStack, row is 0)
    new ScreenLine({tokens, ruleStack, @tabLength, lineEnding})

  lineForScreenRow: (row) ->
    @linesForScreenRows(row, row)[0]

  linesForScreenRows: (startRow, endRow) ->
    @screenLines[startRow..endRow]

  stackForRow: (row) ->
    @screenLines[row]?.ruleStack

  scopesForPosition: (position) ->
    position = Point.fromObject(position)
    token = @screenLines[position.row].tokenAtBufferColumn(position.column)
    token.scopes

  destroy: ->
    @buffer.off ".tokenized-buffer#{@id}"

  iterateTokensInBufferRange: (bufferRange, iterator) ->
    bufferRange = Range.fromObject(bufferRange)
    { start, end } = bufferRange

    keepLooping = true
    stop = -> keepLooping = false

    for bufferRow in [start.row..end.row]
      bufferColumn = 0
      for token in @screenLines[bufferRow].tokens
        startOfToken = new Point(bufferRow, bufferColumn)
        iterator(token, startOfToken, { stop }) if bufferRange.containsPoint(startOfToken)
        return unless keepLooping
        bufferColumn += token.bufferDelta

  backwardsIterateTokensInBufferRange: (bufferRange, iterator) ->
    bufferRange = Range.fromObject(bufferRange)
    { start, end } = bufferRange

    keepLooping = true
    stop = -> keepLooping = false

    for bufferRow in [end.row..start.row]
      bufferColumn = @buffer.lineLengthForRow(bufferRow)
      for token in new Array(@screenLines[bufferRow].tokens...).reverse()
        bufferColumn -= token.bufferDelta
        startOfToken = new Point(bufferRow, bufferColumn)
        iterator(token, startOfToken, { stop }) if bufferRange.containsPoint(startOfToken)
        return unless keepLooping

  findOpeningBracket: (startBufferPosition) ->
    range = [[0,0], startBufferPosition]
    position = null
    depth = 0
    @backwardsIterateTokensInBufferRange range, (token, startPosition, { stop }) ->
      if token.isBracket()
        if token.value == '}'
          depth++
        else if token.value == '{'
          depth--
          if depth == 0
            position = startPosition
            stop()
    position

  findClosingBracket: (startBufferPosition) ->
    range = [startBufferPosition, @buffer.getEofPosition()]
    position = null
    depth = 0
    @iterateTokensInBufferRange range, (token, startPosition, { stop }) ->
      if token.isBracket()
        if token.value == '{'
          depth++
        else if token.value == '}'
          depth--
          if depth == 0
            position = startPosition
            stop()
    position

  getLastRow: ->
    @buffer.getLastRow()

  logLines: (start=0, end=@buffer.getLastRow()) ->
    for row in [start..end]
      line = @lineForScreenRow(row).text
      console.log row, line, line.length

  getDebugSnapshot: ->
    lines = ["Tokenized Buffer:"]
    for screenLine, row in @linesForScreenRows(0, @getLastRow())
      lines.push "#{row}: #{screenLine.text}"
    lines.join('\n')

_.extend(TokenizedBuffer.prototype, EventEmitter)
