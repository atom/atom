path = require 'path'

_ = require 'underscore-plus'
async = require 'async'
optimist = require 'optimist'
read = require 'read'
semver = require 'npm/node_modules/semver'

Command = require './command'
config = require './apm'
fs = require './fs'
Install = require './install'
Packages = require './packages'
request = require './request'
tree = require './tree'

module.exports =
class Upgrade extends Command
  @commandNames: ['upgrade', 'outdated', 'update']

  constructor: ->
    @atomDirectory = config.getAtomDirectory()
    @atomPackagesDirectory = path.join(@atomDirectory, 'packages')

  parseOptions: (argv) ->
    options = optimist(argv)
    options.usage """

      Usage: apm upgrade
             apm upgrade --list
             apm upgrade [<package_name>...]

      Upgrade out of date packages installed to ~/.atom/packages

      This command lists the out of date packages and then prompts to install
      available updates.
    """
    options.alias('c', 'confirm').boolean('confirm').default('confirm', true).describe('confirm', 'Confirm before installing updates')
    options.alias('h', 'help').describe('help', 'Print this usage message')
    options.alias('l', 'list').boolean('list').describe('list', 'List but don\'t install the outdated packages')
    options.boolean('json').describe('json', 'Output outdated packages as a JSON array')
    options.string('compatible').describe('compatible', 'Only list packages/themes compatible with this Atom version')
    options.boolean('verbose').default('verbose', false).describe('verbose', 'Show verbose debug information')

  getInstalledPackages: (options) ->
    packages = []
    for name in fs.list(@atomPackagesDirectory)
      if pack = @getIntalledPackage(name)
        packages.push(pack)

    packageNames = @packageNamesFromArgv(options.argv)
    if packageNames.length > 0
      packages = packages.filter ({name}) -> packageNames.indexOf(name) isnt -1

    packages

  getIntalledPackage: (name) ->
    packageDirectory = path.join(@atomPackagesDirectory, name)
    return if fs.isSymbolicLinkSync(packageDirectory)
    try
      metadata = JSON.parse(fs.readFileSync(path.join(packageDirectory, 'package.json')))
      return metadata if metadata?.name and metadata?.version

  loadInstalledAtomVersion: (options, callback) ->
    if options.argv.compatible
      process.nextTick =>
        version = @normalizeVersion(options.argv.compatible)
        @installedAtomVersion = version if semver.valid(version)
        callback()
    else
      config.getResourcePath (resourcePath) =>
        try
          {version} = require(path.join(resourcePath, 'package.json')) ? {}
          version = @normalizeVersion(version)
          @installedAtomVersion = version if semver.valid(version)
        callback()

  getLatestVersion: (pack, callback) ->
    requestSettings =
      url: "#{config.getAtomPackagesUrl()}/#{pack.name}"
      json: true
    request.get requestSettings, (error, response, body={}) =>
      if error?
        callback("Request for package information failed: #{error.message}")
      else if response.statusCode is 404
        callback()
      else if response.statusCode isnt 200
        message = body.message ? body.error ? body
        callback("Request for package information failed: #{message}")
      else
        atomVersion = @installedAtomVersion
        latestVersion = pack.version
        for version, metadata of body.versions ? {}
          continue unless semver.valid(version)
          continue unless metadata

          engine = metadata.engines?.atom ? '*'
          continue unless semver.validRange(engine)
          continue unless semver.satisfies(atomVersion, engine)

          latestVersion = version if semver.gt(version, latestVersion)

        if latestVersion isnt pack.version and @hasRepo(pack)
          callback(null, {pack, latestVersion})
        else
          callback()

  hasRepo: (pack) ->
    Packages.getRepository(pack)?

  getAvailableUpdates: (packages, callback) ->
    async.map packages, @getLatestVersion.bind(this), (error, updates) =>
      return callback(error) if error?

      updates = _.compact(updates)
      updates.sort (updateA, updateB) ->
        updateA.pack.name.localeCompare(updateB.pack.name)

      callback(null, updates)

  promptForConfirmation: (callback) ->
    read {prompt: 'Would you like to install these updates? (yes)', edit: true}, (error, answer) ->
      answer = if answer then answer.trim().toLowerCase() else 'yes'
      callback(error, answer is 'y' or answer is 'yes')

  installUpdates: (updates, callback) ->
    installCommands = []
    verbose = @verbose
    for {pack, latestVersion} in updates
      do (pack, latestVersion) ->
        installCommands.push (callback) ->
          commandArgs = ["#{pack.name}@#{latestVersion}"]
          commandArgs.unshift('--verbose') if verbose
          new Install().run({callback, commandArgs})

    async.waterfall(installCommands, callback)

  run: (options) ->
    {callback, command} = options
    options = @parseOptions(options.commandArgs)
    options.command = command

    @verbose = options.argv.verbose
    if @verbose
      request.debug(true)
      process.env.NODE_DEBUG = 'request'

    @loadInstalledAtomVersion options, =>
      if @installedAtomVersion
        @upgradePackages(options, callback)
      else
        callback('Could not determine current Atom version installed')

  upgradePackages: (options, callback) ->
    packages = @getInstalledPackages(options)
    @getAvailableUpdates packages, (error, updates) =>
      return callback(error) if error?

      if options.argv.json
        packagesWithLatestVersion = updates.map ({pack, latestVersion}) ->
          pack.latestVersion = latestVersion
          pack
        console.log JSON.stringify(packagesWithLatestVersion)
      else
        console.log "Package Updates Available".cyan + " (#{updates.length})"
        tree updates, ({pack, latestVersion}) ->
          "#{pack.name.yellow} #{pack.version.red} -> #{latestVersion.green}"

      return callback() if options.command is 'outdated'
      return callback() if options.argv.list
      return callback() if updates.length is 0

      console.log()
      if options.argv.confirm
        @promptForConfirmation (error, confirmed) =>
          return callback(error) if error?

          if confirmed
            console.log()
            @installUpdates(updates, callback)
          else
            callback()
      else
        @installUpdates(updates, callback)
