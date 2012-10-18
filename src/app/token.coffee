_ = require 'underscore'

module.exports =
class Token
  value: null
  scopes: null
  isAtomic: null
  isTab: null

  constructor: ({@value, @scopes, @isAtomic, @bufferDelta, @fold, @isTab}) ->
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

  breakOutTabCharacters: (tabLength, showInvisibles) ->
    return [this] unless /\t/.test(@value)

    for substring in @value.match(/[^\t]+|\t/g)
      if substring == "\t"
        @buildTabToken(tabLength)
      else
        new Token(value: substring, scopes: @scopes)

  buildTabToken: (tabLength) ->
    new Token(
      value: new Array(tabLength + 1).join(" ")
      scopes: @scopes
      bufferDelta: 1
      isAtomic: true
      isTab: true
    )

  getValueAsHtml: ({showInvisibles, hasLeadingWhitespace, hasTrailingWhitespace})->
    html = @value
      .replace(/&/g, '&amp;')
      .replace(/"/g, '&quot;')
      .replace(/'/g, '&#39;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')

    if showInvisibles
      if @isTab
        html = html.replace(/^./, "<span class='invisible'>▸</span>")
      else
        if hasLeadingWhitespace
          html = html.replace /^[ ]+/, (match) ->
            "<span class='invisible'>#{match.replace(/./g, '•')}</span>"
        if hasTrailingWhitespace
          html = html.replace /[ ]+$/, (match) ->
            "<span class='invisible'>#{match.replace(/./g, '•')}</span>"

    html
