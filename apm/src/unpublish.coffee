path = require 'path'
readline = require 'readline'

yargs = require 'yargs'

auth = require './auth'
Command = require './command'
config = require './apm'
fs = require './fs'
request = require './request'

module.exports =
class Unpublish extends Command
  @commandNames: ['unpublish']

  parseOptions: (argv) ->
    options = yargs(argv).wrap(100)

    options.usage """
      Usage: apm unpublish [<package_name>]
             apm unpublish <package_name>@<package_version>

      Remove a published package or package version from the atom.io registry.

      The package in the current working directory will be used if no package
      name is specified.
    """
    options.alias('h', 'help').describe('help', 'Print this usage message')
    options.alias('f', 'force').boolean('force').describe('force', 'Do not prompt for confirmation')

  unpublishPackage: (packageName, packageVersion, callback) ->
    packageLabel = packageName
    packageLabel += "@#{packageVersion}" if packageVersion

    process.stdout.write "Unpublishing #{packageLabel} "

    auth.getToken (error, token) =>
      if error?
        @logFailure()
        callback(error)
        return

      options =
        uri: "#{config.getAtomPackagesUrl()}/#{packageName}"
        headers:
          authorization: token
        json: true

      options.uri += "/versions/#{packageVersion}" if packageVersion

      request.del options, (error, response, body={}) =>
        if error?
          @logFailure()
          callback(error)
        else if response.statusCode isnt 204
          @logFailure()
          message = body.message ? body.error ? body
          callback("Unpublishing failed: #{message}")
        else
          @logSuccess()
          callback()

  promptForConfirmation: (packageName, packageVersion, callback) ->
    packageLabel = packageName
    packageLabel += "@#{packageVersion}" if packageVersion

    if packageVersion
      question = "Are you sure you want to unpublish '#{packageLabel}'? (no) "
    else
      question = "Are you sure you want to unpublish ALL VERSIONS of '#{packageLabel}'? " +
                 "This will remove it from the apm registry, including " +
                 "download counts and stars, and this action is irreversible. (no)"

    @prompt question, (answer) =>
      answer = if answer then answer.trim().toLowerCase() else 'no'
      if answer in ['y', 'yes']
        @unpublishPackage(packageName, packageVersion, callback)
      else
        callback("Cancelled unpublishing #{packageLabel}")

  prompt: (question, callback) ->
    prompt = readline.createInterface(process.stdin, process.stdout)

    prompt.question question, (answer) ->
      prompt.close()
      callback(answer)

  run: (options) ->
    {callback} = options
    options = @parseOptions(options.commandArgs)
    [name] = options.argv._

    if name?.length > 0
      atIndex = name.indexOf('@')
      if atIndex isnt -1
        version = name.substring(atIndex + 1)
        name = name.substring(0, atIndex)

    unless name
      try
        name = JSON.parse(fs.readFileSync('package.json'))?.name

    unless name
      name = path.basename(process.cwd())

    if options.argv.force
      @unpublishPackage(name, version, callback)
    else
      @promptForConfirmation(name, version, callback)
