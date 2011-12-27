module.exports =
class OpenTag
  constructor: (@name) ->

  toHtml: ->
    "<#{@name}>"

