_ = require 'underscore'
ScreenLine = require 'screen-line'
EventEmitter = require 'event-emitter'
Token = require 'token'
Range = require 'range'
Point = require 'point'
AceAdaptor = require 'ace-adaptor'

module.exports =
class TokenizedBuffer
  @idCounter: 1

  buffer: null
  aceMode: null
  aceAdaptor: null
  screenLines: null

  constructor: (@buffer, @tabText) ->
    @id = @constructor.idCounter++
    @aceMode = @requireAceMode()
    @screenLines = @buildScreenLinesForRows('start', 0, @buffer.getLastRow())
    @buffer.on "change.tokenized-buffer#{@id}", (e) => @handleBufferChange(e)
    @aceAdaptor = new AceAdaptor(this)

  requireAceMode: ->
    modeName = switch @buffer.getExtension()
      when 'js' then 'javascript'
      when 'coffee' then 'coffee'
      when 'rb', 'ru' then 'ruby'
      when 'c', 'h', 'cpp' then 'c_cpp'
      when 'html', 'htm' then 'html'
      when 'css' then 'css'
      when 'java' then 'java'
      when 'xml' then 'xml'
      else 'text'
    new (require("ace/mode/#{modeName}").Mode)

  toggleLineCommentsInRange: (range) ->
    range = Range.fromObject(range)
    @aceMode.toggleCommentLines(@stateForRow(range.start.row), @aceAdaptor, range.start.row, range.end.row)

  isBufferRowFoldable: (bufferRow) ->
    @aceMode.foldingRules?.getFoldWidget(@aceAdaptor, null, bufferRow) == "start"

  rowRangeForFoldAtBufferRow: (bufferRow) ->
    if aceRange = @aceMode.foldingRules?.getFoldWidgetRange(@aceAdaptor, null, bufferRow)
      [aceRange.start.row, aceRange.end.row]
    else
      null

  autoIndentTextAfterBufferPosition: (text, bufferPosition) ->
    { row, column} = bufferPosition
    state = @stateForRow(row)
    lineBeforeCursor = @buffer.lineForRow(row)[0...column]
    if text[0] == "\n"
      indent = @aceMode.getNextLineIndent(state, lineBeforeCursor, @tabText)
      text = text[0] + indent + text[1..]
    else if @aceMode.checkOutdent(state, lineBeforeCursor, text)
      shouldOutdent = true

    {text, shouldOutdent}

  autoOutdentBufferRow: (bufferRow) ->
    state = @stateForRow(bufferRow)
    @aceMode.autoOutdent(state, @aceAdaptor, bufferRow)

  handleBufferChange: (e) ->
    oldRange = e.oldRange.copy()
    newRange = e.newRange.copy()
    previousState = @stateForRow(oldRange.end.row) # used in spill detection below

    startState = @stateForRow(newRange.start.row - 1)
    @screenLines[oldRange.start.row..oldRange.end.row] =
      @buildScreenLinesForRows(startState, newRange.start.row, newRange.end.row)

    # spill detection
    # compare scanner state of last re-highlighted line with its previous state.
    # if it differs, re-tokenize the next line with the new state and repeat for
    # each line until the line's new state matches the previous state. this covers
    # cases like inserting a /* needing to comment out lines below until we see a */
    for row in [newRange.end.row...@buffer.getLastRow()]
      break if @stateForRow(row) == previousState
      nextRow = row + 1
      previousState = @stateForRow(nextRow)
      @screenLines[nextRow] = @buildScreenLineForRow(@stateForRow(row), nextRow)

    # if highlighting spilled beyond the bounds of the textual change, update
    # the pre and post range to reflect area of highlight changes
    if nextRow > newRange.end.row
      oldRange.end.row += (nextRow - newRange.end.row)
      newRange.end.row = nextRow
      endColumn = @buffer.lineForRow(nextRow).length
      newRange.end.column = endColumn
      oldRange.end.column = endColumn

    @trigger("change", {oldRange, newRange})

  buildScreenLinesForRows: (startState, startRow, endRow) ->
    state = startState
    for row in [startRow..endRow]
      screenLine = @buildScreenLineForRow(state, row)
      state = screenLine.state
      screenLine

  buildScreenLineForRow: (state, row) ->
    tokenizer = @aceMode.getTokenizer()
    line = @buffer.lineForRow(row)
    {tokens, state} = tokenizer.getLineTokens(line, state)
    tokenObjects = []
    for tokenProperties in tokens
      token = new Token(tokenProperties)
      tokenObjects.push(token.breakOutTabCharacters(@tabText)...)
    text = _.pluck(tokenObjects, 'value').join('')
    new ScreenLine(tokenObjects, text, [1, 0], [1, 0], { state })

  lineForScreenRow: (row) ->
    @screenLines[row]

  linesForScreenRows: (startRow, endRow) ->
    @screenLines[startRow..endRow]

  stateForRow: (row) ->
    @screenLines[row]?.state ? 'start'

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
      if token.type.match /lparen|rparen/
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
      if token.type.match /lparen|rparen/
        if token.value == '{'
          depth++
        else if token.value == '}'
          depth--
          if depth == 0
            position = startPosition
            stop()
    position

_.extend(TokenizedBuffer.prototype, EventEmitter)
