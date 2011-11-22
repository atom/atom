fs = require 'fs'

module.exports =
class ExtensionManager
  constructor: ->
    @loadExtensions()
    atom.on 'window:close', @unloadExtensions

  loadExtensions: =>
    extension.shutdown() for name, extension of atom.extensions
    atom.extensions = {}

    extensionPaths = fs.list require.resourcePath + "/extensions"
    for extensionPath in extensionPaths when fs.isDirectory extensionPath
      try
        extension = require extensionPath
        atom.extensions[extension.name] = new extension
        atom.keybinder.load "#{extensionPath}/key-bindings.coffee"
      catch error
        console.warn "Loading Extension '#{fs.base extensionPath}' failed."
        console.warn error

  unloadExtensions: =>
    extension.shutdown() for name, extension of atom.extensions