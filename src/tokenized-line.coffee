_ = require 'underscore-plus'
{isPairedCharacter} = require './text-utils'
Token = require './token'
TokenIterator = require './token-iterator'
{SoftTab, HardTab, PairedCharacter, SoftWrapIndent} = require './special-token-symbols'

NonWhitespaceRegex = /\S/
LeadingWhitespaceRegex = /^\s*/
TrailingWhitespaceRegex = /\s*$/
RepeatedSpaceRegex = /[ ]/g
idCounter = 1

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
    {@openScopes, @text, @tags, @lineEnding, @ruleStack} = properties
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

    while bufferColumn < @text.length
      # advance to next token if we've iterated over its length
      if tokenOffset is @tags[tokenIndex]
        tokenIndex++
        tokenOffset = 0

      # advance to next token tag
      tokenIndex++ while @tags[tokenIndex] < 0

      character = @text[bufferColumn]

      # split out unicode surrogate pairs
      if isPairedCharacter(@text, bufferColumn)
        prefix = tokenOffset
        suffix = @tags[tokenIndex] - tokenOffset - 2
        splitTokens = []
        splitTokens.push(prefix) if prefix > 0
        splitTokens.push(2)
        splitTokens.push(suffix) if suffix > 0

        @tags.splice(tokenIndex, 1, splitTokens...)

        firstNonWhitespaceColumn ?= screenColumn
        lastNonWhitespaceColumn = screenColumn + 1

        text += @text.substr(bufferColumn, 2)
        screenColumn += 2
        bufferColumn += 2

        tokenIndex++ if prefix > 0
        @specialTokens[tokenIndex] = PairedCharacter
        tokenIndex++
        tokenOffset = 0

      # split out leading soft tabs
      else if character is ' '
        if firstNonWhitespaceColumn?
          text += ' '
        else
          if (screenColumn + 1) % @tabLength is 0
            @specialTokens[tokenIndex] = SoftTab
            suffix = @tags[tokenIndex] - @tabLength
            @tags.splice(tokenIndex, 1, @tabLength)
            @tags.splice(tokenIndex + 1, 0, suffix) if suffix > 0
          text += @invisibles?.space ? ' '

        screenColumn++
        bufferColumn++
        tokenOffset++

      # expand hard tabs to the next tab stop
      else if character is '\t'
        tabLength = @tabLength - (screenColumn % @tabLength)
        if @invisibles?.tab
          text += @invisibles.tab
        else
          text += ' '
        text += ' ' for i in [1...tabLength] by 1

        prefix = tokenOffset
        suffix = @tags[tokenIndex] - tokenOffset - 1
        splitTokens = []
        splitTokens.push(prefix) if prefix > 0
        splitTokens.push(tabLength)
        splitTokens.push(suffix) if suffix > 0

        @tags.splice(tokenIndex, 1, splitTokens...)

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

        text += character
        screenColumn++
        bufferColumn++
        tokenOffset++

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

  Object.defineProperty @prototype, 'tokens', get: ->
    iterator = TokenIterator.instance.reset(this)
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
    copy.indentLevel = @indentLevel
    copy.openScopes = @openScopes
    copy.text = @text
    copy.tags = @tags
    copy.specialTokens = @specialTokens
    copy.firstNonWhitespaceIndex = @firstNonWhitespaceIndex
    copy.firstTrailingWhitespaceIndex = @firstTrailingWhitespaceIndex
    copy.lineEnding = @lineEnding
    copy.endOfLineInvisibles = @endOfLineInvisibles
    copy.ruleStack = @ruleStack
    copy.startBufferColumn = @startBufferColumn
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
    return 0 if @tokens.length is 0

    {clip} = options
    column = Math.min(column, @getMaxScreenColumn())

    tokenStartColumn = 0
    for token in @tokens
      break if tokenStartColumn + token.screenDelta > column
      tokenStartColumn += token.screenDelta

    if @isColumnInsideSoftWrapIndentation(tokenStartColumn)
      @getSoftWrapIndentationDelta()
    else if token.isAtomic and tokenStartColumn < column
      if clip is 'forward'
        tokenStartColumn + token.screenDelta
      else if clip is 'backward'
        tokenStartColumn
      else #'closest'
        if column > tokenStartColumn + (token.screenDelta / 2)
          tokenStartColumn + token.screenDelta
        else
          tokenStartColumn
    else
      column

  screenColumnForBufferColumn: (targetBufferColumn, options) ->
    bufferColumn = @startBufferColumn
    screenColumn = 0
    for tag, index in @tags
      if tag > 0
        switch @specialTokens[index]
          when HardTab
            bufferDelta = 1
            screenDelta = tag
          when SoftWrapIndent
            bufferDelta = 0
            screenDelta = tag
          else
            bufferDelta = screenDelta = tag

        nextBufferColumn = bufferColumn + bufferDelta
        if nextBufferColumn > targetBufferColumn
          overshoot = targetBufferColumn - bufferColumn
          bufferColumn += overshoot
          screenColumn += Math.min(screenDelta, overshoot)
          break
        else
          bufferColumn = nextBufferColumn
          screenColumn += screenDelta

    screenColumn

  bufferColumnForScreenColumn: (targetScreenColumn) ->
    bufferColumn = @startBufferColumn
    screenColumn = 0
    for tag, index in @tags
      if tag > 0
        switch @specialTokens[index]
          when HardTab
            bufferDelta = 1
            screenDelta = tag
          when SoftWrapIndent
            bufferDelta = 0
            screenDelta = tag
          else
            bufferDelta = screenDelta = tag

        nextScreenColumn = screenColumn + screenDelta
        if nextScreenColumn > targetScreenColumn
          overshoot = targetScreenColumn - screenColumn
          screenColumn += overshoot
          bufferColumn += Math.min(bufferDelta, overshoot)
          break
        else
          screenColumn = nextScreenColumn
          bufferColumn += bufferDelta

    bufferColumn

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
          rightText = ' ' + rightText for i in [0...softWrapIndent] by 1
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
    rightFragment.openScopes = rightOpenScopes
    rightFragment.text = rightText
    rightFragment.tags = rightTags
    rightFragment.specialTokens = rightSpecialTokens
    rightFragment.startBufferColumn = splitBufferColumn
    rightFragment.bufferDelta = @bufferDelta - splitBufferColumn
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
