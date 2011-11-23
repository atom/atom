_ = require 'underscore'
Pane = require 'pane'

# When subclassing, call super() at the end of your
# constructor.
module.exports =
class Resource extends Pane
  position: "main"
  url: null

  # Can be used to delegate key events to another object, such as a pane.
  responder: ->
    this

  close: ->
    window.close()
