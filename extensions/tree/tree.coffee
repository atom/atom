_ = require 'underscore'

Extension = require 'extension'
TreePane = require 'tree/tree-pane'

fs = require 'fs'

module.exports =
class Tree extends Extension
  ignorePattern: /^(\.git|\.xcodeproj|\.DS_Store)$/

  project: null

  constructor: ->
    atom.keybinder.load require.resolve "tree/key-bindings.coffee"
    atom.on 'project:load', @startup

  startup: (@project) =>
    @pane = new TreePane this
    @pane.show()

  shutdown: ->
    @pane.remove()

  urls: (root=@project.url) ->
    _.compact _.map (fs.list root), (url) =>
      return if @ignorePattern.test url
      type: if fs.isDirectory url then 'dir' else 'file'
      label: url.replace(root, "").substring 1
      url: url
