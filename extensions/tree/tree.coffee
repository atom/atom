_ = require 'underscore'

Extension = require 'extension'
TreePane = require 'tree/tree-pane'

fs = require 'fs'

module.exports =
class Tree extends Extension
  project: null

  constructor: ->
    atom.keybinder.load require.resolve "tree/key-bindings.coffee"
    atom.on 'project:open', @startup

  startup: (@project) =>
    @pane = new TreePane this
    @pane.show()
    super

  shutdown: ->
    @pane.remove()
    super

  urls: (root=@project.url) ->
    @project.urls root
