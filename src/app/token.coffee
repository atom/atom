_ = require 'underscore'

module.exports =
class Token
  value: null
  scopes: null
  isAtomic: null
  isHardTab: null

  constructor: ({@value, @scopes, @isAtomic, @bufferDelta, @isHardTab}) ->
    @screenDelta = @value.length
    @bufferDelta ?= @screenDelta

  isEqual: (other) ->
    @value == other.value and _.isEqual(@scopes, other.scopes) and !!@isAtomic == !!other.isAtomic

  isBracket: ->
    /^meta\.brace\b/.test(_.last(@scopes))

  splitAt: (splitIndex) ->
    value1 = @value.substring(0, splitIndex)
    value2 = @value.substring(splitIndex)
    [new Token(value: value1, scopes: @scopes), new Token(value: value2, scopes: @scopes)]

  breakOutAtomicTokens: (tabLength, breakOutLeadingWhitespace) ->
    if breakOutLeadingWhitespace
      return [this] unless /^[ ]|\t/.test(@value)
    else
      return [this] unless /\t/.test(@value)

    outputTokens = []
    regex = new RegExp("([ ]{#{tabLength}})|(\t)|([^\t]+)", "g")

    while match = regex.exec(@value)
      [fullMatch, softTab, hardTab] = match
      if softTab and breakOutLeadingWhitespace
        outputTokens.push(@buildSoftTabToken(tabLength, false))
      else if hardTab
        breakOutLeadingWhitespace = false
        outputTokens.push(@buildHardTabToken(tabLength, true))
      else
        breakOutLeadingWhitespace = false
        outputTokens.push(new Token(value: match[0], scopes: @scopes))

    outputTokens

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
