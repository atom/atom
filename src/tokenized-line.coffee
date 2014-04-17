_ = require 'underscore-plus'

idCounter = 1

module.exports =
class TokenizedLine
  constructor: ({tokens, @lineEnding, @ruleStack, @startBufferColumn, @fold, tabLength}) ->
    @tokens = @breakOutAtomicTokens(tokens, tabLength)
    @startBufferColumn ?= 0
    @text = _.pluck(@tokens, 'value').join('')
    @bufferDelta = _.sum(_.pluck(@tokens, 'bufferDelta'))
    @id = idCounter++

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
      lineEnding: null
    )
    rightFragment = new TokenizedLine(
      tokens: rightTokens
      startBufferColumn: @bufferColumnForScreenColumn(column)
      ruleStack: @ruleStack
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

  breakOutAtomicTokens: (inputTokens, tabLength) ->
    outputTokens = []
    breakOutLeadingWhitespace = true
    for token in inputTokens
      outputTokens.push(token.breakOutAtomicTokens(tabLength, breakOutLeadingWhitespace)...)
      breakOutLeadingWhitespace = token.isOnlyWhitespace() if breakOutLeadingWhitespace
    outputTokens

  isComment: ->
    for token in @tokens
      continue if token.scopes.length is 1
      continue if token.isOnlyWhitespace()
      for scope in token.scopes
        return true if _.contains(scope.split('.'), 'comment')
      break
    false

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
    @scopeTree ?= new ScopeTree(@tokens)

class ScopeTree
  constructor: (@tokens, @scope, @depth=0) ->
    @scope ?= @tokens[0].scopes[@depth]
    @children = []
    childDepth = @depth + 1
    currentChildScope = null
    currentChildTokens = []

    for token in @tokens
      tokenScope = token.scopes[childDepth]

      if tokenScope is currentChildScope
        currentChildTokens.push(token)
      else
        if currentChildScope?
          @children.push(new ScopeTree(currentChildTokens, currentChildScope, childDepth))
          currentChildScope = null
          currentChildTokens = []

        if tokenScope?
          currentChildScope = tokenScope
          currentChildTokens.push(token)
        else
          @children.push(token)

    if currentChildScope?
      @children.push(new ScopeTree(currentChildTokens, currentChildScope, childDepth))
