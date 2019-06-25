Token = require './token'
CommentScopeRegex = /(\b|\.)comment/

idCounter = 1

module.exports =
class TokenizedLine
  constructor: (properties) ->
    @id = idCounter++

    return unless properties?

    {@openScopes, @text, @tags, @ruleStack, @tokenIterator, @grammar, tokens} = properties
    @cachedTokens = tokens

  getTokenIterator: -> @tokenIterator.reset(this)

  Object.defineProperty @prototype, 'tokens', get: ->
    if @cachedTokens
      @cachedTokens
    else
      iterator = @getTokenIterator()
      tokens = []

      while iterator.next()
        tokens.push(new Token({
          value: iterator.getText()
          scopes: iterator.getScopes().slice()
        }))

      tokens

  tokenAtBufferColumn: (bufferColumn) ->
    @tokens[@tokenIndexAtBufferColumn(bufferColumn)]

  tokenIndexAtBufferColumn: (bufferColumn) ->
    column = 0
    for token, index in @tokens
      column += token.value.length
      return index if column > bufferColumn
    index - 1

  tokenStartColumnForBufferColumn: (bufferColumn) ->
    delta = 0
    for token in @tokens
      nextDelta = delta + token.bufferDelta
      break if nextDelta > bufferColumn
      delta = nextDelta
    delta

  isComment: ->
    return @isCommentLine if @isCommentLine?

    @isCommentLine = false

    for tag in @openScopes
      if @isCommentOpenTag(tag)
        @isCommentLine = true
        return @isCommentLine

    startIndex = 0
    for tag in @tags
      # If we haven't encountered any comment scope when reading the first
      # non-whitespace chunk of text, then we consider this as not being a
      # comment line.
      if tag > 0
        break unless isWhitespaceOnly(@text.substr(startIndex, tag))
        startIndex += tag

      if @isCommentOpenTag(tag)
        @isCommentLine = true
        return @isCommentLine

    @isCommentLine

  isCommentOpenTag: (tag) ->
    if tag < 0 and (tag & 1) is 1
      scope = @grammar.scopeForId(tag)
      if CommentScopeRegex.test(scope)
        return true
    false

  tokenAtIndex: (index) ->
    @tokens[index]

  getTokenCount: ->
    count = 0
    count++ for tag in @tags when tag >= 0
    count

isWhitespaceOnly = (text) ->
  for char in text
    if char isnt '\t' and char isnt ' '
      return false
  return true
