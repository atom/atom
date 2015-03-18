_ = require 'underscore-plus'
{isPairedCharacter} = require './text-utils'

NonWhitespaceRegex = /\S/
LeadingWhitespaceRegex = /^\s*/
TrailingWhitespaceRegex = /\s*$/
RepeatedSpaceRegex = /[ ]/g
idCounter = 1

module.exports =
class TokenizedLine
  endOfLineInvisibles: null
  lineIsWhitespaceOnly: false
  foldable: false

  constructor: ({tokens, @lineEnding, @ruleStack, @startBufferColumn, @fold, @tabLength, @indentLevel, @invisibles}) ->
    @startBufferColumn ?= 0
    @tokens = @breakOutAtomicTokens(tokens)
    @text = @buildText()
    @bufferDelta = @buildBufferDelta()
    @softWrapIndentationTokens = @getSoftWrapIndentationTokens()
    @softWrapIndentationDelta = @buildSoftWrapIndentationDelta()

    @id = idCounter++
    @markLeadingAndTrailingWhitespaceTokens()
    if @invisibles
      @substituteInvisibleCharacters()
      @buildEndOfLineInvisibles() if @lineEnding?

  buildText: ->
    text = ""
    text += token.value for token in @tokens
    text

  buildBufferDelta: ->
    delta = 0
    delta += token.bufferDelta for token in @tokens
    delta

  copy: ->
    new TokenizedLine({@tokens, @lineEnding, @ruleStack, @startBufferColumn, @fold})

  clipScreenColumn: (column, options={}) ->
    return 0 if @tokens.length == 0

    { skipAtomicTokens } = options
    column = Math.min(column, @getMaxScreenColumn())

    tokenStartColumn = 0
    for token in @tokens
      break if tokenStartColumn + token.screenDelta > column
      tokenStartColumn += token.screenDelta

    if @isColumnInsideSoftWrapIndentation(tokenStartColumn)
      @softWrapIndentationDelta
    else if token.isAtomic and tokenStartColumn < column
      if skipAtomicTokens
        tokenStartColumn + token.screenDelta
      else
        tokenStartColumn
    else
      column

  screenColumnForBufferColumn: (bufferColumn, options) ->
    bufferColumn = bufferColumn - @startBufferColumn
    screenColumn = 0
    currentBufferColumn = 0
    for token in @tokens
      break if currentBufferColumn > bufferColumn
      screenColumn += token.screenDelta
      currentBufferColumn += token.bufferDelta
    @clipScreenColumn(screenColumn + (bufferColumn - currentBufferColumn))

  bufferColumnForScreenColumn: (screenColumn, options) ->
    bufferColumn = @startBufferColumn
    currentScreenColumn = 0
    for token in @tokens
      break if currentScreenColumn + token.screenDelta > screenColumn
      bufferColumn += token.bufferDelta
      currentScreenColumn += token.screenDelta
    bufferColumn + (screenColumn - currentScreenColumn)

  getMaxScreenColumn: ->
    if @fold
      0
    else
      @text.length

  getMaxBufferColumn: ->
    @startBufferColumn + @bufferDelta

  # Given a boundary column, finds the point where this line would wrap.
  #
  # maxColumn - The {Number} where you want soft wrapping to occur
  #
  # Returns a {Number} representing the `line` position where the wrap would take place.
  # Returns `null` if a wrap wouldn't occur.
  findWrapColumn: (maxColumn) ->
    return unless @text.length > maxColumn

    if /\s/.test(@text[maxColumn])
       # search forward for the start of a word past the boundary
      for column in [maxColumn..@text.length]
        return column if /\S/.test(@text[column])

      return @text.length
    else
      # search backward for the start of the word on the boundary
      for column in [maxColumn..0] when @isColumnOutsideSoftWrapIndentation(column)
        return column + 1 if /\s/.test(@text[column])

      return maxColumn

  buildSoftWrapIndentationTokens: (token, hangingIndent) ->
    totalIndentSpaces = (@indentLevel * @tabLength) + hangingIndent
    indentTokens = []
    while totalIndentSpaces > 0
      tokenLength = Math.min(@tabLength, totalIndentSpaces)
      indentToken = token.buildSoftWrapIndentationToken(tokenLength)
      indentTokens.push(indentToken)
      totalIndentSpaces -= tokenLength

    indentTokens

  softWrapAt: (column, hangingIndent) ->
    return [new TokenizedLine([], '', [0, 0], [0, 0]), this] if column == 0

    rightTokens = new Array(@tokens...)
    leftTokens = []
    leftTextLength = 0
    while leftTextLength < column
      if leftTextLength + rightTokens[0].value.length > column
        rightTokens[0..0] = rightTokens[0].splitAt(column - leftTextLength)
      nextToken = rightTokens.shift()
      leftTextLength += nextToken.value.length
      leftTokens.push nextToken

    indentationTokens = @buildSoftWrapIndentationTokens(leftTokens[0], hangingIndent)

    leftFragment = new TokenizedLine(
      tokens: leftTokens
      startBufferColumn: @startBufferColumn
      ruleStack: @ruleStack
      invisibles: @invisibles
      lineEnding: null,
      indentLevel: @indentLevel,
      tabLength: @tabLength
    )
    rightFragment = new TokenizedLine(
      tokens: indentationTokens.concat(rightTokens)
      startBufferColumn: @bufferColumnForScreenColumn(column)
      ruleStack: @ruleStack
      invisibles: @invisibles
      lineEnding: @lineEnding,
      indentLevel: @indentLevel,
      tabLength: @tabLength
    )
    [leftFragment, rightFragment]

  isSoftWrapped: ->
    @lineEnding is null

  isColumnOutsideSoftWrapIndentation: (column) ->
    return true if @softWrapIndentationTokens.length == 0

    column > @softWrapIndentationDelta

  isColumnInsideSoftWrapIndentation: (column) ->
    return false if @softWrapIndentationTokens.length == 0

    column < @softWrapIndentationDelta

  getSoftWrapIndentationTokens: ->
    _.select(@tokens, (token) -> token.isSoftWrapIndentation)

  buildSoftWrapIndentationDelta: ->
    _.reduce @softWrapIndentationTokens, ((acc, token) -> acc + token.screenDelta), 0

  hasOnlySoftWrapIndentation: ->
    @tokens.length == @softWrapIndentationTokens.length

  tokenAtBufferColumn: (bufferColumn) ->
    @tokens[@tokenIndexAtBufferColumn(bufferColumn)]

  tokenIndexAtBufferColumn: (bufferColumn) ->
    delta = 0
    for token, index in @tokens
      delta += token.bufferDelta
      return index if delta > bufferColumn
    index - 1

  tokenStartColumnForBufferColumn: (bufferColumn) ->
    delta = 0
    for token in @tokens
      nextDelta = delta + token.bufferDelta
      break if nextDelta > bufferColumn
      delta = nextDelta
    delta

  breakOutAtomicTokens: (inputTokens) ->
    outputTokens = []
    breakOutLeadingSoftTabs = true
    column = @startBufferColumn
    for token in inputTokens
      newTokens = token.breakOutAtomicTokens(@tabLength, breakOutLeadingSoftTabs, column)
      column += newToken.value.length for newToken in newTokens
      outputTokens.push(newTokens...)
      breakOutLeadingSoftTabs = token.isOnlyWhitespace() if breakOutLeadingSoftTabs
    outputTokens

  markLeadingAndTrailingWhitespaceTokens: ->
    firstNonWhitespaceIndex = @text.search(NonWhitespaceRegex)
    if firstNonWhitespaceIndex > 0 and isPairedCharacter(@text, firstNonWhitespaceIndex - 1)
      firstNonWhitespaceIndex--
    firstTrailingWhitespaceIndex = @text.search(TrailingWhitespaceRegex)
    @lineIsWhitespaceOnly = firstTrailingWhitespaceIndex is 0
    index = 0
    for token in @tokens
      if index < firstNonWhitespaceIndex
        token.firstNonWhitespaceIndex = Math.min(index + token.value.length, firstNonWhitespaceIndex - index)
      # Only the *last* segment of a soft-wrapped line can have trailing whitespace
      if @lineEnding? and (index + token.value.length > firstTrailingWhitespaceIndex)
        token.firstTrailingWhitespaceIndex = Math.max(0, firstTrailingWhitespaceIndex - index)
      index += token.value.length
    return

  substituteInvisibleCharacters: ->
    invisibles = @invisibles
    changedText = false

    for token, i in @tokens
      if token.isHardTab
        if invisibles.tab
          token.value = invisibles.tab + token.value.substring(invisibles.tab.length)
          token.hasInvisibleCharacters = true
          changedText = true
      else
        if invisibles.space
          if token.hasLeadingWhitespace() and not token.isSoftWrapIndentation
            token.value = token.value.replace LeadingWhitespaceRegex, (leadingWhitespace) ->
              leadingWhitespace.replace RepeatedSpaceRegex, invisibles.space
            token.hasInvisibleCharacters = true
            changedText = true
          if token.hasTrailingWhitespace()
            token.value = token.value.replace TrailingWhitespaceRegex, (leadingWhitespace) ->
              leadingWhitespace.replace RepeatedSpaceRegex, invisibles.space
            token.hasInvisibleCharacters = true
            changedText = true

    @text = @buildText() if changedText

  buildEndOfLineInvisibles: ->
    @endOfLineInvisibles = []
    {cr, eol} = @invisibles

    switch @lineEnding
      when '\r\n'
        @endOfLineInvisibles.push(cr) if cr
        @endOfLineInvisibles.push(eol) if eol
      when '\n'
        @endOfLineInvisibles.push(eol) if eol

  isComment: ->
    for token in @tokens
      continue if token.scopes.length is 1
      continue if token.isOnlyWhitespace()
      for scope in token.scopes
        return true if _.contains(scope.split('.'), 'comment')
      break
    false

  isOnlyWhitespace: ->
    @lineIsWhitespaceOnly

  tokenAtIndex: (index) ->
    @tokens[index]

  getTokenCount: ->
    @tokens.length

  bufferColumnForToken: (targetToken) ->
    column = 0
    for token in @tokens
      return column if token is targetToken
      column += token.bufferDelta

  getScopeTree: ->
    return @scopeTree if @scopeTree?

    scopeStack = []
    for token in @tokens
      @updateScopeStack(scopeStack, token.scopes)
      _.last(scopeStack).children.push(token)

    @scopeTree = scopeStack[0]
    @updateScopeStack(scopeStack, [])
    @scopeTree

  updateScopeStack: (scopeStack, desiredScopeDescriptor) ->
    # Find a common prefix
    for scope, i in desiredScopeDescriptor
      break unless scopeStack[i]?.scope is desiredScopeDescriptor[i]

    # Pop scopeDescriptor until we're at the common prefx
    until scopeStack.length is i
      poppedScope = scopeStack.pop()
      _.last(scopeStack)?.children.push(poppedScope)

    # Push onto common prefix until scopeStack equals desiredScopeDescriptor
    for j in [i...desiredScopeDescriptor.length]
      scopeStack.push(new Scope(desiredScopeDescriptor[j]))

    return

class Scope
  constructor: (@scope) ->
    @children = []
