module.exports =
  configDefaults:
    numbers: { one: 1, two: 2 }

  activate: ({@someNumber}) ->
    @someNumber ?= 1

  serialize: ->
    {@someNumber}
