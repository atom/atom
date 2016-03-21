_ = require 'underscore-plus'
{isPairedCharacter, isCJKCharacter} = require './text-utils'
Token = require './token'
CommentScopeRegex = /(\b|\.)comment/

idCounter = 1

module.exports =
class TokenizedLine
  endOfLineInvisibles: null
  lineIsWhitespaceOnly: false
  firstNonWhitespaceIndex: 0

  constructor: (properties) ->
    @id = idCounter++

    return unless properties?

    {@openScopes, @text, @tags, @lineEnding, @ruleStack, @tokenIterator} = properties
    {@startBufferColumn, @fold, @tabLength, @invisibles} = properties

    @startBufferColumn ?= 0
    @bufferDelta = @text.length

  getTokenIterator: -> @tokenIterator.reset(this, arguments...)

  Object.defineProperty @prototype, 'tokens', get: ->
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

  isComment: ->
    return @isCommentLine if @isCommentLine?

    @isCommentLine = false
    iterator = @getTokenIterator()
    while iterator.next()
      scopes = iterator.getScopes()
      continue if scopes.length is 1
      for scope in scopes
        if CommentScopeRegex.test(scope)
          @isCommentLine = true
          break
      break
    @isCommentLine

  isOnlyWhitespace: ->
    @lineIsWhitespaceOnly

  tokenAtIndex: (index) ->
    @tokens[index]

  getTokenCount: ->
    count = 0
    count++ for tag in @tags when tag >= 0
    count
