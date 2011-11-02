$ = require 'jquery'

Extension = require 'extension'
KeyBinder = require 'key-binder'
Event = require 'event'
TabsPane = require 'tabs/tabspane'

fs = require 'fs'

module.exports =
class Tabs extends Extension
  constructor: () ->
    KeyBinder.register "tabs", @
    KeyBinder.load require.resolve "tabs/key-bindings.coffee"

    @pane = new TabsPane @

    Event.on 'window:open', (e) =>
      path = e.details
      return if fs.isDirectory path  # Ignore directories
      @pane.addTab path

    Event.on 'editor:close', (e) =>
      path = e.details
      @pane.removeTab path

  startup: ->
    @pane.show()