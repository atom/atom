$ = require 'jquery'

Extension = require 'extension'
TabsPane = require 'tabs/tabs-pane'

fs = require 'fs'

module.exports =
class Tabs extends Extension
  constructor: () ->
    atom.keybinder.load require.resolve "tabs/key-bindings.coffee"

    @pane = new TabsPane @

    atom.on 'editor:bufferAdd', (e) =>
      path = e.details
      @pane.addTab path

    atom.on 'editor:bufferFocus', (e) =>
      path = e.details
      @pane.addTab path

    atom.on 'editor:bufferRemove', (e) =>
      path = e.details
      @pane.removeTab path

    atom.on 'browser:focus', (e) =>
      path = e.details
      @pane.addTab path

  startup: ->
    @pane.show()
