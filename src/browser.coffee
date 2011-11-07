$ = require 'jquery'

Event = require 'event'
Pane = require 'pane'

module.exports =
class Browser extends Pane
  buffers: {}

  html: $ "<div id='browser'></div>"

  position: 'main'

  @isPathUrl: (path) ->
    /^https?:\/\//.test path

  constructor: ->
    Event.on "window:open", (e) =>
      path = e.details
      return unless @constructor.isPathUrl path

      @buffers[path] ?= $ "<iframe src='#{path}' style='width:100%;height:100%'></iframe>"

      @html.html @buffers[path]

      @show()

      Event.trigger "browser:focus", path
