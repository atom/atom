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

getTabString = (length) ->
  TabStringsByLength[length] ?= buildTabString(length)

buildTabString = (length) ->
  string = SpaceString
  string += SpaceString for i in [1...length] by 1
  string

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

  copy: ->
    copy = new TokenizedLine
    copy.tokenIterator = @tokenIterator
    copy.openScopes = @openScopes
    copy.text = @text
    copy.tags = @tags
    copy.specialTokens = @specialTokens
    copy.startBufferColumn = @startBufferColumn
    copy.bufferDelta = @bufferDelta
    copy.ruleStack = @ruleStack
    copy.lineEnding = @lineEnding
    copy.invisibles = @invisibles
    copy.endOfLineInvisibles = @endOfLineInvisibles
    copy.tabLength = @tabLength
    copy.firstNonWhitespaceIndex = @firstNonWhitespaceIndex
    copy.firstTrailingWhitespaceIndex = @firstTrailingWhitespaceIndex
    copy.fold = @fold
    copy

  # This clips a given screen column to a valid column that's within the line
  # and not in the middle of any atomic tokens.
  #
  # column - A {Number} representing the column to clip
  # options - A hash with the key clip. Valid values for this key:
  #           'closest' (default): clip to the closest edge of an atomic token.
  #           'forward': clip to the forward edge.
  #           'backward': clip to the backward edge.
  #
  # Returns a {Number} representing the clipped column.
  clipScreenColumn: (column, options={}) ->
    return 0 if @tags.length is 0

    {clip} = options
    column = Math.min(column, @getMaxScreenColumn())

    tokenStartColumn = 0

    iterator = @getTokenIterator()
    while iterator.next()
      break if iterator.getScreenEnd() > column

    if iterator.isSoftWrapIndentation()
      iterator.next() while iterator.isSoftWrapIndentation()
      iterator.getScreenStart()
    else if iterator.isAtomic() and iterator.getScreenStart() < column
      if clip is 'forward'
        iterator.getScreenEnd()
      else if clip is 'backward'
        iterator.getScreenStart()
      else #'closest'
        if column > ((iterator.getScreenStart() + iterator.getScreenEnd()) / 2)
          iterator.getScreenEnd()
        else
          iterator.getScreenStart()
    else
      column

  screenColumnForBufferColumn: (targetBufferColumn, options) ->
    iterator = @getTokenIterator()
    while iterator.next()
      tokenBufferStart = iterator.getBufferStart()
      tokenBufferEnd = iterator.getBufferEnd()
      if tokenBufferStart <= targetBufferColumn < tokenBufferEnd
        overshoot = targetBufferColumn - tokenBufferStart
        return Math.min(
          iterator.getScreenStart() + overshoot,
          iterator.getScreenEnd()
        )
    iterator.getScreenEnd()

  bufferColumnForScreenColumn: (targetScreenColumn) ->
    iterator = @getTokenIterator()
    while iterator.next()
      tokenScreenStart = iterator.getScreenStart()
      tokenScreenEnd = iterator.getScreenEnd()
      if tokenScreenStart <= targetScreenColumn < tokenScreenEnd
        overshoot = targetScreenColumn - tokenScreenStart
        return Math.min(
          iterator.getBufferStart() + overshoot,
          iterator.getBufferEnd()
        )
    iterator.getBufferEnd()

  getMaxScreenColumn: ->
    if @fold
      0
    else
      @text.length

  getMaxBufferColumn: ->
    @startBufferColumn + @bufferDelta

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
