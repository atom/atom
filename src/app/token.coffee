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

  breakOutTabCharacters: (tabLength) ->
    return [this] unless /\t/.test(@value)

    tabText = new Array(tabLength + 1).join(" ")
    for substring in @value.match(/([^\t]+|\t)/g)
      if substring == '\t'
        new Token(value: tabText, scopes: @scopes, bufferDelta: 1, isAtomic: true, isTab: true)
      else
        new Token(value: substring, scopes: @scopes)

  buildTabToken: (tabLength) ->
    tabText = new Array(tabLength + 1).join(" ")

  escapeValue: (showInvisibles)->
    return "&nbsp;" if @value == ""

    value = @value
      .replace(/&/g, '&amp;')
      .replace(/"/g, '&quot;')
      .replace(/'/g, '&#39;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')

    if showInvisibles
      if @isTab
        value = "▸" + value[1..]
      else
        value = value.replace(/[ ]+/g, "•")

    value
