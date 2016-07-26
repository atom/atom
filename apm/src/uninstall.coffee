path = require 'path'

async = require 'async'
CSON = require 'season'
yargs = require 'yargs'

auth = require './auth'
Command = require './command'
config = require './apm'
fs = require './fs'
request = require './request'

module.exports =
class Uninstall extends Command
  @commandNames: ['deinstall', 'delete', 'erase', 'remove', 'rm', 'uninstall']

  parseOptions: (argv) ->
    options = yargs(argv).wrap(100)
    options.usage """

      Usage: apm uninstall <package_name>...

      Delete the installed package(s) from the ~/.atom/packages directory.
    """
    options.alias('h', 'help').describe('help', 'Print this usage message')
    options.alias('d', 'dev').boolean('dev').describe('dev', 'Uninstall from ~/.atom/dev/packages')
    options.boolean('hard').describe('hard', 'Uninstall from ~/.atom/packages and ~/.atom/dev/packages')

  getPackageVersion: (packageDirectory) ->
    try
      CSON.readFileSync(path.join(packageDirectory, 'package.json'))?.version
    catch error
      null

  registerUninstall: ({packageName, packageVersion}, callback) ->
    return callback() unless packageVersion

    auth.getToken (error, token) ->
      return callback() unless token

      requestOptions =
        url: "#{config.getAtomPackagesUrl()}/#{packageName}/versions/#{packageVersion}/events/uninstall"
        json: true
        headers:
          authorization: token

      request.post requestOptions, (error, response, body) -> callback()

  run: (options) ->
    {callback} = options
    options = @parseOptions(options.commandArgs)
    packageNames = @packageNamesFromArgv(options.argv)

    if packageNames.length is 0
      callback("Please specify a package name to uninstall")
      return

    packagesDirectory = path.join(config.getAtomDirectory(), 'packages')
    devPackagesDirectory = path.join(config.getAtomDirectory(), 'dev', 'packages')

    uninstallsToRegister = []
    uninstallError = null

    for packageName in packageNames
      process.stdout.write "Uninstalling #{packageName} "
      try
        unless options.argv.dev
          packageDirectory = path.join(packagesDirectory, packageName)
          if fs.existsSync(packageDirectory)
            packageVersion = @getPackageVersion(packageDirectory)
            fs.removeSync(packageDirectory)
            if packageVersion
              uninstallsToRegister.push({packageName, packageVersion})
          else if not options.argv.hard
            throw new Error("Does not exist")

        if options.argv.hard or options.argv.dev
          packageDirectory = path.join(devPackagesDirectory, packageName)
          if fs.existsSync(packageDirectory)
            fs.removeSync(packageDirectory)
          else if not options.argv.hard
            throw new Error("Does not exist")

        @logSuccess()
      catch error
        @logFailure()
        uninstallError = new Error("Failed to delete #{packageName}: #{error.message}")
        break

    async.eachSeries uninstallsToRegister, @registerUninstall.bind(this), ->
      callback(uninstallError)
