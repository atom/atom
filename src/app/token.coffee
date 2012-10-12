_ = require 'underscore'

module.exports =
class Token
  value: null
  scopes: null
  isAtomic: null

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

  breakOutWhitespaceCharacters: (tabLength, showInvisibles) ->
    return [this] unless /\t| /.test(@value)

    for substring in @value.match(/([^\t ]+|(\t| +))/g)
      scopesForInvisibles = if showInvisibles then @scopes.concat("invisible") else @scopes

      if substring == "\t"
        value = new Array(tabLength + 1).join(" ")
        value = "▸" + value[1..] if showInvisibles
        new Token(value: value, scopes: scopesForInvisibles, bufferDelta: 1, isAtomic: true)
      else if /^ +$/.test(substring)
        value = if showInvisibles then substring.replace(/[ ]/g, "•") else substring
        new Token(value: value, scopes: scopesForInvisibles)
      else
        new Token(value: substring, scopes: @scopes)

  buildTabToken: (tabLength) ->
    tabText = new Array(tabLength + 1).join(" ")

  escapeValue: (showInvisibles)->
    @value
      .replace(/&/g, '&amp;')
      .replace(/"/g, '&quot;')
      .replace(/'/g, '&#39;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
