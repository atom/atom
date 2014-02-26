path = require 'path'
url = require 'url'

optimist = require 'optimist'
Git = require 'git-utils'
request = require 'request'

auth = require './auth'
fs = require './fs'
config = require './config'
Command = require './command'
Login = require './login'

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
             apm publish --tag <tagname>

      Publish a new version of the package in the current working directory.

      If a new version or version increment is specified, then a new Git tag is
      created and the package.json file is updated with that new version before
      it is published to the apm registry. The HEAD branch and the new tag are
      pushed up to the remote repository automatically using this option.

      Run `apm available` to see all the currently published packages.
    """
    options.alias('h', 'help').describe('help', 'Print this usage message')
    options.alias('t', 'tag').string('tag').describe('tag', 'Specify a tag to publish')

  showHelp: (argv) -> @parseOptions(argv).showHelp()

  getToken: (callback) ->
    auth.getToken (error, token) ->
      if error?
        new Login().run({callback, commandArgs: []})
      else
        callback(null, token)

  # Create a new version and tag use the `npm version` command.
  #
  # version  - The new version or version increment.
  # callback - The callback function to invoke with an error as the first
  #            argument and a the generated tag string as the second argument.
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
  #  tag - The tag to push.
  #  callback - The callback function to invoke with an error as the first
  #             argument.
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

  # Check for the tag being available from the GitHub API before notifying
  # atom.io about the new version.
  #
  # The tag is checked for 5 times at 1 second intervals.
  #
  # pack - The package metadata.
  # tag - The tag that was pushed.
  # callback - The callback function to invoke when either the tag is available
  #            or the maximum numbers of requests for the tag have been made.
  #            No arguments are passed to the callback when it is invoked.
  waitForTagToBeAvailable: (pack, tag, callback) ->
    @getToken (error, token) =>
      if error?
        callback(error)
        return

      retryCount = 5
      interval = 1000
      requestSettings =
        url: "https://api.github.com/repos/#{@getRepository(pack)}/tags"
        json: true
        proxy: process.env.http_proxy || process.env.https_proxy
        headers:
          'User-Agent': "AtomApm/#{require('../package.json').version}"
          authorization: "token #{token}"

      requestTags = ->
        request.get requestSettings, (error, response, tags=[]) ->
          if response.statusCode is 200
            for {name}, index in tags when name is tag
              return callback()
          if --retryCount <= 0
            callback()
          else
            setTimeout(requestTags, interval)
      requestTags()

  # Does the given package already exist in the registry?
  #
  # packageName - The string package name to check.
  # callback    - The callback function invoke with an error as the first
  #               argument and true/false as the second argument.
  packageExists: (packageName, callback) ->
    @getToken (error, token) ->
      if error?
        callback(error)
        return

      requestSettings =
        url: "#{config.getAtomPackagesUrl()}/#{packageName}"
        json: true
        proxy: process.env.http_proxy || process.env.https_proxy
        headers:
          authorization: token
      request.get requestSettings, (error, response, body={}) ->
        if error?
          callback(error)
        else
          callback(null, response.statusCode is 200)

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
  # pack - The package metadata.
  # callback - The callback function.
  registerPackage: (pack, callback) ->
    unless pack.name
      callback('Required name field in package.json not found')
      return

    @packageExists pack.name, (error, exists) =>
      return callback(error) if error?
      return callback() if exists

      unless repository = @getRepository(pack)
        callback('Unable to parse repository name/owner from package.json repository field')
        return

      process.stdout.write "Registering #{pack.name} "
      @getToken (error, token) ->
        if error?
          process.stdout.write '\u2717\n'.red
          callback(error)
          return

        requestSettings =
          url: config.getAtomPackagesUrl()
          json: true
          method: 'POST'
          proxy: process.env.http_proxy || process.env.https_proxy
          body:
            repository: repository
          headers:
            authorization: token
        request.get requestSettings, (error, response, body={}) ->
          if error?
            callback(error)
          else if response.statusCode isnt 201
            message = body.message ? body.error ? body
            process.stdout.write '\u2717\n'.red
            callback("Registering package failed: #{message}")
          else
            process.stdout.write '\u2713\n'.green
            callback(null, true)

  # Create a new package version at the given Git tag.
  #
  # packageName - The string name of the package.
  # tag - The string Git tag of the new version.
  # callback - The callback function to invoke with an error as the first
  #            argument.
  createPackageVersion: (packageName, tag, callback) ->
    @getToken (error, token) ->
      if error?
        callback(error)
        return

      requestSettings =
        url: "#{config.getAtomPackagesUrl()}/#{packageName}/versions"
        json: true
        method: 'POST'
        proxy: process.env.http_proxy || process.env.https_proxy
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
  # pack - The package metadata.
  # tag - The Git tag string of the package version to publish.
  # callback - The callback function to invoke when done with an error as the
  #            first argument.
  publishPackage: (pack, tag, callback) ->
    process.stdout.write "Publishing #{pack.name}@#{tag} "
    @createPackageVersion pack.name, tag, (error) ->
      if error?
        process.stdout.write '\u2717\n'.red
        callback(error)
      else
        process.stdout.write '\u2713\n'.green
        callback()

  logFirstTimePublishMessage: (pack) ->
    process.stdout.write 'Congrats on publishing a new package!'.rainbow
    # :+1: :package: :tada: when available
    if process.platform is 'darwin'
      process.stdout.write ' \uD83D\uDC4D  \uD83D\uDCE6  \uD83C\uDF89'

    process.stdout.write "\nCheck it out at https://atom.io/packages/#{pack.name}\n"

  loadMetadata: ->
    metadataPath = path.resolve('package.json')
    unless fs.isFileSync(metadataPath)
      throw new Error("No package.json file found at #{process.cwd()}/package.json")

    try
      pack = JSON.parse(fs.readFileSync(metadataPath))
    catch error
      throw new Error("Error parsing package.json file: #{error.message}")

  loadRepository: ->
    currentDirectory = process.cwd()

    repo = Git.open(currentDirectory)
    if repo?.getWorkingDirectory() isnt currentDirectory
      throw new Error('Package must be in a Git repository before publishing: https://help.github.com/articles/create-a-repo')

    unless repo.getConfigValue('remote.origin.url')
      throw new Error('Package must pushed up to GitHub before publishing: https://help.github.com/articles/create-a-repo')

  # Run the publish command with the given options
  run: (options) ->
    {callback} = options
    options = @parseOptions(options.commandArgs)
    {tag} = options.argv
    [version] = options.argv._

    try
      pack = @loadMetadata()
    catch error
      return callback(error)

    try
      @loadRepository()
    catch error
      return callback(error)

    if version?.length > 0
      @registerPackage pack, (error, firstTimePublishing) =>
        return callback(error) if error?

        @versionPackage version, (error, tag) =>
          return callback(error) if error?

          @pushVersion tag, (error) =>
            return callback(error) if error?

            @waitForTagToBeAvailable pack, tag, =>

              @publishPackage pack, tag, (error) =>
                if firstTimePublishing and not error?
                  @logFirstTimePublishMessage(pack)
                callback(error)
    else if tag?.length > 0
      @registerPackage pack, (error, firstTimePublishing) =>
        return callback(error) if error?

        @publishPackage pack, tag, (error) =>
          if firstTimePublishing and not error?
            @logFirstTimePublishMessage(pack)
          callback(error)
    else
      callback('Missing required tag to publish')
