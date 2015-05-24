_ = require 'underscore-plus'
{CompositeDisposable, Emitter} = require 'event-kit'
{Point, Range} = require 'text-buffer'
Serializable = require 'serializable'
Model = require './model'
TokenizedLine = require './tokenized-line'
Token = require './token'
ScopeDescriptor = require './scope-descriptor'
Grim = require 'grim'

module.exports =
class TokenizedBuffer extends Model
  Serializable.includeInto(this)

  grammar: null
  currentGrammarScore: null
  buffer: null
  tabLength: null
  tokenizedLines: null
  chunkSize: 50
  invalidRows: null
  visible: false
  configSettings: null

  constructor: ({@buffer, @tabLength, @ignoreInvisibles}) ->
    @emitter = new Emitter
    @disposables = new CompositeDisposable

    @disposables.add atom.grammars.onDidAddGrammar(@grammarAddedOrUpdated)
    @disposables.add atom.grammars.onDidUpdateGrammar(@grammarAddedOrUpdated)

    @disposables.add @buffer.preemptDidChange (e) => @handleBufferChange(e)
    @disposables.add @buffer.onDidChangePath (@bufferPath) => @reloadGrammar()

    @reloadGrammar()

  destroyed: ->
    @disposables.dispose()

  serializeParams: ->
    bufferPath: @buffer.getPath()
    tabLength: @tabLength
    ignoreInvisibles: @ignoreInvisibles

  deserializeParams: (params) ->
    params.buffer = atom.project.bufferForPathSync(params.bufferPath)
    params

  observeGrammar: (callback) ->
    callback(@grammar)
    @onDidChangeGrammar(callback)

  onDidChangeGrammar: (callback) ->
    @emitter.on 'did-change-grammar', callback

  onDidChange: (callback) ->
    @emitter.on 'did-change', callback

  onDidTokenize: (callback) ->
    @emitter.on 'did-tokenize', callback

  grammarAddedOrUpdated: (grammar) =>
    if grammar.injectionSelector?
      @retokenizeLines() if @hasTokenForSelector(grammar.injectionSelector)
    else
      newScore = grammar.getScore(@buffer.getPath(), @buffer.getText())
      @setGrammar(grammar, newScore) if newScore > @currentGrammarScore

  setGrammar: (grammar, score) ->
    return if grammar is @grammar

    @grammar = grammar
    @rootScopeDescriptor = new ScopeDescriptor(scopes: [@grammar.scopeName])
    @currentGrammarScore = score ? grammar.getScore(@buffer.getPath(), @buffer.getText())

    @grammarUpdateDisposable?.dispose()
    @grammarUpdateDisposable = @grammar.onDidUpdate => @retokenizeLines()
    @disposables.add(@grammarUpdateDisposable)

    scopeOptions = {scope: @rootScopeDescriptor}
    @configSettings =
      tabLength: atom.config.get('editor.tabLength', scopeOptions)
      invisibles: atom.config.get('editor.invisibles', scopeOptions)
      showInvisibles: atom.config.get('editor.showInvisibles', scopeOptions)

    if @configSubscriptions?
      @configSubscriptions.dispose()
      @disposables.remove(@configSubscriptions)
    @configSubscriptions = new CompositeDisposable
    @configSubscriptions.add atom.config.onDidChange 'editor.tabLength', scopeOptions, ({newValue}) =>
      @configSettings.tabLength = newValue
      @retokenizeLines()
    ['invisibles', 'showInvisibles'].forEach (key) =>
      @configSubscriptions.add atom.config.onDidChange "editor.#{key}", scopeOptions, ({newValue}) =>
        oldInvisibles = @getInvisiblesToShow()
        @configSettings[key] = newValue
        @retokenizeLines() unless _.isEqual(@getInvisiblesToShow(), oldInvisibles)
    @disposables.add(@configSubscriptions)

    @retokenizeLines()

    @emit 'grammar-changed', grammar if Grim.includeDeprecatedAPIs
    @emitter.emit 'did-change-grammar', grammar

  reloadGrammar: ->
    if grammar = atom.grammars.selectGrammar(@buffer.getPath(), @buffer.getText())
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
    event = {start: 0, end: lastRow, delta: 0}
    @emit 'changed', event if Grim.includeDeprecatedAPIs
    @emitter.emit 'did-change', event

  setVisible: (@visible) ->
    @tokenizeInBackground() if @visible

  getTabLength: ->
    @tabLength ? @configSettings.tabLength

  setTabLength: (tabLength) ->
    return if tabLength is @tabLength

    @tabLength = tabLength
    @retokenizeLines()

  setIgnoreInvisibles: (ignoreInvisibles) ->
    if ignoreInvisibles isnt @ignoreInvisibles
      @ignoreInvisibles = ignoreInvisibles
      if @configSettings.showInvisibles and @configSettings.invisibles?
        @retokenizeLines()

  tokenizeInBackground: ->
    return if not @visible or @pendingChunk or not @isAlive()

    @pendingChunk = true
    _.defer =>
      @pendingChunk = false
      @tokenizeNextChunk() if @isAlive() and @buffer.isAlive()

  tokenizeNextChunk: ->
    # Short circuit null grammar which can just use the placeholder tokens
    if @grammar is atom.grammars.nullGrammar and @firstInvalidRow()?
      @invalidRows = []
      @markTokenizationComplete()
      return

    rowsRemaining = @chunkSize

    while @firstInvalidRow()? and rowsRemaining > 0
      startRow = @invalidRows.shift()
      lastRow = @getLastRow()
      continue if startRow > lastRow

      row = startRow
      loop
        previousStack = @stackForRow(row)
        @tokenizedLines[row] = @buildTokenizedLineForRow(row, @stackForRow(row - 1))
        if --rowsRemaining is 0
          filledRegion = false
          endRow = row
          break
        if row is lastRow or _.isEqual(@stackForRow(row), previousStack)
          filledRegion = true
          endRow = row
          break
        row++

      @validateRow(endRow)
      @invalidateRow(endRow + 1) unless filledRegion

      [startRow, endRow] = @updateFoldableStatus(startRow, endRow)

      event = {start: startRow, end: endRow, delta: 0}
      @emit 'changed', event if Grim.includeDeprecatedAPIs
      @emitter.emit 'did-change', event

    if @firstInvalidRow()?
      @tokenizeInBackground()
    else
      @markTokenizationComplete()

  markTokenizationComplete: ->
    unless @fullyTokenized
      @emit 'tokenized' if Grim.includeDeprecatedAPIs
      @emitter.emit 'did-tokenize'
    @fullyTokenized = true

  firstInvalidRow: ->
    @invalidRows[0]

  validateRow: (row) ->
    @invalidRows.shift() while @invalidRows[0] <= row
    return

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

    [start, end] = @updateFoldableStatus(start, end + delta)
    end -= delta

    event = {start, end, delta, bufferChange: e}
    @emit 'changed', event if Grim.includeDeprecatedAPIs
    @emitter.emit 'did-change', event

  retokenizeWhitespaceRowsIfIndentLevelChanged: (row, increment) ->
    line = @tokenizedLines[row]
    if line?.isOnlyWhitespace() and @indentLevelForRow(row) isnt line.indentLevel
      while line?.isOnlyWhitespace()
        @tokenizedLines[row] = @buildTokenizedLineForRow(row, @stackForRow(row - 1))
        row += increment
        line = @tokenizedLines[row]

    row - increment

  updateFoldableStatus: (startRow, endRow) ->
    scanStartRow = @buffer.previousNonBlankRow(startRow) ? startRow
    scanStartRow-- while scanStartRow > 0 and @tokenizedLineForRow(scanStartRow).isComment()
    scanEndRow = @buffer.nextNonBlankRow(endRow) ? endRow

    for row in [scanStartRow..scanEndRow] by 1
      foldable = @isFoldableAtRow(row)
      line = @tokenizedLineForRow(row)
      unless line.foldable is foldable
        line.foldable = foldable
        startRow = Math.min(startRow, row)
        endRow = Math.max(endRow, row)

    [startRow, endRow]

  isFoldableAtRow: (row) ->
    @isFoldableCodeAtRow(row) or @isFoldableCommentAtRow(row)

  # Returns a {Boolean} indicating whether the given buffer row starts
  # a a foldable row range due to the code's indentation patterns.
  isFoldableCodeAtRow: (row) ->
    return false if @buffer.isRowBlank(row) or @tokenizedLineForRow(row).isComment()
    nextRow = @buffer.nextNonBlankRow(row)
    return false unless nextRow?

    @indentLevelForRow(nextRow) > @indentLevelForRow(row)

  isFoldableCommentAtRow: (row) ->
    previousRow = row - 1
    nextRow = row + 1
    return false if nextRow > @buffer.getLastRow()

    (row is 0 or not @tokenizedLineForRow(previousRow).isComment()) and
      @tokenizedLineForRow(row).isComment() and
      @tokenizedLineForRow(nextRow).isComment()

  buildTokenizedLinesForRows: (startRow, endRow, startingStack) ->
    ruleStack = startingStack
    stopTokenizingAt = startRow + @chunkSize
    tokenizedLines = for row in [startRow..endRow]
      if (ruleStack or row is 0) and row < stopTokenizingAt
        screenLine = @buildTokenizedLineForRow(row, ruleStack)
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
    new TokenizedLine({tokens, tabLength, indentLevel, invisibles: @getInvisiblesToShow(), lineEnding})

  buildTokenizedLineForRow: (row, ruleStack) ->
    @buildTokenizedLineForRowWithText(row, @buffer.lineForRow(row), ruleStack)

  buildTokenizedLineForRowWithText: (row, line, ruleStack = @stackForRow(row - 1)) ->
    lineEnding = @buffer.lineEndingForRow(row)
    tabLength = @getTabLength()
    indentLevel = @indentLevelForRow(row)
    {tokens, ruleStack} = @grammar.tokenizeLine(line, ruleStack, row is 0)
    new TokenizedLine({tokens, ruleStack, tabLength, lineEnding, indentLevel, invisibles: @getInvisiblesToShow()})

  getInvisiblesToShow: ->
    if @configSettings.showInvisibles and not @ignoreInvisibles
      @configSettings.invisibles
    else
      null

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

  scopeDescriptorForPosition: (position) ->
    new ScopeDescriptor(scopes: @tokenForPosition(position).scopes)

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
    {start, end} = bufferRange

    keepLooping = true
    stop = -> keepLooping = false

    for bufferRow in [start.row..end.row]
      bufferColumn = 0
      for token in @tokenizedLines[bufferRow].tokens
        startOfToken = new Point(bufferRow, bufferColumn)
        iterator(token, startOfToken, {stop}) if bufferRange.containsPoint(startOfToken)
        return unless keepLooping
        bufferColumn += token.bufferDelta

  backwardsIterateTokensInBufferRange: (bufferRange, iterator) ->
    bufferRange = Range.fromObject(bufferRange)
    {start, end} = bufferRange

    keepLooping = true
    stop = -> keepLooping = false

    for bufferRow in [end.row..start.row]
      bufferColumn = @buffer.lineLengthForRow(bufferRow)
      for token in new Array(@tokenizedLines[bufferRow].tokens...).reverse()
        bufferColumn -= token.bufferDelta
        startOfToken = new Point(bufferRow, bufferColumn)
        iterator(token, startOfToken, {stop}) if bufferRange.containsPoint(startOfToken)
        return unless keepLooping

  findOpeningBracket: (startBufferPosition) ->
    range = [[0,0], startBufferPosition]
    position = null
    depth = 0
    @backwardsIterateTokensInBufferRange range, (token, startPosition, {stop}) ->
      if token.isBracket()
        if token.value is '}'
          depth++
        else if token.value is '{'
          depth--
          if depth is 0
            position = startPosition
            stop()
    position

  findClosingBracket: (startBufferPosition) ->
    range = [startBufferPosition, @buffer.getEndPosition()]
    position = null
    depth = 0
    @iterateTokensInBufferRange range, (token, startPosition, {stop}) ->
      if token.isBracket()
        if token.value is '{'
          depth++
        else if token.value is '}'
          depth--
          if depth is 0
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
    return

if Grim.includeDeprecatedAPIs
  EmitterMixin = require('emissary').Emitter

  TokenizedBuffer::on = (eventName) ->
    switch eventName
      when 'changed'
        Grim.deprecate("Use TokenizedBuffer::onDidChange instead")
      when 'grammar-changed'
        Grim.deprecate("Use TokenizedBuffer::onDidChangeGrammar instead")
      when 'tokenized'
        Grim.deprecate("Use TokenizedBuffer::onDidTokenize instead")
      else
        Grim.deprecate("TokenizedBuffer::on is deprecated. Use event subscription methods instead.")

    EmitterMixin::on.apply(this, arguments)
