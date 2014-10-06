path = require 'path'

_ = require 'underscore-plus'
async = require 'async'
CSON = require 'season'
optimist = require 'optimist'

config = require './config'
Command = require './command'
fs = require './fs'
Login = require './login'
Packages = require './packages'
request = require './request'

module.exports =
class Star extends Command
  @commandNames: ['star']

  parseOptions: (argv) ->
    options = optimist(argv)
    options.usage """

      Usage: apm star <package_name>...

      Star the given packages on https://atom.io

      Run `apm stars` to see all your starred packages.
    """
    options.alias('h', 'help').describe('help', 'Print this usage message')
    options.boolean('installed').describe('installed', 'Star all packages in ~/.atom/packages')

  starPackage: (packageName, {ignoreUnpublishedPackages, token}={}, callback) ->
    process.stdout.write '\u2B50  ' if process.platform is 'darwin'
    process.stdout.write "Starring #{packageName} "
    requestSettings =
      json: true
      url: "#{config.getAtomPackagesUrl()}/#{packageName}/star"
      headers:
        authorization: token
    request.post requestSettings, (error, response, body={}) =>
      if error?
        @logFailure()
        callback(error)
      else if response.statusCode is 404 and ignoreUnpublishedPackages
        process.stdout.write 'skipped (not published)\n'.yellow
        callback()
      else if response.statusCode isnt 200
        @logFailure()
        message = body.message ? body.error ? body
        callback("Starring package failed: #{message}")
      else
        @logSuccess()
        callback()

  getInstalledPackageNames: ->
    installedPackages = []
    userPackagesDirectory = path.join(config.getAtomDirectory(), 'packages')
    for child in fs.list(userPackagesDirectory)
      continue unless fs.isDirectorySync(path.join(userPackagesDirectory, child))

      if manifestPath = CSON.resolve(path.join(userPackagesDirectory, child, 'package'))
        try
          metadata = CSON.readFileSync(manifestPath) ? {}
          if metadata.name and Packages.getRepository(metadata)
            installedPackages.push metadata.name

    _.uniq(installedPackages)

  run: (options) ->
    {callback} = options
    options = @parseOptions(options.commandArgs)

    if options.argv.installed
      packageNames = @getInstalledPackageNames()
      if packageNames.length is 0
        callback()
        return
    else
      packageNames = @packageNamesFromArgv(options.argv)
      if packageNames.length is 0
        callback("Must specify a package name to star")
        return

    Login.getTokenOrLogin (error, token) =>
      return callback(error) if error?

      starOptions =
        ignoreUnpublishedPackages: options.argv.installed
        token: token

      commands = packageNames.map (packageName) =>
        (callback) => @starPackage(packageName, starOptions, callback)
      async.waterfall(commands, callback)
