_ = require 'underscore'
textUtils = require 'text-utils'

whitespaceRegexesByTabLength = {}

module.exports =
class Token
  value: null
  hasSurrogatePair: false
  scopes: null
  isAtomic: null
  isHardTab: null

  ### Internal ###

  constructor: ({@value, @scopes, @isAtomic, @bufferDelta, @isHardTab}) ->
    @screenDelta = @value.length
    @bufferDelta ?= @screenDelta
    @hasSurrogatePair = textUtils.hasSurrogatePair(@value)

  ### Public ###

  isEqual: (other) ->
    @value == other.value and _.isEqual(@scopes, other.scopes) and !!@isAtomic == !!other.isAtomic

  isBracket: ->
    /^meta\.brace\b/.test(_.last(@scopes))

  splitAt: (splitIndex) ->
    value1 = @value.substring(0, splitIndex)
    value2 = @value.substring(splitIndex)
    [new Token(value: value1, scopes: @scopes), new Token(value: value2, scopes: @scopes)]

  whitespaceRegexForTabLength: (tabLength) ->
    whitespaceRegexesByTabLength[tabLength] ?= new RegExp("([ ]{#{tabLength}})|(\t)|([^\t]+)", "g")

  breakOutAtomicTokens: (tabLength, breakOutLeadingWhitespace) ->
    if @hasSurrogatePair
      outputTokens = []

      for token in @breakOutSurrogatePairs()
        if token.isAtomic
          outputTokens.push(token)
        else
          outputTokens.push(token.breakOutAtomicTokens(tabLength, breakOutLeadingWhitespace)...)
        breakOutLeadingWhitespace = token.isOnlyWhitespace() if breakOutLeadingWhitespace

      outputTokens
    else
      if breakOutLeadingWhitespace
        return [this] unless /^[ ]|\t/.test(@value)
      else
        return [this] unless /\t/.test(@value)

      outputTokens = []
      regex = @whitespaceRegexForTabLength(tabLength)
      while match = regex.exec(@value)
        [fullMatch, softTab, hardTab] = match
        if softTab and breakOutLeadingWhitespace
          outputTokens.push(@buildSoftTabToken(tabLength, false))
        else if hardTab
          breakOutLeadingWhitespace = false
          outputTokens.push(@buildHardTabToken(tabLength, true))
        else
          breakOutLeadingWhitespace = false
          value = match[0]
          outputTokens.push(new Token({value, @scopes}))

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

  buildHardTabToken: (tabLength) ->
    @buildTabToken(tabLength, true)

  buildSoftTabToken: (tabLength) ->
    @buildTabToken(tabLength, false)

  buildTabToken: (tabLength, isHardTab) ->
    new Token(
      value: _.multiplyString(" ", tabLength)
      scopes: @scopes
      bufferDelta: if isHardTab then 1 else tabLength
      isAtomic: true
      isHardTab: isHardTab
    )

  isOnlyWhitespace: ->
    not /\S/.test(@value)

  matchesScopeSelector: (selector) ->
    targetClasses = selector.replace(/^\.?/, '').split('.')
    _.any @scopes, (scope) ->
      scopeClasses = scope.split('.')
      _.isSubset(targetClasses, scopeClasses)

  getValueAsHtml: ({invisibles, hasLeadingWhitespace, hasTrailingWhitespace, hasIndentGuide})->
    invisibles ?= {}
    html = @value
      .replace(/&/g, '&amp;')
      .replace(/"/g, '&quot;')
      .replace(/'/g, '&#39;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')

    if @isHardTab
      classes = []
      classes.push('indent-guide') if hasIndentGuide
      classes.push('invisible-character') if invisibles.tab
      classes.push('hard-tab')
      classes = classes.join(' ')
      html = html.replace /^./, (match) ->
        match = invisibles.tab ? match
        "<span class='#{classes}'>#{match}</span>"
    else
      if hasLeadingWhitespace
        classes = []
        classes.push('indent-guide') if hasIndentGuide
        classes.push('invisible-character') if invisibles.space
        classes.push('leading-whitespace')
        classes = classes.join(' ')
        html = html.replace /^[ ]+/, (match) ->
          match = match.replace(/./g, invisibles.space) if invisibles.space
          "<span class='#{classes}'>#{match}</span>"
      if hasTrailingWhitespace
        classes = []
        classes.push('indent-guide') if hasIndentGuide and not hasLeadingWhitespace
        classes.push('invisible-character') if invisibles.space
        classes.push('trailing-whitespace')
        classes = classes.join(' ')
        html = html.replace /[ ]+$/, (match) ->
          match = match.replace(/./g, invisibles.space) if invisibles.space
          "<span class='#{classes}'>#{match}</span>"

    html
