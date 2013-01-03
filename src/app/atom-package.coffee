Package = require 'package'
fs = require 'fs'

module.exports =
class AtomPackage extends Package
  constructor: (@name) ->
    super
    @module = require(@path)
    @module.name = @name

  load: ->
    try
      rootView.activatePackage(@module)
      @loadKeymaps()
    catch e
      console.error "Failed to load package named '#{@name}'", e.stack

  loadKeymaps: ->
    for keymapPath in @getKeymapPaths()
      keymap.load(keymapPath)

  getKeymapPaths: ->
    keymapsDirPath = fs.join(@path, 'keymaps')
    if fs.exists keymapsDirPath
      fs.list keymapsDirPath
    else
      []
