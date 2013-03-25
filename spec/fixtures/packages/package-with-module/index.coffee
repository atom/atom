module.exports =
  configDefaults:
    numbers: { one: 1, two: 2 }

  someNumber: 0

  activate: ({@someNumber}) ->
    @someNumber ?= 1

  deactivate: ->

  serialize: ->
    {@someNumber}
