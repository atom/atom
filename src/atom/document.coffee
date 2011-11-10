_ = require 'underscore'
Pane = require 'pane'

module.exports =
class Document extends Pane
  position: "main"

  @handlers: {}
  @handler: (path) ->
    for name, {test, handler} of Document.handlers
      return new handler path if test path
    null
  @register: (test) ->
    Document.handlers[@name] = {test, handler: this}

  open: ->
  close: ->
  save: ->
