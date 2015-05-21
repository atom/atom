_ = require 'underscore-plus'
textUtils = require './text-utils'

WhitespaceRegexesByTabLength = {}
EscapeRegex = /[&"'<>]/g
StartDotRegex = /^\.?/
WhitespaceRegex = /\S/

MaxTokenLength = 20000

# Represents a single unit of text as selected by a grammar.
module.exports =
class Token
  value: null
  hasPairedCharacter: false
  scopes: null
  isAtomic: null
  isHardTab: null
  firstNonWhitespaceIndex: null
  firstTrailingWhitespaceIndex: null
  hasInvisibleCharacters: false

  constructor: ({@value, @scopes, @isAtomic, @bufferDelta, @isHardTab, @hasPairedCharacter, @isSoftWrapIndentation}) ->
    @screenDelta = @value.length
    @bufferDelta ?= @screenDelta
    @hasPairedCharacter ?= textUtils.hasPairedCharacter(@value)

  isEqual: (other) ->
    # TODO: scopes is deprecated. This is here for the sake of lang package tests
    @value is other.value and _.isEqual(@scopes, other.scopes) and !!@isAtomic is !!other.isAtomic

  isBracket: ->
    /^meta\.brace\b/.test(_.last(@scopes))

  splitAt: (splitIndex) ->
    leftToken = new Token(value: @value.substring(0, splitIndex), scopes: @scopes)
    rightToken = new Token(value: @value.substring(splitIndex), scopes: @scopes)

    if @firstNonWhitespaceIndex?
      leftToken.firstNonWhitespaceIndex = Math.min(splitIndex, @firstNonWhitespaceIndex)
      leftToken.hasInvisibleCharacters = @hasInvisibleCharacters

      if @firstNonWhitespaceIndex > splitIndex
        rightToken.firstNonWhitespaceIndex = @firstNonWhitespaceIndex - splitIndex
        rightToken.hasInvisibleCharacters = @hasInvisibleCharacters

    if @firstTrailingWhitespaceIndex?
      rightToken.firstTrailingWhitespaceIndex = Math.max(0, @firstTrailingWhitespaceIndex - splitIndex)
      rightToken.hasInvisibleCharacters = @hasInvisibleCharacters

      if @firstTrailingWhitespaceIndex < splitIndex
        leftToken.firstTrailingWhitespaceIndex = @firstTrailingWhitespaceIndex
        leftToken.hasInvisibleCharacters = @hasInvisibleCharacters

    [leftToken, rightToken]

  whitespaceRegexForTabLength: (tabLength) ->
    WhitespaceRegexesByTabLength[tabLength] ?= new RegExp("([ ]{#{tabLength}})|(\t)|([^\t]+)", "g")

  breakOutAtomicTokens: (tabLength, breakOutLeadingSoftTabs, startColumn) ->
    if @hasPairedCharacter
      outputTokens = []
      column = startColumn

      for token in @breakOutPairedCharacters()
        if token.isAtomic
          outputTokens.push(token)
        else
          outputTokens.push(token.breakOutAtomicTokens(tabLength, breakOutLeadingSoftTabs, column)...)
        breakOutLeadingSoftTabs = token.isOnlyWhitespace() if breakOutLeadingSoftTabs
        column += token.value.length

      outputTokens
    else
      return [this] if @isAtomic

      if breakOutLeadingSoftTabs
        return [this] unless /^[ ]|\t/.test(@value)
      else
        return [this] unless /\t/.test(@value)

      outputTokens = []
      regex = @whitespaceRegexForTabLength(tabLength)
      column = startColumn
      while match = regex.exec(@value)
        [fullMatch, softTab, hardTab] = match
        token = null
        if softTab and breakOutLeadingSoftTabs
          token = @buildSoftTabToken(tabLength)
        else if hardTab
          breakOutLeadingSoftTabs = false
          token = @buildHardTabToken(tabLength, column)
        else
          breakOutLeadingSoftTabs = false
          value = match[0]
          token = new Token({value, @scopes})
        column += token.value.length
        outputTokens.push(token)

      outputTokens

  breakOutPairedCharacters: ->
    outputTokens = []
    index = 0
    nonPairStart = 0

    while index < @value.length
      if textUtils.isPairedCharacter(@value, index)
        if nonPairStart isnt index
          outputTokens.push(new Token({value: @value[nonPairStart...index], @scopes}))
        outputTokens.push(@buildPairedCharacterToken(@value, index))
        index += 2
        nonPairStart = index
      else
        index++

    if nonPairStart isnt index
      outputTokens.push(new Token({value: @value[nonPairStart...index], @scopes}))

    outputTokens

  buildPairedCharacterToken: (value, index) ->
    new Token(
      value: value[index..index + 1]
      scopes: @scopes
      isAtomic: true
      hasPairedCharacter: true
    )

  buildHardTabToken: (tabLength, column) ->
    @buildTabToken(tabLength, true, column)

  buildSoftTabToken: (tabLength) ->
    @buildTabToken(tabLength, false, 0)

  buildTabToken: (tabLength, isHardTab, column=0) ->
    tabStop = tabLength - (column % tabLength)
    new Token(
      value: _.multiplyString(" ", tabStop)
      scopes: @scopes
      bufferDelta: if isHardTab then 1 else tabStop
      isAtomic: true
      isHardTab: isHardTab
    )

  buildSoftWrapIndentationToken: (length) ->
    new Token(
      value: _.multiplyString(" ", length),
      scopes: @scopes,
      bufferDelta: 0,
      isAtomic: true,
      isSoftWrapIndentation: true
    )

  isOnlyWhitespace: ->
    not WhitespaceRegex.test(@value)

  matchesScopeSelector: (selector) ->
    targetClasses = selector.replace(StartDotRegex, '').split('.')
    _.any @scopes, (scope) ->
      scopeClasses = scope.split('.')
      _.isSubset(targetClasses, scopeClasses)

  getValueAsHtml: ({hasIndentGuide}) ->
    if @isHardTab
      classes = 'hard-tab'
      classes += ' leading-whitespace' if @hasLeadingWhitespace()
      classes += ' trailing-whitespace' if @hasTrailingWhitespace()
      classes += ' indent-guide' if hasIndentGuide
      classes += ' invisible-character' if @hasInvisibleCharacters
      html = "<span class='#{classes}'>#{@escapeString(@value)}</span>"
    else
      startIndex = 0
      endIndex = @value.length

      leadingHtml = ''
      trailingHtml = ''

      if @hasLeadingWhitespace()
        leadingWhitespace = @value.substring(0, @firstNonWhitespaceIndex)

        classes = 'leading-whitespace'
        classes += ' indent-guide' if hasIndentGuide
        classes += ' invisible-character' if @hasInvisibleCharacters

        leadingHtml = "<span class='#{classes}'>#{leadingWhitespace}</span>"
        startIndex = @firstNonWhitespaceIndex

      if @hasTrailingWhitespace()
        tokenIsOnlyWhitespace = @firstTrailingWhitespaceIndex is 0
        trailingWhitespace = @value.substring(@firstTrailingWhitespaceIndex)

        classes = 'trailing-whitespace'
        classes += ' indent-guide' if hasIndentGuide and not @hasLeadingWhitespace() and tokenIsOnlyWhitespace
        classes += ' invisible-character' if @hasInvisibleCharacters

        trailingHtml = "<span class='#{classes}'>#{trailingWhitespace}</span>"

        endIndex = @firstTrailingWhitespaceIndex

      html = leadingHtml
      if @value.length > MaxTokenLength
        while startIndex < endIndex
          html += "<span>" + @escapeString(@value, startIndex, startIndex + MaxTokenLength) + "</span>"
          startIndex += MaxTokenLength
      else
        html += @escapeString(@value, startIndex, endIndex)

      html += trailingHtml
    html

  escapeString: (str, startIndex, endIndex) ->
    strLength = str.length

    startIndex ?= 0
    endIndex ?= strLength

    str = str.slice(startIndex, endIndex) if startIndex > 0 or endIndex < strLength
    str.replace(EscapeRegex, @escapeStringReplace)

  escapeStringReplace: (match) ->
    switch match
      when '&' then '&amp;'
      when '"' then '&quot;'
      when "'" then '&#39;'
      when '<' then '&lt;'
      when '>' then '&gt;'
      else match

  hasLeadingWhitespace: ->
    @firstNonWhitespaceIndex? and @firstNonWhitespaceIndex > 0

  hasTrailingWhitespace: ->
    @firstTrailingWhitespaceIndex? and @firstTrailingWhitespaceIndex < @value.length
