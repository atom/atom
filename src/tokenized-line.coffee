_ = require 'underscore-plus'
{isPairedCharacter} = require './text-utils'
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
  foldable: false

  constructor: (properties) ->
    @id = idCounter++

    return unless properties?

    @specialTokens = {}
    {@openScopes, @text, @tags, @lineEnding, @ruleStack, @tokenIterator} = properties
    {@startBufferColumn, @fold, @tabLength, @indentLevel, @invisibles} = properties

    @startBufferColumn ?= 0
    @bufferDelta = @text.length

    @transformContent()
    @buildEndOfLineInvisibles() if @invisibles? and @lineEnding?

  transformContent: ->
    text = ''
    bufferColumn = 0
    screenColumn = 0
    tokenIndex = 0
    tokenOffset = 0
    firstNonWhitespaceColumn = null
    lastNonWhitespaceColumn = null

    substringStart = 0
    substringEnd = 0

    while bufferColumn < @text.length
      # advance to next token if we've iterated over its length
      if tokenOffset is @tags[tokenIndex]
        tokenIndex++
        tokenOffset = 0

      # advance to next token tag
      tokenIndex++ while @tags[tokenIndex] < 0

      charCode = @text.charCodeAt(bufferColumn)

      # split out unicode surrogate pairs
      if isPairedCharacter(@text, bufferColumn)
        prefix = tokenOffset
        suffix = @tags[tokenIndex] - tokenOffset - 2

        i = tokenIndex
        @tags.splice(i, 1)
        @tags.splice(i++, 0, prefix) if prefix > 0
        @tags.splice(i++, 0, 2)
        @tags.splice(i, 0, suffix) if suffix > 0

        firstNonWhitespaceColumn ?= screenColumn
        lastNonWhitespaceColumn = screenColumn + 1

        substringEnd += 2
        screenColumn += 2
        bufferColumn += 2

        tokenIndex++ if prefix > 0
        @specialTokens[tokenIndex] = PairedCharacter
        tokenIndex++
        tokenOffset = 0

      # split out leading soft tabs
      else if charCode is SpaceCharCode
        if firstNonWhitespaceColumn?
          substringEnd += 1
        else
          if (screenColumn + 1) % @tabLength is 0
            suffix = @tags[tokenIndex] - @tabLength
            if suffix >= 0
              @specialTokens[tokenIndex] = SoftTab
              @tags.splice(tokenIndex, 1, @tabLength)
              @tags.splice(tokenIndex + 1, 0, suffix) if suffix > 0

          if @invisibles?.space
            if substringEnd > substringStart
              text += @text.substring(substringStart, substringEnd)
            substringStart = substringEnd
            text += @invisibles.space
            substringStart += 1

          substringEnd += 1

        screenColumn++
        bufferColumn++
        tokenOffset++

      # expand hard tabs to the next tab stop
      else if charCode is TabCharCode
        if substringEnd > substringStart
          text += @text.substring(substringStart, substringEnd)
        substringStart = substringEnd

        tabLength = @tabLength - (screenColumn % @tabLength)
        if @invisibles?.tab
          text += @invisibles.tab
          text += getTabString(tabLength - 1) if tabLength > 1
        else
          text += getTabString(tabLength)

        substringStart += 1
        substringEnd += 1

        prefix = tokenOffset
        suffix = @tags[tokenIndex] - tokenOffset - 1

        i = tokenIndex
        @tags.splice(i, 1)
        @tags.splice(i++, 0, prefix) if prefix > 0
        @tags.splice(i++, 0, tabLength)
        @tags.splice(i, 0, suffix) if suffix > 0

        screenColumn += tabLength
        bufferColumn++

        tokenIndex++ if prefix > 0
        @specialTokens[tokenIndex] = HardTab
        tokenIndex++
        tokenOffset = 0

      # continue past any other character
      else
        firstNonWhitespaceColumn ?= screenColumn
        lastNonWhitespaceColumn = screenColumn

        substringEnd += 1
        screenColumn++
        bufferColumn++
        tokenOffset++

    if substringEnd > substringStart
      unless substringStart is 0 and substringEnd is @text.length
        text += @text.substring(substringStart, substringEnd)
        @text = text
    else
      @text = text

    @firstNonWhitespaceIndex = firstNonWhitespaceColumn
    if lastNonWhitespaceColumn?
      if lastNonWhitespaceColumn + 1 < @text.length
        @firstTrailingWhitespaceIndex = lastNonWhitespaceColumn + 1
        if @invisibles?.space
          @text =
            @text.substring(0, @firstTrailingWhitespaceIndex) +
              @text.substring(@firstTrailingWhitespaceIndex)
                .replace(RepeatedSpaceRegex, @invisibles.space)
    else
      @lineIsWhitespaceOnly = true
      @firstTrailingWhitespaceIndex = 0

  getTokenIterator: -> @tokenIterator.reset(this)

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
    copy.indentLevel = @indentLevel
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

  # Given a boundary column, finds the point where this line would wrap.
  #
  # maxColumn - The {Number} where you want soft wrapping to occur
  #
  # Returns a {Number} representing the `line` position where the wrap would take place.
  # Returns `null` if a wrap wouldn't occur.
  findWrapColumn: (maxColumn) ->
    return unless maxColumn?
    return unless @text.length > maxColumn

    if /\s/.test(@text[maxColumn])
       # search forward for the start of a word past the boundary
      for column in [maxColumn..@text.length]
        return column if /\S/.test(@text[column])

      return @text.length
    else
      # search backward for the start of the word on the boundary
      for column in [maxColumn..@firstNonWhitespaceIndex]
        return column + 1 if /\s/.test(@text[column])

      return maxColumn

  softWrapAt: (column, hangingIndent) ->
    return [null, this] if column is 0

    leftText = @text.substring(0, column)
    rightText = @text.substring(column)

    leftTags = []
    rightTags = []

    leftSpecialTokens = {}
    rightSpecialTokens = {}

    rightOpenScopes = @openScopes.slice()

    screenColumn = 0

    for tag, index in @tags
      # tag represents a token
      if tag >= 0
        # token ends before the soft wrap column
        if screenColumn + tag <= column
          if specialToken = @specialTokens[index]
            leftSpecialTokens[index] = specialToken
          leftTags.push(tag)
          screenColumn += tag

        # token starts before and ends after the split column
        else if screenColumn <= column
          leftSuffix = column - screenColumn
          rightPrefix = screenColumn + tag - column

          leftTags.push(leftSuffix) if leftSuffix > 0

          softWrapIndent = @indentLevel * @tabLength + (hangingIndent ? 0)
          for i in [0...softWrapIndent] by 1
            rightText = ' ' + rightText
          remainingSoftWrapIndent = softWrapIndent
          while remainingSoftWrapIndent > 0
            indentToken = Math.min(remainingSoftWrapIndent, @tabLength)
            rightSpecialTokens[rightTags.length] = SoftWrapIndent
            rightTags.push(indentToken)
            remainingSoftWrapIndent -= indentToken

          rightTags.push(rightPrefix) if rightPrefix > 0

          screenColumn += tag

         # token is after split column
        else
          if specialToken = @specialTokens[index]
            rightSpecialTokens[rightTags.length] = specialToken
          rightTags.push(tag)

      # tag represents the start or end of a scop
      else if (tag % 2) is -1
        if screenColumn < column
          leftTags.push(tag)
          rightOpenScopes.push(tag)
        else
          rightTags.push(tag)
      else
        if screenColumn < column
          leftTags.push(tag)
          rightOpenScopes.pop()
        else
          rightTags.push(tag)

    splitBufferColumn = @bufferColumnForScreenColumn(column)

    leftFragment = new TokenizedLine
    leftFragment.tokenIterator = @tokenIterator
    leftFragment.openScopes = @openScopes
    leftFragment.text = leftText
    leftFragment.tags = leftTags
    leftFragment.specialTokens = leftSpecialTokens
    leftFragment.startBufferColumn = @startBufferColumn
    leftFragment.bufferDelta = splitBufferColumn - @startBufferColumn
    leftFragment.ruleStack = @ruleStack
    leftFragment.invisibles = @invisibles
    leftFragment.lineEnding = null
    leftFragment.indentLevel = @indentLevel
    leftFragment.tabLength = @tabLength
    leftFragment.firstNonWhitespaceIndex = Math.min(column, @firstNonWhitespaceIndex)
    leftFragment.firstTrailingWhitespaceIndex = Math.min(column, @firstTrailingWhitespaceIndex)

    rightFragment = new TokenizedLine
    rightFragment.tokenIterator = @tokenIterator
    rightFragment.openScopes = rightOpenScopes
    rightFragment.text = rightText
    rightFragment.tags = rightTags
    rightFragment.specialTokens = rightSpecialTokens
    rightFragment.startBufferColumn = splitBufferColumn
    rightFragment.bufferDelta = @startBufferColumn + @bufferDelta - splitBufferColumn
    rightFragment.ruleStack = @ruleStack
    rightFragment.invisibles = @invisibles
    rightFragment.lineEnding = @lineEnding
    rightFragment.indentLevel = @indentLevel
    rightFragment.tabLength = @tabLength
    rightFragment.endOfLineInvisibles = @endOfLineInvisibles
    rightFragment.firstNonWhitespaceIndex = Math.max(softWrapIndent, @firstNonWhitespaceIndex - column + softWrapIndent)
    rightFragment.firstTrailingWhitespaceIndex = Math.max(softWrapIndent, @firstTrailingWhitespaceIndex - column + softWrapIndent)

    [leftFragment, rightFragment]

  isSoftWrapped: ->
    @lineEnding is null

  isColumnInsideSoftWrapIndentation: (targetColumn) ->
    targetColumn < @getSoftWrapIndentationDelta()

  getSoftWrapIndentationDelta: ->
    delta = 0
    for tag, index in @tags
      if tag >= 0
        if @specialTokens[index] is SoftWrapIndent
          delta += tag
        else
          break
    delta

  hasOnlySoftWrapIndentation: ->
    @getSoftWrapIndentationDelta() is @text.length

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
    iterator = @getTokenIterator()
    while iterator.next()
      scopes = iterator.getScopes()
      continue if scopes.length is 1
      continue unless NonWhitespaceRegex.test(iterator.getText())
      for scope in scopes
        return true if CommentScopeRegex.test(scope)
      break
    false

  isOnlyWhitespace: ->
    @lineIsWhitespaceOnly

  tokenAtIndex: (index) ->
    @tokens[index]

  getTokenCount: ->
    count = 0
    count++ for tag in @tags when tag >= 0
    count
