_ = require 'underscore'
Pane = require 'pane'

# When subclassing, call super() at the end of your
# constructor.
module.exports =
class Document extends Pane
  position: "main"
  path: null

  constructor: ->

  close: ->
    window.close()

  save: ->
