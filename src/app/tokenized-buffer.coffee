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

  constructor: (@buffer, { @languageMode, @tabLength }) ->
    @tabLength ?= 2
    @languageMode.tokenizedBuffer = this
    @id = @constructor.idCounter++
    @screenLines = @buildScreenLinesForRows(0, @buffer.getLastRow())
    @buffer.on "change.tokenized-buffer#{@id}", (e) => @handleBufferChange(e)

  handleBufferChange: (e) ->
    oldRange = e.oldRange.copy()
    newRange = e.newRange.copy()
    previousStack = @stackForRow(oldRange.end.row) # used in spill detection below

    stack = @stackForRow(newRange.start.row - 1)
    @screenLines[oldRange.start.row..oldRange.end.row] =
      @buildScreenLinesForRows(newRange.start.row, newRange.end.row, stack)

    # spill detection
    # compare scanner state of last re-highlighted line with its previous state.
    # if it differs, re-tokenize the next line with the new state and repeat for
    # each line until the line's new state matches the previous state. this covers
    # cases like inserting a /* needing to comment out lines below until we see a */
    for row in [newRange.end.row...@buffer.getLastRow()]
      break if _.isEqual(@stackForRow(row), previousStack)
      nextRow = row + 1
      previousStack = @stackForRow(nextRow)
      @screenLines[nextRow] = @buildScreenLineForRow(nextRow, @stackForRow(row))

    # if highlighting spilled beyond the bounds of the textual change, update
    # the pre and post range to reflect area of highlight changes
    if nextRow > newRange.end.row
      oldRange.end.row += (nextRow - newRange.end.row)
      newRange.end.row = nextRow
      endColumn = @buffer.lineForRow(nextRow).length
      newRange.end.column = endColumn
      oldRange.end.column = endColumn

    @trigger("change", {oldRange, newRange})

  buildScreenLinesForRows: (startRow, endRow, startingStack) ->
    stack = startingStack
    for row in [startRow..endRow]
      screenLine = @buildScreenLineForRow(row, stack)
      stack = screenLine.stack
      screenLine

  buildScreenLineForRow: (row, stack) ->
    line = @buffer.lineForRow(row)
    {tokens, stack} = @languageMode.getLineTokens(line, stack)
    tokenObjects = []
    for tokenProperties in tokens
      token = new Token(tokenProperties)
      tokenObjects.push(token.breakOutTabCharacters(@tabLength)...)
    text = _.pluck(tokenObjects, 'value').join('')
    new ScreenLine(tokenObjects, text, [1, 0], [1, 0], { stack })

  lineForScreenRow: (row) ->
    @screenLines[row]

  linesForScreenRows: (startRow, endRow) ->
    @screenLines[startRow..endRow]

  stackForRow: (row) ->
    @screenLines[row]?.stack

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

  isBufferPositionInsideString: (bufferPosition) ->
    if lastScope = _.last(@scopesForPosition(bufferPosition))
      /^string\./.test(lastScope)

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
