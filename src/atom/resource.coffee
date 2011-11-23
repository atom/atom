_ = require 'underscore'
Pane = require 'pane'

# When subclassing, call super() at the end of your
# constructor.
module.exports =
class Resource extends Pane
  position: "main"
  settings: {}
  url: null

  # Can be used to delegate key events to another object, such as a pane.
  constructor: ->
    atom.settings.applyTo this

  responder: ->
    this

  close: ->
    window.close()
