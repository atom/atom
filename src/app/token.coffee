_ = require 'underscore'

module.exports =
class Token
  value: null
  scopes: null
  isAtomic: null

  constructor: ({@value, @scopes, @isAtomic, @bufferDelta, @fold}) ->
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

  breakOutTabCharacters: (tabText) ->
    return [this] unless /\t/.test(@value)

    for substring in @value.match(/([^\t]+|\t)/g)
      if substring == '\t'
        @buildTabToken(tabText)
      else
        new Token(value: substring, scopes: @scopes)

  buildTabToken: (tabText) ->
    new Token(value: tabText, scopes: @scopes, bufferDelta: 1, isAtomic: true)

  getCssClassString: ->
    @cssClassString ?= @getCssClasses().join(' ')

  getCssClasses: ->
    classes = []
    for scope in @scopes
      scopeComponents = scope.split('.')
      for i in [0...scopeComponents.length]
        classes.push scopeComponents[0..i].join('-')
    classes

