path = require 'path'

_ = require 'underscore'
config = require './config'
optimist = require 'optimist'

fs = require './fs'

module.exports =
class Uninstaller
  @commandNames: ['uninstall']

  parseOptions: (argv) ->
    options = optimist(argv)
    options.usage """

      Usage: apm uninstall <package_name>

      Delete the installed package from the ~/.atom/packages directory.
    """
    options.alias('h', 'help').describe('help', 'Print this usage message')

  showHelp: (argv) -> @parseOptions(argv).showHelp()

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
