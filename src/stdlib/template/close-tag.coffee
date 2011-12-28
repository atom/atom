module.exports =
class CloseTag
  constructor: (@name) ->

  toHtml: ->
    "</#{@name}>"

