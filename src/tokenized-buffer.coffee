_ = require 'underscore'
TokenizedLine = require 'tokenized-line'
EventEmitter = require 'event-emitter'
Subscriber = require 'subscriber'
Token = require 'token'
telepath = require 'telepath'
{Point, Range} = telepath

### Internal ###

module.exports =
class TokenizedBuffer
  grammar: null
  currentGrammarScore: null
  buffer: null
  tokenizedLines: null
  chunkSize: 50
  invalidRows: null
  visible: false

  @acceptsDocuments: true
  registerDeserializer(this)

  @deserialize: (state) ->
    new this(state)

  constructor: (optionsOrState) ->
    if optionsOrState instanceof telepath.Document
      @state = optionsOrState
      @buffer = project.bufferForPath(optionsOrState.get('bufferPath'))
    else
      { @buffer, tabLength } = optionsOrState
      @state = site.createDocument
        deserializer: @constructor.name
        bufferPath: @buffer.getRelativePath()
        tabLength: tabLength ? 2

    @subscribe syntax, 'grammar-added grammar-updated', (grammar) =>
      if grammar.injectionSelector?
        @resetTokenizedLines() if @hasTokenForSelector(grammar.injectionSelector)
      else
        newScore = grammar.getScore(@buffer.getPath(), @buffer.getText())
        @setGrammar(grammar, newScore) if newScore > @currentGrammarScore

    @on 'grammar-changed grammar-updated', => @resetTokenizedLines()
    @subscribe @buffer, "changed", (e) => @handleBufferChange(e)
    @subscribe @buffer, "path-changed", => @state.set('bufferPath', @buffer.getRelativePath())

    @reloadGrammar()

  serialize: -> @state.clone()
  getState: -> @state

  setGrammar: (grammar, score) ->
    return if grammar is @grammar
    @unsubscribe(@grammar) if @grammar
    @grammar = grammar
    @currentGrammarScore = score ? grammar.getScore(@buffer.getPath(), @buffer.getText())
    @subscribe @grammar, 'grammar-updated', => @resetTokenizedLines()
    @trigger 'grammar-changed', grammar

  reloadGrammar: ->
    if grammar = syntax.selectGrammar(@buffer.getPath(), @buffer.getText())
      @setGrammar(grammar)
    else
      throw new Error("No grammar found for path: #{path}")

  hasTokenForSelector: (selector) ->
    for {tokens} in @tokenizedLines
      for token in tokens
        return true if selector.matches(token.scopes)
    false

  resetTokenizedLines: ->
    @tokenizedLines = @buildPlaceholderTokenizedLinesForRows(0, @buffer.getLastRow())
    @invalidRows = []
    @invalidateRow(0)

  setVisible: (@visible) ->
    @tokenizeInBackground() if @visible

  # Retrieves the current tab length.
  #
  # Returns a {Number}.
  getTabLength: ->
    @state.get('tabLength')

  # Specifies the tab length.
  #
  # tabLength - A {Number} that defines the new tab length.
  setTabLength: (tabLength) ->
    @state.set('tabLength', tabLength)
    lastRow = @buffer.getLastRow()
    @tokenizedLines = @buildPlaceholderTokenizedLinesForRows(0, lastRow)
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
        @tokenizedLines[row] = @buildTokenizedTokenizedLineForRow(row, @stackForRow(row - 1))
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
    newTokenizedLines = @buildTokenizedLinesForRows(start, end + delta, @stackForRow(start - 1))
    _.spliceWithArray(@tokenizedLines, start, end - start + 1, newTokenizedLines)
    newEndStack = @stackForRow(end + delta)

    if newEndStack and not _.isEqual(newEndStack, previousEndStack)
      @invalidateRow(end + delta + 1)

    @trigger "changed", { start, end, delta, bufferChange: e }

  buildTokenizedLinesForRows: (startRow, endRow, startingStack) ->
    ruleStack = startingStack
    stopTokenizingAt = startRow + @chunkSize
    tokenizedLines = for row in [startRow..endRow]
      if (ruleStack or row == 0) and row < stopTokenizingAt
        screenLine = @buildTokenizedTokenizedLineForRow(row, ruleStack)
        ruleStack = screenLine.ruleStack
      else
        screenLine = @buildPlaceholderTokenizedLineForRow(row)
      screenLine

    if endRow >= stopTokenizingAt
      @invalidateRow(stopTokenizingAt)
      @tokenizeInBackground()

    tokenizedLines

  buildPlaceholderTokenizedLinesForRows: (startRow, endRow) ->
    @buildPlaceholderTokenizedLineForRow(row) for row in [startRow..endRow]

  buildPlaceholderTokenizedLineForRow: (row) ->
    line = @buffer.lineForRow(row)
    tokens = [new Token(value: line, scopes: [@grammar.scopeName])]
    tabLength = @getTabLength()
    new TokenizedLine({tokens, tabLength})

  buildTokenizedTokenizedLineForRow: (row, ruleStack) ->
    line = @buffer.lineForRow(row)
    lineEnding = @buffer.lineEndingForRow(row)
    tabLength = @getTabLength()
    { tokens, ruleStack } = @grammar.tokenizeLine(line, ruleStack, row is 0)
    new TokenizedLine({tokens, ruleStack, tabLength, lineEnding})

  # FIXME: benogle says: These are actually buffer rows as all buffer rows are
  # accounted for in @tokenizedLines
  lineForScreenRow: (row) ->
    @linesForScreenRows(row, row)[0]

  # FIXME: benogle says: These are actually buffer rows as all buffer rows are
  # accounted for in @tokenizedLines
  linesForScreenRows: (startRow, endRow) ->
    @tokenizedLines[startRow..endRow]

  stackForRow: (row) ->
    @tokenizedLines[row]?.ruleStack

  scopesForPosition: (position) ->
    @tokenForPosition(position).scopes

  tokenForPosition: (position) ->
    {row, column} = Point.fromObject(position)
    @tokenizedLines[row].tokenAtBufferColumn(column)

  tokenStartPositionForPosition: (position) ->
    {row, column} = Point.fromObject(position)
    column = @tokenizedLines[row].tokenStartColumnForBufferColumn(column)
    new Point(row, column)

  bufferRangeForScopeAtPosition: (selector, position) ->
    position = Point.fromObject(position)
    tokenizedLine = @tokenizedLines[position.row]
    startIndex = tokenizedLine.tokenIndexAtBufferColumn(position.column)

    for index in [startIndex..0]
      token = tokenizedLine.tokenAtIndex(index)
      break unless token.matchesScopeSelector(selector)
      firstToken = token

    for index in [startIndex...tokenizedLine.getTokenCount()]
      token = tokenizedLine.tokenAtIndex(index)
      break unless token.matchesScopeSelector(selector)
      lastToken = token

    return unless firstToken? and lastToken?

    startColumn = tokenizedLine.bufferColumnForToken(firstToken)
    endColumn = tokenizedLine.bufferColumnForToken(lastToken) + lastToken.bufferDelta
    new Range([position.row, startColumn], [position.row, endColumn])

  destroy: ->
    @unsubscribe()

  iterateTokensInBufferRange: (bufferRange, iterator) ->
    bufferRange = Range.fromObject(bufferRange)
    { start, end } = bufferRange

    keepLooping = true
    stop = -> keepLooping = false

    for bufferRow in [start.row..end.row]
      bufferColumn = 0
      for token in @tokenizedLines[bufferRow].tokens
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
      for token in new Array(@tokenizedLines[bufferRow].tokens...).reverse()
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

  # Gets the row number of the last line.
  #
  # Returns a {Number}.
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
_.extend(TokenizedBuffer.prototype, Subscriber)
