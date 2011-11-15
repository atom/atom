$ = require 'jquery'
fs = require 'fs'
Extension = require 'extension'
TabsPane = require 'tabs/tabs-pane'

module.exports =
class Tabs extends Extension
  project: null

  constructor: ->
    atom.keybinder.load require.resolve "tabs/key-bindings.coffee"

    atom.on 'project:open', @startup
    atom.on 'project:resource:active', @focus

  startup: (@project) =>
    @pane = new TabsPane this
    @pane.show()
    super

  shutdown: ->
    @pane.remove()
    super

  focus: (project, resource) =>
    @pane?.addTab resource.url