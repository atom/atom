_ = require 'underscore'

Extension = require 'extension'
TreePane = require 'tree/tree-pane'

fs = require 'fs'

module.exports =
class Tree extends Extension
  ignorePattern: /\.git|\.xcodeproj|\.DS_Store/

  constructor: ->
    atom.on 'project:load', @startup

  startup: =>
    atom.keybinder.load require.resolve "tree/key-bindings.coffee"

    @pane = new TreePane this
    @pane.show()

  shutdown: ->
