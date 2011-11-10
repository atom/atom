_ = require 'underscore'
Pane = require 'pane'

# When subclassing, call super() at the end of your
# constructor.
module.exports =
class Document extends Pane
  position: "main"
  path: null

  @handlers: {}
  @handler: (path) ->
    for name, {test, handler} of Document.handlers
      return new handler path if test path
    null
  @register: (test) ->
    Document.handlers[@name] = {test, handler: this}

  constructor: (path) ->
    @path = path if path
    atom.trigger 'document:load', this

  open: ->
  close: ->
  save: ->
