$ = require 'jquery'
fs = require 'fs'
Extension = require 'extension'
TabsPane = require 'tabs/tabs-pane'

module.exports =
class Tabs extends Extension
  project: null

  constructor: ->
    atom.on 'project:open', @startup
    atom.on 'project:resource:active', @focus
    atom.on 'project:resource:close', @close

  startup: (@project) =>
    @pane = new TabsPane this
    @pane.show()
    super

  shutdown: ->
    @pane.remove()
    super

  toggle: ->
    @pane?.toggle()

  focus: (project, resource) =>
    @pane?.addTab resource.url

  close: (project, resource) =>
    @pane?.removeTab resource.url