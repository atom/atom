{$$} = require 'space-pencil'

Template = $$ ->
  @div ->
    @div()
    @div()
    @div()

module.exports =
class MarkerView
  constructor: (@marker, @editorView) ->
    @element = Template.cloneElement(true)
