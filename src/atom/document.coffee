_ = require 'underscore'
Pane = require 'pane'

module.exports =
class Document extends Pane
  position: "main"

  @handlers: {}
  @handler: (path) ->
    for handler, test of Document.handlers
      return handler if test path
  @register: (cb) ->
    Document.handlers[this] = cb

  open: ->
  close: ->
  save: ->
