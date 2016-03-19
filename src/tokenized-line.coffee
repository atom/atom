_ = require 'underscore-plus'
{isPairedCharacter, isCJKCharacter} = require './text-utils'
Token = require './token'
{SoftTab, HardTab, PairedCharacter, SoftWrapIndent} = require './special-token-symbols'

NonWhitespaceRegex = /\S/
LeadingWhitespaceRegex = /^\s*/
TrailingWhitespaceRegex = /\s*$/
RepeatedSpaceRegex = /[ ]/g
CommentScopeRegex = /(\b|\.)comment/
TabCharCode = 9
SpaceCharCode = 32
SpaceString = ' '
TabStringsByLength = {
  1: ' '
  2: '  '
  3: '   '
  4: '    '
}

idCounter = 1

module.exports =
class TokenizedLine
  endOfLineInvisibles: null
  lineIsWhitespaceOnly: false
  firstNonWhitespaceIndex: 0

  constructor: (properties) ->
    @id = idCounter++

    return unless properties?

    @specialTokens = {}
    {@openScopes, @text, @tags, @lineEnding, @ruleStack, @tokenIterator} = properties
    {@startBufferColumn, @fold, @tabLength, @invisibles} = properties

    @startBufferColumn ?= 0
    @bufferDelta = @text.length

  getTokenIterator: -> @tokenIterator.reset(this, arguments...)

  Object.defineProperty @prototype, 'tokens', get: ->
    iterator = @getTokenIterator()
    tokens = []

    while iterator.next()
      properties = {
        value: iterator.getText()
        scopes: iterator.getScopes().slice()
        isAtomic: iterator.isAtomic()
        isHardTab: iterator.isHardTab()
        hasPairedCharacter: iterator.isPairedCharacter()
        isSoftWrapIndentation: iterator.isSoftWrapIndentation()
      }

      if iterator.isHardTab()
        properties.bufferDelta = 1
        properties.hasInvisibleCharacters = true if @invisibles?.tab

      if iterator.getScreenStart() < @firstNonWhitespaceIndex
        properties.firstNonWhitespaceIndex =
          Math.min(@firstNonWhitespaceIndex, iterator.getScreenEnd()) - iterator.getScreenStart()
        properties.hasInvisibleCharacters = true if @invisibles?.space

      if @lineEnding? and iterator.getScreenEnd() > @firstTrailingWhitespaceIndex
        properties.firstTrailingWhitespaceIndex =
          Math.max(0, @firstTrailingWhitespaceIndex - iterator.getScreenStart())
        properties.hasInvisibleCharacters = true if @invisibles?.space

      tokens.push(new Token(properties))

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
