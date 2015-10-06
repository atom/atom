_ = require 'underscore-plus'
{CompositeDisposable, Emitter} = require 'event-kit'
{Point, Range} = require 'text-buffer'
{ScopeSelector} = require 'first-mate'
Model = require './model'
TokenizedLine = require './tokenized-line'
TokenIterator = require './token-iterator'
Token = require './token'
ScopeDescriptor = require './scope-descriptor'

module.exports =
class TokenizedBuffer extends Model
  grammar: null
  currentGrammarScore: null
  buffer: null
  tabLength: null
  tokenizedLines: null
  chunkSize: 50
  invalidRows: null
  visible: false
  configSettings: null
  changeCount: 0

  @deserialize: (state, atomEnvironment) ->
    state.buffer = atomEnvironment.project.bufferForPathSync(state.bufferPath)
    state.config = atomEnvironment.config
    state.grammarRegistry = atomEnvironment.grammars
    state.packageManager = atomEnvironment.packages
    state.assert = atomEnvironment.assert
    new this(state)

  constructor: (params) ->
    {
      @buffer, @tabLength, @ignoreInvisibles, @largeFileMode, @config,
      @grammarRegistry, @packageManager, @assert
    } = params

    @emitter = new Emitter
    @disposables = new CompositeDisposable
    @tokenIterator = new TokenIterator({@grammarRegistry})

    @disposables.add @grammarRegistry.onDidAddGrammar(@grammarAddedOrUpdated)
    @disposables.add @grammarRegistry.onDidUpdateGrammar(@grammarAddedOrUpdated)

    @disposables.add @buffer.preemptDidChange (e) => @handleBufferChange(e)
    @disposables.add @buffer.onDidChangePath (@bufferPath) => @reloadGrammar()

    @reloadGrammar()

  destroyed: ->
    @disposables.dispose()

  serialize: ->
    deserializer: 'TokenizedBuffer'
    bufferPath: @buffer.getPath()
    tabLength: @tabLength
    ignoreInvisibles: @ignoreInvisibles
    largeFileMode: @largeFileMode

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
      newScore = @grammarRegistry.getGrammarScore(grammar, @buffer.getPath(), @getGrammarSelectionContent())
      @setGrammar(grammar, newScore) if newScore > @currentGrammarScore

  setGrammar: (grammar, score) ->
    return unless grammar? and grammar isnt @grammar

    @grammar = grammar
    @rootScopeDescriptor = new ScopeDescriptor(scopes: [@grammar.scopeName])
    @currentGrammarScore = score ? @grammarRegistry.getGrammarScore(grammar, @buffer.getPath(), @getGrammarSelectionContent())

    @grammarUpdateDisposable?.dispose()
    @grammarUpdateDisposable = @grammar.onDidUpdate => @retokenizeLines()
    @disposables.add(@grammarUpdateDisposable)

    scopeOptions = {scope: @rootScopeDescriptor}
    @configSettings =
      tabLength: @config.get('editor.tabLength', scopeOptions)
      invisibles: @config.get('editor.invisibles', scopeOptions)
      showInvisibles: @config.get('editor.showInvisibles', scopeOptions)

    if @configSubscriptions?
      @configSubscriptions.dispose()
      @disposables.remove(@configSubscriptions)
    @configSubscriptions = new CompositeDisposable
    @configSubscriptions.add @config.onDidChange 'editor.tabLength', scopeOptions, ({newValue}) =>
      @configSettings.tabLength = newValue
      @retokenizeLines()
    ['invisibles', 'showInvisibles'].forEach (key) =>
      @configSubscriptions.add @config.onDidChange "editor.#{key}", scopeOptions, ({newValue}) =>
        oldInvisibles = @getInvisiblesToShow()
        @configSettings[key] = newValue
        @retokenizeLines() unless _.isEqual(@getInvisiblesToShow(), oldInvisibles)
    @disposables.add(@configSubscriptions)

    @retokenizeLines()
    @packageManager.triggerActivationHook("#{grammar.packageName}:grammar-used")
    @emitter.emit 'did-change-grammar', grammar

  getGrammarSelectionContent: ->
    @buffer.getTextInRange([[0, 0], [10, 0]])

  reloadGrammar: ->
    if grammar = @grammarRegistry.selectGrammar(@buffer.getPath(), @getGrammarSelectionContent())
      @setGrammar(grammar)
    else
      throw new Error("No grammar found for path: #{path}")

  hasTokenForSelector: (selector) ->
    for tokenizedLine in @tokenizedLines when tokenizedLine?
      for token in tokenizedLine.tokens
        return true if selector.matches(token.scopes)
    false

  retokenizeLines: ->
    lastRow = @buffer.getLastRow()
    @tokenizedLines = new Array(lastRow + 1)
    @invalidRows = []
    @invalidateRow(0)
    @fullyTokenized = false
    event = {start: 0, end: lastRow, delta: 0}
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
    if @grammar is @grammarRegistry.nullGrammar and @firstInvalidRow()?
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
        @tokenizedLines[row] = @buildTokenizedLineForRow(row, @stackForRow(row - 1), @openScopesForRow(row))
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
      @emitter.emit 'did-change', event

    if @firstInvalidRow()?
      @tokenizeInBackground()
    else
      @markTokenizationComplete()

  markTokenizationComplete: ->
    unless @fullyTokenized
      @emitter.emit 'did-tokenize'
    @fullyTokenized = true

  firstInvalidRow: ->
    @invalidRows[0]

  validateRow: (row) ->
    @invalidRows.shift() while @invalidRows[0] <= row
    return

  invalidateRow: (row) ->
    return if @largeFileMode

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
    @changeCount = @buffer.changeCount

    {oldRange, newRange} = e
    start = oldRange.start.row
    end = oldRange.end.row
    delta = newRange.end.row - oldRange.end.row

    @updateInvalidRows(start, end, delta)
    previousEndStack = @stackForRow(end) # used in spill detection below
    if @largeFileMode
      newTokenizedLines = @buildPlaceholderTokenizedLinesForRows(start, end + delta)
    else
      newTokenizedLines = @buildTokenizedLinesForRows(start, end + delta, @stackForRow(start - 1), @openScopesForRow(start))
    _.spliceWithArray(@tokenizedLines, start, end - start + 1, newTokenizedLines)

    start = @retokenizeWhitespaceRowsIfIndentLevelChanged(start - 1, -1)
    end = @retokenizeWhitespaceRowsIfIndentLevelChanged(newRange.end.row + 1, 1) - delta

    newEndStack = @stackForRow(end + delta)
    if newEndStack and not _.isEqual(newEndStack, previousEndStack)
      @invalidateRow(end + delta + 1)

    [start, end] = @updateFoldableStatus(start, end + delta)
    end -= delta

    event = {start, end, delta, bufferChange: e}
    @emitter.emit 'did-change', event

  retokenizeWhitespaceRowsIfIndentLevelChanged: (row, increment) ->
    line = @tokenizedLineForRow(row)
    if line?.isOnlyWhitespace() and @indentLevelForRow(row) isnt line.indentLevel
      while line?.isOnlyWhitespace()
        @tokenizedLines[row] = @buildTokenizedLineForRow(row, @stackForRow(row - 1), @openScopesForRow(row))
        row += increment
        line = @tokenizedLineForRow(row)

    row - increment

  updateFoldableStatus: (startRow, endRow) ->
    return [startRow, endRow] if @largeFileMode

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
    if @largeFileMode
      false
    else
      @isFoldableCodeAtRow(row) or @isFoldableCommentAtRow(row)

  # Returns a {Boolean} indicating whether the given buffer row starts
  # a a foldable row range due to the code's indentation patterns.
  isFoldableCodeAtRow: (row) ->
    # Investigating an exception that's occurring here due to the line being
    # undefined. This should paper over the problem but we want to figure out
    # what is happening:
    tokenizedLine = @tokenizedLineForRow(row)
    @assert tokenizedLine?, "TokenizedLine is undefined", (error) =>
      error.metadata = {
        row: row
        rowCount: @tokenizedLines.length
        tokenizedBufferChangeCount: @changeCount
        bufferChangeCount: @buffer.changeCount
      }

    return false unless tokenizedLine?

    return false if @buffer.isRowBlank(row) or tokenizedLine.isComment()
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

  buildTokenizedLinesForRows: (startRow, endRow, startingStack, startingopenScopes) ->
    ruleStack = startingStack
    openScopes = startingopenScopes
    stopTokenizingAt = startRow + @chunkSize
    tokenizedLines = for row in [startRow..endRow]
      if (ruleStack or row is 0) and row < stopTokenizingAt
        tokenizedLine = @buildTokenizedLineForRow(row, ruleStack, openScopes)
        ruleStack = tokenizedLine.ruleStack
        openScopes = @scopesFromTags(openScopes, tokenizedLine.tags)
      else
        tokenizedLine = @buildPlaceholderTokenizedLineForRow(row, openScopes)
      tokenizedLine

    if endRow >= stopTokenizingAt
      @invalidateRow(stopTokenizingAt)
      @tokenizeInBackground()

    tokenizedLines

  buildPlaceholderTokenizedLinesForRows: (startRow, endRow) ->
    @buildPlaceholderTokenizedLineForRow(row) for row in [startRow..endRow] by 1

  buildPlaceholderTokenizedLineForRow: (row) ->
    openScopes = [@grammar.startIdForScope(@grammar.scopeName)]
    text = @buffer.lineForRow(row)
    tags = [text.length]
    tabLength = @getTabLength()
    indentLevel = @indentLevelForRow(row)
    lineEnding = @buffer.lineEndingForRow(row)
    new TokenizedLine({openScopes, text, tags, tabLength, indentLevel, invisibles: @getInvisiblesToShow(), lineEnding, @tokenIterator})

  buildTokenizedLineForRow: (row, ruleStack, openScopes) ->
    @buildTokenizedLineForRowWithText(row, @buffer.lineForRow(row), ruleStack, openScopes)

  buildTokenizedLineForRowWithText: (row, text, ruleStack = @stackForRow(row - 1), openScopes = @openScopesForRow(row)) ->
    lineEnding = @buffer.lineEndingForRow(row)
    tabLength = @getTabLength()
    indentLevel = @indentLevelForRow(row)
    {tags, ruleStack} = @grammar.tokenizeLine(text, ruleStack, row is 0, false)
    new TokenizedLine({openScopes, text, tags, ruleStack, tabLength, lineEnding, indentLevel, invisibles: @getInvisiblesToShow(), @tokenIterator})

  getInvisiblesToShow: ->
    if @configSettings.showInvisibles and not @ignoreInvisibles
      @configSettings.invisibles
    else
      null

  tokenizedLineForRow: (bufferRow) ->
    if 0 <= bufferRow < @tokenizedLines.length
      @tokenizedLines[bufferRow] ?= @buildPlaceholderTokenizedLineForRow(bufferRow)

  tokenizedLinesForRows: (startRow, endRow) ->
    for row in [startRow..endRow] by 1
      @tokenizedLineForRow(row)

  stackForRow: (bufferRow) ->
    @tokenizedLines[bufferRow]?.ruleStack

  openScopesForRow: (bufferRow) ->
    if bufferRow > 0
      precedingLine = @tokenizedLineForRow(bufferRow - 1)
      @scopesFromTags(precedingLine.openScopes, precedingLine.tags)
    else
      []

  scopesFromTags: (startingScopes, tags) ->
    scopes = startingScopes.slice()
    for tag in tags when tag < 0
      if (tag % 2) is -1
        scopes.push(tag)
      else
        matchingStartTag = tag + 1
        loop
          break if scopes.pop() is matchingStartTag
          if scopes.length is 0
            @assert false, "Encountered an unmatched scope end tag.", (error) =>
              error.metadata = {
                grammarScopeName: @grammar.scopeName
                unmatchedEndTag: @grammar.scopeForId(tag)
              }
              path = require 'path'
              error.privateMetadataDescription = "The contents of `#{path.basename(@buffer.getPath())}`"
              error.privateMetadata = {
                filePath: @buffer.getPath()
                fileContents: @buffer.getText()
              }
    scopes

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
      indentLength = 0
      for character in match[0]
        if character is '\t'
          indentLength += @getTabLength() - (indentLength % @getTabLength())
        else
          indentLength++

      indentLength / @getTabLength()
    else
      0

  scopeDescriptorForPosition: (position) ->
    {row, column} = @buffer.clipPosition(Point.fromObject(position))

    iterator = @tokenizedLineForRow(row).getTokenIterator()
    while iterator.next()
      if iterator.getBufferEnd() > column
        scopes = iterator.getScopes()
        break

    # rebuild scope of last token if we iterated off the end
    unless scopes?
      scopes = iterator.getScopes()
      scopes.push(iterator.getScopeEnds().reverse()...)

    new ScopeDescriptor({scopes})

  tokenForPosition: (position) ->
    {row, column} = Point.fromObject(position)
    @tokenizedLineForRow(row).tokenAtBufferColumn(column)

  tokenStartPositionForPosition: (position) ->
    {row, column} = Point.fromObject(position)
    column = @tokenizedLineForRow(row).tokenStartColumnForBufferColumn(column)
    new Point(row, column)

  bufferRangeForScopeAtPosition: (selector, position) ->
    position = Point.fromObject(position)

    {openScopes, tags} = @tokenizedLineForRow(position.row)
    scopes = openScopes.map (tag) => @grammarRegistry.scopeForId(tag)

    startColumn = 0
    for tag, tokenIndex in tags
      if tag < 0
        if tag % 2 is -1
          scopes.push(@grammarRegistry.scopeForId(tag))
        else
          scopes.pop()
      else
        endColumn = startColumn + tag
        if endColumn >= position.column
          break
        else
          startColumn = endColumn


    return unless selectorMatchesAnyScope(selector, scopes)

    startScopes = scopes.slice()
    for startTokenIndex in [(tokenIndex - 1)..0] by -1
      tag = tags[startTokenIndex]
      if tag < 0
        if tag % 2 is -1
          startScopes.pop()
        else
          startScopes.push(@grammarRegistry.scopeForId(tag))
      else
        break unless selectorMatchesAnyScope(selector, startScopes)
        startColumn -= tag

    endScopes = scopes.slice()
    for endTokenIndex in [(tokenIndex + 1)...tags.length] by 1
      tag = tags[endTokenIndex]
      if tag < 0
        if tag % 2 is -1
          endScopes.push(@grammarRegistry.scopeForId(tag))
        else
          endScopes.pop()
      else
        break unless selectorMatchesAnyScope(selector, endScopes)
        endColumn += tag

    new Range(new Point(position.row, startColumn), new Point(position.row, endColumn))

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

selectorMatchesAnyScope = (selector, scopes) ->
  targetClasses = selector.replace(/^\./, '').split('.')
  _.any scopes, (scope) ->
    scopeClasses = scope.split('.')
    _.isSubset(targetClasses, scopeClasses)
