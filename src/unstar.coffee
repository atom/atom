async = require 'async'
optimist = require 'optimist'

config = require './apm'
Command = require './command'
Login = require './login'
request = require './request'

module.exports =
class Unstar extends Command
  @commandNames: ['unstar']

  parseOptions: (argv) ->
    options = optimist(argv)
    options.usage """

      Usage: apm unstar <package_name>...

      Unstar the given packages on https://atom.io

      Run `apm stars` to see all your starred packages.
    """
    options.alias('h', 'help').describe('help', 'Print this usage message')

  starPackage: (packageName, token, callback) ->
    process.stdout.write '\uD83D\uDC5F \u2B50  ' if process.platform is 'darwin'
    process.stdout.write "Unstarring #{packageName} "
    requestSettings =
      json: true
      url: "#{config.getAtomPackagesUrl()}/#{packageName}/star"
      headers:
        authorization: token
    request.del requestSettings, (error, response, body={}) =>
      if error?
        @logFailure()
        callback(error)
      else if response.statusCode isnt 204
        @logFailure()
        message = body.message ? body.error ? body
        callback("Unstarring package failed: #{message}")
      else
        @logSuccess()
        callback()

  run: (options) ->
    {callback} = options
    options = @parseOptions(options.commandArgs)
    packageNames = @packageNamesFromArgv(options.argv)

    if packageNames.length is 0
      callback("Please specify a package name to unstar")
      return

    Login.getTokenOrLogin (error, token) =>
      return callback(error) if error?

      commands = packageNames.map (packageName) =>
        (callback) => @starPackage(packageName, token, callback)
      async.waterfall(commands, callback)
