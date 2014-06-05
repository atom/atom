path = require 'path'

async = require 'async'
optimist = require 'optimist'

config = require './config'
Command = require './command'
Login = require './login'
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

  starPackage: (packageName, token, callback) ->
    process.stdout.write '\u2B50  ' if process.platform is 'darwin'
    process.stdout.write "Starring #{packageName} "
    requestSettings =
      url: "#{config.getAtomPackagesUrl()}/#{packageName}/star"
      headers:
        authorization: token
    request.post requestSettings, (error, response, body={}) =>
      if error?
        @logFailure()
        callback(error)
      else if response.statusCode isnt 200
        @logFailure()
        message = body.message ? body.error ? body
        callback("Requesting packages failed: #{message}")
      else
        @logSuccess()
        callback()

  run: (options) ->
    {callback} = options
    options = @parseOptions(options.commandArgs)
    packageNames = @packageNamesFromArgv(options.argv)

    if packageNames.length is 0
      callback("Must specify a package name to star")
      return

    Login.getTokenOrLogin (error, token) =>
      return callback(error) if error?

      commands = packageNames.map (packageName) =>
        (callback) => @starPackage(packageName, token, callback)
      async.waterfall(commands, callback)
