path = require 'path'

_ = require 'underscore-plus'
config = require './config'
optimist = require 'optimist'

fs = require './fs'

module.exports =
class Uninstall
  @commandNames: ['uninstall']

  parseOptions: (argv) ->
    options = optimist(argv)
    options.usage """

      Usage: apm uninstall <package_name>...

      Delete the installed package(s) from the ~/.atom/packages directory.
    """
    options.alias('h', 'help').describe('help', 'Print this usage message')

  showHelp: (argv) -> @parseOptions(argv).showHelp()

  run: (options) ->
    {callback} = options
    options = @parseOptions(options.commandArgs)

    if options.argv._.length is 0
      callback("Must specify a package name to uninstall")
      return

    packagesDirectory = path.join(config.getAtomDirectory(), 'packages')
    packages = fs.list(packagesDirectory)
    for packageName in options.argv._
      process.stdout.write "Uninstalling #{packageName} "
      unless _.contains(packages, packageName)
        process.stdout.write '\u2717\n'.red
        callback("#{packageName} does not exist in #{packagesDirectory}")
        return

      try
        packagePath = path.join(packagesDirectory, packageName)
        fs.removeSync(packagePath)
        process.stdout.write '\u2713\n'.green
      catch error
        process.stdout.write '\u2717\n'.red
        callback("Failed to delete #{packageName}: #{error.message}")
        return

    callback()
