module.exports =
class Token
  value: null
  type: null
  isAtomic: null

  constructor: ({@value, @type, @isAtomic}) ->

  isEqual: (other) ->
    @value == other.value and @type == other.type and !!@isAtomic == !!other.isAtomic

  splitAt: (splitIndex) ->
    value1 = @value.substring(0, splitIndex)
    value2 = @value.substring(splitIndex)
    [new Token(value: value1, type: @type), new Token(value: value2, type: @type)]

  breakOutTabCharacters: ->
    for substring in @value.match(/([^\t]+|\t)/g)
      if substring == '\t'
        @buildTabToken()
      else
        new Token(value: substring, type: @type)

  buildTabToken: ->
    new Token(value: atom.tabText, type: @type, isAtomic: true)
