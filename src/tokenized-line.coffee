_ = require 'underscore-plus'

NonWhitespaceRegex = /\S/
LeadingWhitespaceRegex = /^\s*/
TrailingWhitespaceRegex = /\s*$/
RepeatedSpaceRegex = /[ ]/g
idCounter = 1

module.exports =
class TokenizedLine
  endOfLineInvisibles: null

  constructor: ({tokens, @lineEnding, @ruleStack, @startBufferColumn, @fold, @tabLength, @indentLevel, @invisibles}) ->
    @startBufferColumn ?= 0
    @tokens = @breakOutAtomicTokens(tokens)
    @text = @buildText()
    @bufferDelta = @buildBufferDelta()

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

    if token.isAtomic and tokenStartColumn < column
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

  softWrapAt: (column) ->
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

    leftFragment = new TokenizedLine(
      tokens: leftTokens
      startBufferColumn: @startBufferColumn
      ruleStack: @ruleStack
      invisibles: @invisibles
      lineEnding: null
    )
    rightFragment = new TokenizedLine(
      tokens: rightTokens
      startBufferColumn: @bufferColumnForScreenColumn(column)
      ruleStack: @ruleStack
      invisibles: @invisibles
      lineEnding: @lineEnding
    )
    [leftFragment, rightFragment]

  isSoftWrapped: ->
    @lineEnding is null

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
    firstTrailingWhitespaceIndex = @text.search(TrailingWhitespaceRegex)
    lineIsWhitespaceOnly = firstTrailingWhitespaceIndex is 0
    index = 0
    for token in @tokens
      if index < firstNonWhitespaceIndex
        token.firstNonWhitespaceIndex = Math.min(index + token.value.length, firstNonWhitespaceIndex - index)
      # Only the *last* segment of a soft-wrapped line can have trailing whitespace
      if @lineEnding? and (index + token.value.length > firstTrailingWhitespaceIndex)
        token.firstTrailingWhitespaceIndex = Math.max(0, firstTrailingWhitespaceIndex - index)
      index += token.value.length

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
          if token.hasLeadingWhitespace()
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
    if @text == ''
      true
    else
      for token in @tokens
        return false unless token.isOnlyWhitespace()
      true

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

class Scope
  constructor: (@scope) ->
    @children = []
