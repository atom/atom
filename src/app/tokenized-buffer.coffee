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

  constructor: (@buffer, { @languageMode, @tabLength }) ->
    @tabLength ?= 2
    @id = @constructor.idCounter++
    @screenLines = @buildPlaceholderScreenLinesForRows(0, @buffer.getLastRow())
    @invalidRows = [0]
    @tokenizeInBackground()
    @buffer.on "change.tokenized-buffer#{@id}", (e) => @handleBufferChange(e)

  handleBufferChange: (e) ->
    {oldRange, newRange} = e
    start = oldRange.start.row
    end = oldRange.end.row
    delta = newRange.end.row - oldRange.end.row

    previousStack = @stackForRow(end) # used in spill detection below

    stack = @stackForRow(start - 1)

    @screenLines[start..end] = @buildTokenizedScreenLinesForRows(start, end + delta, stack)

    # spill detection
    # compare scanner state of last re-highlighted line with its previous state.
    # if it differs, re-tokenize the next line with the new state and repeat for
    # each line until the line's new state matches the previous state. this covers
    # cases like inserting a /* needing to comment out lines below until we see a */


    unless _.isEqual(@stackForRow(end + delta), previousStack)
      console.log "spill"
      @invalidRows.unshift(end + 1)
      @tokenizeInBackground()

#     for row in [(end + delta)...@buffer.getLastRow()]
#
#       nextRow = row + 1
#       previousStack = @stackForRow(nextRow)
#       @screenLines[nextRow] = @buildTokenizedScreenLineForRow(nextRow, @stackForRow(row))

    # if highlighting spilled beyond the bounds of the textual change, update the
    # end of the affected range to reflect the larger area of highlighting
#     end = Math.max(end, nextRow - delta) if nextRow
    @trigger "change", { start, end, delta, bufferChange: e }

  getTabLength: ->
    @tabLength

  setTabLength: (@tabLength) ->
    lastRow = @buffer.getLastRow()
    @invalidRows = [0]
    @screenLines = @buildPlaceholderScreenLinesForRows(0, lastRow)
    @tokenizeInBackground()
    @trigger "change", { start: 0, end: lastRow, delta: 0 }

  tokenizeInBackground: ->
    return if @pendingChunk
    @pendingChunk = true
    _.defer =>
      @pendingChunk = false
      @tokenizeNextChunk()

  tokenizeNextChunk: ->
    rowsRemaining = @chunkSize

    while @invalidRows.length and rowsRemaining > 0
      invalidRow = @invalidRows.shift()
      lastRow = @getLastRow()
      continue if invalidRow > lastRow

      filledRegion = false
      row = invalidRow
      loop
        previousStack = @stackForRow(row)
        @screenLines[row] = @buildTokenizedScreenLineForRow(row, @stackForRow(row - 1))
        if row == lastRow or _.isEqual(@stackForRow(row), previousStack)
          filledRegion = true
          break
        if --rowsRemaining == 0
          break
        row++

      @trigger "change", { start: invalidRow, end: row, delta: 0}
      @invalidRows.unshift(row + 1) unless filledRegion

    @tokenizeInBackground()

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

_.extend(TokenizedBuffer.prototype, EventEmitter)
