_ = require 'underscore-plus'
{Model} = require 'theorist'
{Point, Range} = require 'text-buffer'
Serializable = require 'serializable'
TokenizedLine = require './tokenized-line'
Token = require './token'

module.exports =
class TokenizedBuffer extends Model
  Serializable.includeInto(this)

  @property 'tabLength'

  grammar: null
  currentGrammarScore: null
  buffer: null
  tokenizedLines: null
  chunkSize: 50
  invalidRows: null
  visible: false

  constructor: ({@buffer, @tabLength, @invisibles}) ->
    @tabLength ?= atom.config.getPositiveInt('editor.tabLength', 2)

    @subscribe atom.syntax, 'grammar-added grammar-updated', (grammar) =>
      if grammar.injectionSelector?
        @retokenizeLines() if @hasTokenForSelector(grammar.injectionSelector)
      else
        newScore = grammar.getScore(@buffer.getPath(), @buffer.getText())
        @setGrammar(grammar, newScore) if newScore > @currentGrammarScore

    @on 'grammar-changed grammar-updated', => @retokenizeLines()
    @subscribe @buffer.onDidChange (e) => @handleBufferChange(e)
    @subscribe @buffer.onDidChangePath (@bufferPath) => @reloadGrammar()

    @subscribe @$tabLength.changes, (tabLength) => @retokenizeLines()

    @subscribe atom.config.observe 'editor.tabLength', callNow: false, =>
      @setTabLength(atom.config.getPositiveInt('editor.tabLength', 2))

    @reloadGrammar()

  serializeParams: ->
    bufferPath: @buffer.getPath()
    tabLength: @tabLength
    invisibles: _.clone(@invisibles)

  deserializeParams: (params) ->
    params.buffer = atom.project.bufferForPathSync(params.bufferPath)
    params

  setGrammar: (grammar, score) ->
    return if grammar is @grammar
    @unsubscribe(@grammar) if @grammar
    @grammar = grammar
    @currentGrammarScore = score ? grammar.getScore(@buffer.getPath(), @buffer.getText())
    @subscribe @grammar, 'grammar-updated', => @retokenizeLines()
    @emit 'grammar-changed', grammar

  reloadGrammar: ->
    if grammar = atom.syntax.selectGrammar(@buffer.getPath(), @buffer.getText())
      @setGrammar(grammar)
    else
      throw new Error("No grammar found for path: #{path}")

  hasTokenForSelector: (selector) ->
    for {tokens} in @tokenizedLines
      for token in tokens
        return true if selector.matches(token.scopes)
    false

  retokenizeLines: ->
    lastRow = @buffer.getLastRow()
    @tokenizedLines = @buildPlaceholderTokenizedLinesForRows(0, lastRow)
    @invalidRows = []
    @invalidateRow(0)
    @fullyTokenized = false
    @emit "changed", {start: 0, end: lastRow, delta: 0}

  setVisible: (@visible) ->
    @tokenizeInBackground() if @visible

  # Retrieves the current tab length.
  #
  # Returns a {Number}.
  getTabLength: ->
    @tabLength

  # Specifies the tab length.
  #
  # tabLength - A {Number} that defines the new tab length.
  setTabLength: (@tabLength) ->

  setInvisibles: (invisibles) ->
    unless _.isEqual(invisibles, @invisibles)
      @invisibles = invisibles
      @retokenizeLines()

  tokenizeInBackground: ->
    return if not @visible or @pendingChunk or not @isAlive()
    @pendingChunk = true
    _.defer =>
      @pendingChunk = false
      @tokenizeNextChunk() if @isAlive() and @buffer.isAlive()

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
      @emit "changed", { start: invalidRow, end: row, delta: 0 }

    if @firstInvalidRow()?
      @tokenizeInBackground()
    else
      @emit "tokenized" unless @fullyTokenized
      @fullyTokenized = true

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

    start = @retokenizeWhitespaceRowsIfIndentLevelChanged(start - 1, -1)
    end = @retokenizeWhitespaceRowsIfIndentLevelChanged(newRange.end.row + 1, 1) - delta

    newEndStack = @stackForRow(end + delta)
    if newEndStack and not _.isEqual(newEndStack, previousEndStack)
      @invalidateRow(end + delta + 1)

    @emit "changed", { start, end, delta, bufferChange: e }

  retokenizeWhitespaceRowsIfIndentLevelChanged: (row, increment) ->
    line = @tokenizedLines[row]
    if line?.isOnlyWhitespace() and @indentLevelForRow(row) isnt line.indentLevel
      while line?.isOnlyWhitespace()
        @tokenizedLines[row] = @buildTokenizedTokenizedLineForRow(row, @stackForRow(row - 1))
        row += increment
        line = @tokenizedLines[row]

    row - increment

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
    indentLevel = @indentLevelForRow(row)
    lineEnding = @buffer.lineEndingForRow(row)
    new TokenizedLine({tokens, tabLength, indentLevel, @invisibles, lineEnding})

  buildTokenizedTokenizedLineForRow: (row, ruleStack) ->
    line = @buffer.lineForRow(row)
    lineEnding = @buffer.lineEndingForRow(row)
    tabLength = @getTabLength()
    indentLevel = @indentLevelForRow(row)
    {tokens, ruleStack} = @grammar.tokenizeLine(line, ruleStack, row is 0)
    new TokenizedLine({tokens, ruleStack, tabLength, lineEnding, indentLevel, @invisibles})

  tokenizedLineForRow: (bufferRow) ->
    @tokenizedLines[bufferRow]

  stackForRow: (bufferRow) ->
    @tokenizedLines[bufferRow]?.ruleStack

  indentLevelForRow: (bufferRow) ->
    line = @buffer.lineForRow(bufferRow)
    indentLevel = 0

    if line is ''
      nextRow = bufferRow + 1
      lineCount = @getLineCount()
      while nextRow < lineCount
        nextLine = @buffer.lineForRow(nextRow)
        unless nextLine is ''
          indentLevel = Math.ceil(@indentLevelForLine(nextLine))
          break
        nextRow++

      previousRow = bufferRow - 1
      while previousRow >= 0
        previousLine = @buffer.lineForRow(previousRow)
        unless previousLine is ''
          indentLevel = Math.max(Math.ceil(@indentLevelForLine(previousLine)), indentLevel)
          break
        previousRow--

      indentLevel
    else
      @indentLevelForLine(line)

  indentLevelForLine: (line) ->
    if match = line.match(/^[\t ]+/)
      leadingWhitespace = match[0]
      tabCount = leadingWhitespace.match(/\t/g)?.length ? 0
      spaceCount = leadingWhitespace.match(/[ ]/g)?.length ? 0
      tabCount + (spaceCount / @getTabLength())
    else
      0

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
    range = [startBufferPosition, @buffer.getEndPosition()]
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

  getLineCount: ->
    @buffer.getLineCount()

  logLines: (start=0, end=@buffer.getLastRow()) ->
    for row in [start..end]
      line = @tokenizedLineForRow(row).text
      console.log row, line, line.length
