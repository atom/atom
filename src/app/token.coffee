module.exports =
class Token
  value: null
  type: null
  isAtomic: null

  constructor: ({@value, @type, @isAtomic}) ->

  isEqual: (other) ->
    @value == other.value and @type == other.type and !!@isAtomic == !!other.isAtomic
