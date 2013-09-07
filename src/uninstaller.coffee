path = require 'path'
fs = require './fs'
_ = require 'underscore'
config = require './config'

module.exports =
class Uninstaller
  @commandNames: ['uninstall']

  run: (options) ->
    packageName = options.commandArgs.shift()
    if packageName
      packagesDirectory = path.join(config.getAtomDirectory(), 'packages')
      packages = fs.list(packagesDirectory)
      if _.contains(packages, packageName)
        try
          packagePath = path.join(packagesDirectory, packageName)
          fs.rm(packagePath)
          console.log("Uninstalled #{packagePath}")
          options.callback()
        catch error
          options.callback("Failed to delete #{packageName}: #{error.message}")

      else
        options.callback("#{packageName} does not exist in #{packagesDirectory}")
    else
      options.callback("Must specify a package name to uninstall")
