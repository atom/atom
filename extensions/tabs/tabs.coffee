$ = require 'jquery'
fs = require 'fs'
Extension = require 'extension'
TabsPane = require 'tabs/tabs-pane'

module.exports =
class Tabs extends Extension
  project: null

  constructor: ->
    atom.keybinder.load require.resolve "tabs/key-bindings.coffee"

    atom.on 'project:load', @startup

  startup: (@project) =>
    @pane = new TabsPane this
    @pane.show()

    atom.on 'project:resource:load', (project, resource) =>
      @pane.addTab resource.url

    super

  shutdown: ->
    @pane.remove()
    super
