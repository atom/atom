path = require 'path'

config = require './config'
optimist = require 'optimist'

Command = require './command'
fs = require './fs'

module.exports =
class Uninstall extends Command
  @commandNames: ['uninstall']

  parseOptions: (argv) ->
    options = optimist(argv)
    options.usage """

      Usage: apm uninstall <package_name>...

      Delete the installed package(s) from the ~/.atom/packages directory.
    """
    options.alias('h', 'help').describe('help', 'Print this usage message')
    options.alias('d', 'dev').boolean('dev').describe('dev', 'Uninstall from ~/.atom/dev/packages')
    options.boolean('hard').describe('hard', 'Uninstall from ~/.atom/packages and ~/.atom/dev/packages')

  run: (options) ->
    {callback} = options
    options = @parseOptions(options.commandArgs)
    packageNames = @packageNamesFromArgv(options.argv)

    if packageNames.length is 0
      callback("Must specify a package name to uninstall")
      return

    packagesDirectory = path.join(config.getAtomDirectory(), 'packages')
    devPackagesDirectory = path.join(config.getAtomDirectory(), 'dev', 'packages')

    for packageName in packageNames
      process.stdout.write "Uninstalling #{packageName} "
      try
        unless options.argv.dev
          fs.removeSync(path.join(packagesDirectory, packageName))

        if options.argv.hard or options.argv.dev
          fs.removeSync(path.join(devPackagesDirectory, packageName))

        process.stdout.write '\u2713\n'.green
      catch error
        process.stdout.write '\u2717\n'.red
        callback("Failed to delete #{packageName}: #{error.message}")
        return

    callback()
