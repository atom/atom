Package = require 'package'
fs = require 'fs'

module.exports =
class AtomPackage extends Package
  constructor: ->
    super
    @module = require(@path)
    @module.name = @name

  load: ->
    try
      rootView.activatePackage(@module)
      extensionKeymapPath = require.resolve(fs.join(@name, "src/keymap"), verifyExistence: false)
      require extensionKeymapPath if fs.exists(extensionKeymapPath)
    catch e
      console.error "Failed to load package named '#{name}'", e.stack
