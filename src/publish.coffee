path = require 'path'
url = require 'url'

yargs = require 'yargs'
Git = require 'git-utils'
semver = require 'semver'

fs = require './fs'
config = require './apm'
Command = require './command'
Login = require './login'
Packages = require './packages'
request = require './request'

module.exports =
class Publish extends Command
  @commandNames: ['publish']

  constructor: ->
    @userConfigPath = config.getUserConfigPath()
    @atomNpmPath = require.resolve('npm/bin/npm-cli')

  parseOptions: (argv) ->
    options = yargs(argv).wrap(100)
    options.usage """

      Usage: apm publish [<newversion> | major | minor | patch | build]
             apm publish --tag <tagname>
             apm publish --rename <new-name>

      Publish a new version of the package in the current working directory.

      If a new version or version increment is specified, then a new Git tag is
      created and the package.json file is updated with that new version before
      it is published to the apm registry. The HEAD branch and the new tag are
      pushed up to the remote repository automatically using this option.

      If a new name is provided via the --rename flag, the package.json file is
      updated with the new name and the package's name is updated on Atom.io.

      Run `apm featured` to see all the featured packages or
      `apm view <packagename>` to see information about your package after you
      have published it.
    """
    options.alias('h', 'help').describe('help', 'Print this usage message')
    options.alias('t', 'tag').string('tag').describe('tag', 'Specify a tag to publish')
    options.alias('r', 'rename').string('rename').describe('rename', 'Specify a new name for the package')

  # Create a new version and tag use the `npm version` command.
  #
  # version  - The new version or version increment.
  # callback - The callback function to invoke with an error as the first
  #            argument and a the generated tag string as the second argument.
  versionPackage: (version, callback) ->
    process.stdout.write 'Preparing and tagging a new version '
    versionArgs = ['version', version, '-m', 'Prepare %s release']
    @fork @atomNpmPath, versionArgs, (code, stderr='', stdout='') =>
      if code is 0
        @logSuccess()
        callback(null, stdout.trim())
      else
        @logFailure()
        callback("#{stdout}\n#{stderr}".trim())

  # Push a tag to the remote repository.
  #
  #  tag - The tag to push.
  #  callback - The callback function to invoke with an error as the first
  #             argument.
  pushVersion: (tag, callback) ->
    process.stdout.write "Pushing #{tag} tag "
    pushArgs = ['push', 'origin', 'HEAD', tag]
    @spawn 'git', pushArgs, (args...) =>
      @logCommandResults(callback, args...)

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
    retryCount = 5
    interval = 1000
    requestSettings =
      url: "https://api.github.com/repos/#{Packages.getRepository(pack)}/tags"
      json: true

    requestTags = ->
      request.get requestSettings, (error, response, tags=[]) ->
        if response?.statusCode is 200
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
    Login.getTokenOrLogin (error, token) ->
      return callback(error) if error?

      requestSettings =
        url: "#{config.getAtomPackagesUrl()}/#{packageName}"
        json: true
        headers:
          authorization: token
      request.get requestSettings, (error, response, body={}) ->
        if error?
          callback(error)
        else
          callback(null, response.statusCode is 200)

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

      unless repository = Packages.getRepository(pack)
        callback('Unable to parse repository name/owner from package.json repository field')
        return

      process.stdout.write "Registering #{pack.name} "
      Login.getTokenOrLogin (error, token) =>
        if error?
          @logFailure()
          callback(error)
          return

        requestSettings =
          url: config.getAtomPackagesUrl()
          json: true
          body:
            repository: repository
          headers:
            authorization: token
        request.post requestSettings, (error, response, body={}) =>
          if error?
            callback(error)
          else if response.statusCode isnt 201
            message = request.getErrorMessage(response, body)
            @logFailure()
            callback("Registering package in #{repository} repository failed: #{message}")
          else
            @logSuccess()
            callback(null, true)

  # Create a new package version at the given Git tag.
  #
  # packageName - The string name of the package.
  # tag - The string Git tag of the new version.
  # callback - The callback function to invoke with an error as the first
  #            argument.
  createPackageVersion: (packageName, tag, options, callback) ->
    Login.getTokenOrLogin (error, token) ->
      if error?
        callback(error)
        return

      requestSettings =
        url: "#{config.getAtomPackagesUrl()}/#{packageName}/versions"
        json: true
        body:
          tag: tag
          rename: options.rename
        headers:
          authorization: token
      request.post requestSettings, (error, response, body={}) ->
        if error?
          callback(error)
        else if response.statusCode isnt 201
          message = request.getErrorMessage(response, body)
          callback("Creating new version failed: #{message}")
        else
          callback()

  # Publish the version of the package associated with the given tag.
  #
  # pack - The package metadata.
  # tag - The Git tag string of the package version to publish.
  # options - An options Object (optional).
  # callback - The callback function to invoke when done with an error as the
  #            first argument.
  publishPackage: (pack, tag, remaining...) ->
    options = remaining.shift() if remaining.length >= 2
    options ?= {}
    callback = remaining.shift()

    process.stdout.write "Publishing #{options.rename or pack.name}@#{tag} "
    @createPackageVersion pack.name, tag, options, (error) =>
      if error?
        @logFailure()
        callback(error)
      else
        @logSuccess()
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

  saveMetadata: (pack, callback) ->
    metadataPath = path.resolve('package.json')
    metadataJson = JSON.stringify(pack, null, 2)
    fs.writeFile(metadataPath, "#{metadataJson}\n", callback)

  loadRepository: ->
    currentDirectory = process.cwd()

    repo = Git.open(currentDirectory)
    unless repo?.isWorkingDirectory(currentDirectory)
      throw new Error('Package must be in a Git repository before publishing: https://help.github.com/articles/create-a-repo')


    if currentBranch = repo.getShortHead()
      remoteName = repo.getConfigValue("branch.#{currentBranch}.remote")
    remoteName ?= repo.getConfigValue('branch.master.remote')

    upstreamUrl = repo.getConfigValue("remote.#{remoteName}.url") if remoteName
    upstreamUrl ?= repo.getConfigValue('remote.origin.url')

    unless upstreamUrl
      throw new Error('Package must pushed up to GitHub before publishing: https://help.github.com/articles/create-a-repo')

  # Rename package if necessary
  renamePackage: (pack, name, callback) ->
    if name?.length > 0
      return callback('The new package name must be different than the name in the package.json file') if pack.name is name

      message = "Renaming #{pack.name} to #{name} "
      process.stdout.write(message)
      @setPackageName pack, name, (error) =>
        if error?
          @logFailure()
          return callback(error)

        config.getSetting 'git', (gitCommand) =>
          gitCommand ?= 'git'
          @spawn gitCommand, ['add', 'package.json'], (code, stderr='', stdout='') =>
            unless code is 0
              @logFailure()
              addOutput = "#{stdout}\n#{stderr}".trim()
              return callback("`git add package.json` failed: #{addOutput}")

            @spawn gitCommand, ['commit', '-m', message], (code, stderr='', stdout='') =>
              if code is 0
                @logSuccess()
                callback()
              else
                @logFailure()
                commitOutput = "#{stdout}\n#{stderr}".trim()
                callback("Failed to commit package.json: #{commitOutput}")
    else
      # Just fall through if the name is empty
      callback()

  setPackageName: (pack, name, callback) ->
    pack.name = name
    @saveMetadata(pack, callback)

  validateSemverRanges: (pack) ->
    return unless pack

    isValidRange = (semverRange) ->
      return true if semver.validRange(semverRange)

      try
        return true if url.parse(semverRange).protocol.length > 0

      semverRange is 'latest'

    if pack.engines?.atom?
      unless semver.validRange(pack.engines.atom)
        throw new Error("The Atom engine range in the package.json file is invalid: #{pack.engines.atom}")

    for packageName, semverRange of pack.dependencies
      unless isValidRange(semverRange)
        throw new Error("The #{packageName} dependency range in the package.json file is invalid: #{semverRange}")

    for packageName, semverRange of pack.devDependencies
      unless isValidRange(semverRange)
        throw new Error("The #{packageName} dev dependency range in the package.json file is invalid: #{semverRange}")

    return

  # Run the publish command with the given options
  run: (options) ->
    {callback} = options
    options = @parseOptions(options.commandArgs)
    {tag, rename} = options.argv
    [version] = options.argv._

    try
      pack = @loadMetadata()
    catch error
      return callback(error)

    try
      @validateSemverRanges(pack)
    catch error
      return callback(error)

    try
      @loadRepository()
    catch error
      return callback(error)

    if version?.length > 0 or rename?.length > 0
      version = 'patch' unless version?.length > 0
      originalName = pack.name if rename?.length > 0

      @registerPackage pack, (error, firstTimePublishing) =>
        return callback(error) if error?

        @renamePackage pack, rename, (error) =>
          return callback(error) if error?

          @versionPackage version, (error, tag) =>
            return callback(error) if error?

            @pushVersion tag, (error) =>
              return callback(error) if error?

              @waitForTagToBeAvailable pack, tag, =>

                if originalName?
                  # If we're renaming a package, we have to hit the API with the
                  # current name, not the new one, or it will 404.
                  rename = pack.name
                  pack.name = originalName
                @publishPackage pack, tag, {rename},  (error) =>
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
      callback('A version, tag, or new package name is required')
