path = require 'path'
url = require 'url'

require 'colors'
CSON = require 'season'
optimist = require 'optimist'
request = require 'request'

auth = require './auth'
config = require './config'
Command = require './command'

module.exports =
class Publish extends Command
  @commandNames: ['publish']

  constructor: ->
    @userConfigPath = config.getUserConfigPath()
    @atomNpmPath = require.resolve('npm/bin/npm-cli')

  parseOptions: (argv) ->
    options = optimist(argv)
    options.usage """

      Usage: apm publish [<newversion> | major | minor | patch | build]
             apm publish -t <tagname>

      Publish a new version of the package in the current working directory.

      If a new version or version increment is specified than a new Git tag is
      created and the package.json file is updated with that new version before
      it is published to the apm registry. The HEAD branch and the new tag are
      pushed up to the remote repository automatically using this option.

      Run `apm available` to see all the currently published packages.
    """
    options.alias('h', 'help').describe('help', 'Print this usage message')
    options.alias('t', 'tag').string('tag').describe('tag', 'Specify a tag to publish')

  showHelp: (argv) -> @parseOptions(argv).showHelp()

  # Create a new version and tag use the `npm version` command.
  #
  #  * version: The new version or version increment.
  #  * callback: The callback function to invoke with an error as the first
  #    argument and a the generated tag string as the second argument.
  versionPackage: (version, callback) ->
    process.stdout.write 'Preparing and tagging a new version '
    versionArgs = ['version', version, '-m', 'Prepare %s release']
    @fork @atomNpmPath, versionArgs, (code, stderr='', stdout='') ->
      if code is 0
        process.stdout.write '\u2713\n'.green
        callback(null, stdout.trim())
      else
        process.stdout.write '\u2717\n'.red
        callback("#{stdout}\n#{stderr}")

  # Push a tag to the remote repository.
  #
  #  * tag: The tag to push.
  #  * callback: The callback function to invoke with an error as the first
  #    argument.
  pushVersion: (tag, callback) ->
    process.stdout.write "Pushing #{tag} tag "
    pushArgs = ['push', 'origin', 'HEAD', tag]
    @spawn 'git', pushArgs, (code, stderr='', stdout='') ->
      if code is 0
        process.stdout.write '\u2713\n'.green
        callback()
      else
        process.stdout.write '\u2717\n'.red
        callback("#{stdout}\n#{stderr}")

  # Does the given package already exist in the registry?
  #
  #  * packageName: The string package name to check.
  #  * callback: The callback function invoke with an error as the first
  #    argument and true/false as the second argument.
  packageExists: (packageName, callback) ->
    auth.getToken (error, token) ->
      if error?
        callback(error)
        return

      requestSettings =
        url: "#{config.getAtomPackagesUrl()}/#{packageName}"
        json: true
        headers:
          authorization: token
      request.get requestSettings, (error, response, body={}) ->
        if error?
          callback(error)
        else
          callback(null, response.statusCode is 404)

  # Parse the repository in `name/owner` format from the package metadata.
  #
  # Returns a name/owner string or null if not parseable.
  getRepository: (pack) ->
    if repository = pack.repository?.url ? pack.repository
      repoPath = url.parse(repository.replace(/\.git$/, '')).pathname
      [name, owner] = repoPath.split('/')[-2..]
      return "#{name}/#{owner}" if name and owner
    null

  # Register the current repository with the package registry.
  #
  #  * repository: The string repository in `name/owner` format.
  #  * callback: The callback function to
  registerPackage: (repository, callback) ->
    auth.getToken (error, token) ->
      if error?
        callback(error)
        return

      requestSettings =
        url: config.getAtomPackagesUrl()
        json: true
        method: 'POST'
        body:
          repository: repository
        headers:
          authorization: token
      request.get requestSettings, (error, response, body={}) ->
        if error?
          callback(error)
        else if response.statusCode isnt 201
          message = body.message ? body.error ? body
          callback("Registering package failed: #{message}")
        else
          callback()

  # Create a new package version at the given Git tag.
  #
  #  * packageName: The string name of the package.
  #  * tag: The string Git tag of the new version.
  #  * callback: The callback function to invoke with an error as the first
  #    argument.
  createPackageVersion: (packageName, tag, callback) ->
    auth.getToken (error, token) ->
      if error?
        callback(error)
        return

      requestSettings =
        url: "#{config.getAtomPackagesUrl()}/#{packageName}/versions"
        json: true
        method: 'POST'
        body:
          tag: tag
        headers:
          authorization: token
      request.get requestSettings, (error, response, body={}) ->
        if error?
          callback(error)
        else if response.statusCode isnt 201
          message = body.message ? body.error ? body
          callback("Creating new version failed: #{message}")
        else
          callback()

  # Publish the version of the package associated with the given tag.
  #
  #  * tag: The Git tag string of the package version to publish.
  #  * callback: The callback function to invoke when done with an error as the
  #    first argument.
  publishPackage: (tag, callback) ->
    try
      pack = CSON.readFileSync(CSON.resolve('package')) ? {}

    unless repository = @getRepository(pack)
      callback('Unable to parse repository name/owner from package.json repository field')
      return

    publishNewVersion = =>
      process.stdout.write "Publishing #{pack.name}@#{tag} "
      @createPackageVersion pack.name, tag, (error) ->
        if error?
          process.stdout.write '\u2717\n'.red
          callback(error)
        else
          process.stdout.write '\u2713\n'.green
          callback()

    @packageExists pack.name, (error, exists) =>
      if error?
        callback(error)
        return

      if exists
        process.stdout.write "Registering #{pack.name} (#{repository})"
        @registerPackage repository, (error) =>
          if error?
            process.stdout.write '\u2717\n'.red
            callback(error)
          else
            process.stdout.write '\u2713\n'.green
            publishNewVersion()
      else
        publishNewVersion()

  # Run the publish command with the given options
  run: (options) ->
    {callback} = options
    options = @parseOptions(options.commandArgs)

    if version = options.argv._[0]
      @versionPackage version, (error, tag) =>
        if error?
          callback(error)
        else
          @pushVersion tag, (error) =>
            if error?
              callback(error)
            else
              @publishPackage(tag, callback)
    else
      if tag = options.argv.tag
        @publishPackage(tag, callback)
      else
        callback('Missing required tag to publish')
