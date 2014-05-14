_ = require 'underscore-plus'
textUtils = require './text-utils'

WhitespaceRegexesByTabLength = {}
LeadingWhitespaceRegex = /^[ ]+/
TrailingWhitespaceRegex = /[ ]+$/
EscapeRegex = /[&"'<>]/g
CharacterRegex = /./g
StartCharacterRegex = /^./
StartDotRegex = /^\.?/
WhitespaceRegex = /\S/

MaxTokenLength = 20000

# Represents a single unit of text as selected by a grammar.
module.exports =
class Token
  value: null
  hasSurrogatePair: false
  scopes: null
  isAtomic: null
  isHardTab: null
  hasLeadingWhitespace: false
  hasTrailingWhitespace: false

  constructor: ({@value, @scopes, @isAtomic, @bufferDelta, @isHardTab}) ->
    @screenDelta = @value.length
    @bufferDelta ?= @screenDelta
    @hasSurrogatePair = textUtils.hasSurrogatePair(@value)

  isEqual: (other) ->
    @value == other.value and _.isEqual(@scopes, other.scopes) and !!@isAtomic == !!other.isAtomic

  isBracket: ->
    /^meta\.brace\b/.test(_.last(@scopes))

  splitAt: (splitIndex) ->
    value1 = @value.substring(0, splitIndex)
    value2 = @value.substring(splitIndex)
    [new Token(value: value1, scopes: @scopes), new Token(value: value2, scopes: @scopes)]

  whitespaceRegexForTabLength: (tabLength) ->
    WhitespaceRegexesByTabLength[tabLength] ?= new RegExp("([ ]{#{tabLength}})|(\t)|([^\t]+)", "g")

  breakOutAtomicTokens: (tabLength, breakOutLeadingSoftTabs, startColumn) ->
    if @hasSurrogatePair
      outputTokens = []
      column = startColumn

      for token in @breakOutSurrogatePairs()
        nextColumn += token.value.length
        if token.isAtomic
          outputTokens.push(token)
        else
          outputTokens.push(token.breakOutAtomicTokens(tabLength, breakOutLeadingSoftTabs, column)...)
        breakOutLeadingSoftTabs = token.isOnlyWhitespace() if breakOutLeadingSoftTabs
        column = nextColumn

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

  breakOutSurrogatePairs: ->
    outputTokens = []
    index = 0
    nonSurrogatePairStart = 0

    while index < @value.length
      if textUtils.isSurrogatePair(@value, index)
        if nonSurrogatePairStart isnt index
          outputTokens.push(new Token({value: @value[nonSurrogatePairStart...index], @scopes}))
        outputTokens.push(@buildSurrogatePairToken(@value, index))
        index += 2
        nonSurrogatePairStart = index
      else
        index++

    if nonSurrogatePairStart isnt index
      outputTokens.push(new Token({value: @value[nonSurrogatePairStart...index], @scopes}))

    outputTokens

  buildSurrogatePairToken: (value, index) ->
    new Token(
      value: value[index..index + 1]
      scopes: @scopes
      isAtomic: true
    )

  buildHardTabToken: (tabLength, column) ->
    @buildTabToken(tabLength, true, column)

  buildSoftTabToken: (tabLength) ->
    @buildTabToken(tabLength, false, 0)

  buildTabToken: (tabLength, isHardTab, column) ->
    tabStop = tabLength - column % tabLength
    new Token(
      value: _.multiplyString(" ", tabStop)
      scopes: @scopes
      bufferDelta: if isHardTab then 1 else tabStop
      isAtomic: true
      isHardTab: isHardTab
    )

  isOnlyWhitespace: ->
    not WhitespaceRegex.test(@value)

  matchesScopeSelector: (selector) ->
    targetClasses = selector.replace(StartDotRegex, '').split('.')
    _.any @scopes, (scope) ->
      scopeClasses = scope.split('.')
      _.isSubset(targetClasses, scopeClasses)

  getValueAsHtml: ({invisibles, hasIndentGuide})->
    invisibles ?= {}
    if @isHardTab
      classes = 'hard-tab'
      classes += ' indent-guide' if hasIndentGuide
      classes += ' invisible-character' if invisibles.tab
      value = if invisibles.tab then @value.replace(StartCharacterRegex, invisibles.tab) else @value
      html = "<span class='#{classes}'>#{@escapeString(value)}</span>"
    else
      startIndex = 0
      endIndex = @value.length

      leadingHtml = ''
      trailingHtml = ''

      if @hasLeadingWhitespace and match = LeadingWhitespaceRegex.exec(@value)
        classes = 'leading-whitespace'
        classes += ' indent-guide' if hasIndentGuide
        classes += ' invisible-character' if invisibles.space

        match[0] = match[0].replace(CharacterRegex, invisibles.space) if invisibles.space
        leadingHtml = "<span class='#{classes}'>#{match[0]}</span>"

        startIndex = match[0].length

      if @hasTrailingWhitespace and match = TrailingWhitespaceRegex.exec(@value)
        tokenIsOnlyWhitespace = match[0].length is @value.length
        classes = 'trailing-whitespace'
        classes += ' indent-guide' if hasIndentGuide and not @hasLeadingWhitespace and tokenIsOnlyWhitespace
        classes += ' invisible-character' if invisibles.space

        match[0] = match[0].replace(CharacterRegex, invisibles.space) if invisibles.space
        trailingHtml = "<span class='#{classes}'>#{match[0]}</span>"

        endIndex = match.index

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
