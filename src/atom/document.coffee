_ = require 'underscore'
Pane = require 'pane'

# When subclassing, call super() at the end of your
# constructor.
module.exports =
class Document extends Pane
  @handlers: []

  @canOpen: () ->
    throw "#{@name}: Must implement a 'canOpen' class method."

  @forURL: (url) ->
    handler = _.find @handlers, (handler) -> handler.canOpen url
    throw "I DON'T KNOW ABOUT #{window.url}" if not handler
    new handler

  position: "main"
  path: null

  constructor: ->

  open: (path) ->
    not @path and @constructor.canOpen path

  close: ->
    window.close()

  save: ->
