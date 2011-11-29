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
        extension = atom.extensions[extension.name] = new extension
        atom.keybinder.load "#{extensionPath}/key-bindings.coffee"
        atom.settings.applyTo extension if extension.settings
      catch error
        console.warn "Loading Extension '#{fs.base extensionPath}' failed."
        console.warn error

  unloadExtensions: =>
    for name, extension of atom.extensions
      try
        extension.shutdown() if extension.running
      catch e
        console.error "Failed to shutdown #{name}"
        console.error e