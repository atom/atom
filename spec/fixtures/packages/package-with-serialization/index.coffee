module.exports =
  activate: ({@someNumber}) ->
    @someNumber ?= 1

  serialize: ->
    {@someNumber}
