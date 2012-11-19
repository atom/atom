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
  untokenizedRow: 0
  chunkSize: 50

  constructor: (@buffer, { @languageMode, @tabLength }) ->
    @tabLength ?= 2
    @id = @constructor.idCounter++
    @screenLines = @buildPlaceholderScreenLinesForRows(0, @buffer.getLastRow())
    @buffer.on "change.tokenized-buffer#{@id}", (e) => @handleBufferChange(e)

  handleBufferChange: (e) ->
    {oldRange, newRange} = e
    start = oldRange.start.row
    end = oldRange.end.row
    delta = newRange.end.row - oldRange.end.row

    previousStack = @stackForRow(end) # used in spill detection below

    stack = @stackForRow(start - 1)
    @screenLines[start..end] = @buildPlaceholderScreenLinesForRows(start, end + delta, stack)

    # spill detection
    # compare scanner state of last re-highlighted line with its previous state.
    # if it differs, re-tokenize the next line with the new state and repeat for
    # each line until the line's new state matches the previous state. this covers
    # cases like inserting a /* needing to comment out lines below until we see a */
    for row in [(end + delta)...@buffer.getLastRow()]
      break if _.isEqual(@stackForRow(row), previousStack)
      nextRow = row + 1
      previousStack = @stackForRow(nextRow)
      @screenLines[nextRow] = @buildTokenizedScreenLineForRow(nextRow, @stackForRow(row))

    # if highlighting spilled beyond the bounds of the textual change, update the
    # end of the affected range to reflect the larger area of highlighting
    end = Math.max(end, nextRow - delta) if nextRow

    @trigger "change", { start, end, delta, bufferChange: e }

  getTabLength: ->
    @tabLength

  setTabLength: (@tabLength) ->
    lastRow = @buffer.getLastRow()
    @screenLines = @buildPlaceholderScreenLinesForRows(0, lastRow)
    @trigger "change", { start: 0, end: lastRow, delta: 0 }

  tokenizeInBackground: ->
    return if @tokenizingInBackground
    @tokenizingInBackground = true
    _.defer => @tokenizeNextChunk()

  tokenizeNextChunk: ->
    lastRow = @buffer.getLastRow()
    stack = @stackForRow(@untokenizedRow - 1)
    start = @untokenizedRow
    end = Math.min(start + @chunkSize - 1, lastRow)
    @screenLines[start..end] = @buildTokenizedScreenLinesForRows(start, end, stack)
    @trigger "change", { start, end, delta: 0}

    @untokenizedRow = end + 1

    if @untokenizedRow <= lastRow
      _.defer => @tokenizeNextChunk()

  buildPlaceholderScreenLinesForRows: (startRow, endRow) ->
    @buildPlaceholderScreenLineForRow(row) for row in [startRow..endRow]

  buildPlaceholderScreenLineForRow: (row) ->
    line = @buffer.lineForRow(row)
    tokens = [new Token(value: line, scopes: [@languageMode.grammar.scopeName])]
    new ScreenLine({tokens, @tabLength})

  buildTokenizedScreenLinesForRows: (startRow, endRow, startingStack) ->
    ruleStack = startingStack
    for row in [startRow..endRow]
      screenLine = @buildTokenizedScreenLineForRow(row, ruleStack)
      ruleStack = screenLine.ruleStack
      screenLine

  buildTokenizedScreenLineForRow: (row, ruleStack) ->
    line = @buffer.lineForRow(row)
    { tokens, ruleStack } = @languageMode.tokenizeLine(line, ruleStack)
    new ScreenLine({tokens, ruleStack, @tabLength})

  lineForScreenRow: (row) ->
    @linesForScreenRows(row, row)[0]

  linesForScreenRows: (startRow, endRow) ->
    @tokenizeInBackground()
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

  logLines: (start=0, end=@buffer.getLastRow()) ->
    for row in [start..end]
      line = @lineForScreenRow(row).text
      console.log row, line, line.length

_.extend(TokenizedBuffer.prototype, EventEmitter)
