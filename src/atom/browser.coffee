$ = require 'jquery'

Document = require 'document'

module.exports =
class Browser extends Document
  @register (path) -> /^https?:/.test path

  buffers: {}

  html: $ "<div id='browser'></div>"

  @isPathUrl: (path) ->
    /^https?:\/\//.test path

  constructor: ->
    atom.on "window:open", (e) =>
      path = e.details
      return unless @constructor.isPathUrl path

      @buffers[path] ?= $ "<iframe src='#{path}' style='width:100%;height:100%'></iframe>"

      @html.html @buffers[path]

      @show()

      atom.trigger "browser:focus", path
