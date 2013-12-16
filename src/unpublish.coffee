path = require 'path'
readline = require 'readline'

optimist = require 'optimist'
request = require 'request'

auth = require './auth'
Command = require './command'
fs = require './fs'

module.exports =
class Unpublish extends Command
  @commandNames: ['unpublish']

  parseOptions: (argv) ->
    options = optimist(argv)

    options.usage """
      Usage: apm unpublish <package_name>

      Remove a published package from the atom.io registry. The package in the
      current working directory will be unpublished if no package name is
      specified
    """
    options.alias('h', 'help').describe('help', 'Print this usage message')
    options.alias('f', 'force').describe('force', 'Do not prompt for confirmation.')

  unpublishPackage: (packageName, callback) ->
    auth.getToken (error, token) ->
      if error?
        callback(error)
        return

      options =
        uri: "https://www.atom.io/api/packages/#{packageName}"
        headers:
          authorization: token
        method: 'DELETE'
        json: true
      request options, (error, response, body={}) ->
        if error?
          callback(error)
        else if response.statusCode isnt 204
          message = body.message ? body.error ? body
          callback("Unpublishing package failed: #{message}")
        else
          callback()

  promptForConfirmation: (packageName, callback) ->
    prompt = readline.createInterface(process.stdin, process.stdout)
    prompt.question "Are you sure you want to unpublish #{packageName}? (yes) ", (answer) =>
      prompt.close()
      answer = if answer then answer.trim().toLowerCase() else 'yes'
      if answer is 'y' or answer is 'yes'
        @unpublishPackage(packageName, callback)

  run: (options) ->
    {callback} = options
    options = @parseOptions(options.commandArgs)

    name = options.argv._[0]
    unless name?
      try
        {name} = JSON.parse(fs.readFileSync('package.json')) ? {}
      name ?= path.basename(process.cwd())

    if options.argv.force
      @unpublishPackage(name, callback)
    else
      @promptForConfirmation(name, callback)
