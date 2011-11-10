fs = require 'fs'

module.exports =
class ExtensionManager
  extensions: {}

  constructor: ->
    atom.on 'window:load', @loadExtensions
    atom.on 'window:close', @unloadExtensions

  loadExtensions: =>
    extension.shutdown() for name, extension of atom.extensions
    atom.extensions = {}

    extensionPaths = fs.list require.resourcePath + "/extensions"
    for extensionPath in extensionPaths when fs.isDirectory extensionPath
      try
        extension = require extensionPath
        atom.extensions[extension.name] = new extension
      catch error
        console.warn "Loading Extension '#{fs.base extensionPath}' failed."
        console.warn error

    # After all the extensions are created, start them up.
    for name, extension of atom.extensions
      try
        extension.startup()
      catch error
        console.warn "Extension #{extension.constructor.name} failed to startup."
        console.warn error

  unloadExtensions: =>
    extension.shutdown() for name, extension of atom.extensions