$ = require 'jquery'

Extension = require 'extension'
TabsPane = require 'tabs/tabs-pane'

fs = require 'fs'

module.exports =
class Tabs extends Extension
  constructor: () ->
    atom.keybinder.register "tabs", @
    atom.keybinder.load require.resolve "tabs/key-bindings.coffee"

    @pane = new TabsPane @

    atom.event.on 'editor:bufferAdd', (e) =>
      path = e.details
      @pane.addTab path

    atom.event.on 'editor:bufferFocus', (e) =>
      path = e.details
      @pane.addTab path

    atom.event.on 'editor:bufferRemove', (e) =>
      path = e.details
      @pane.removeTab path

    atom.event.on 'browser:focus', (e) =>
      path = e.details
      @pane.addTab path

  startup: ->
    @pane.show()
    for path, buffer of window.editor.buffers
      @pane.addTab path
