path = require 'path'

_ = require 'underscore-plus'
async = require 'async'
optimist = require 'optimist'
request = require 'request'
semver = require 'semver'

Command = require './command'
config = require './config'
fs = require './fs'
tree = require './tree'

module.exports =
class Upgrade extends Command
  @commandNames: ['upgrade']

  constructor: ->
    @atomDirectory = config.getAtomDirectory()
    @atomPackagesDirectory = path.join(@atomDirectory, 'packages')

  parseOptions: (argv) ->
    options = optimist(argv)
    options.usage """

      Usage: apm upgrade [<package_name>...]

      Upgrade packages installed to ~/.atom/packages.

      All packages are upgraded if no package names are passed as arguments.
    """
    options.alias('h', 'help').describe('help', 'Print this usage message')
    options.alias('c', 'confirm').boolean('confirm').default('confirm', true).describe('confirm', 'Confirm before install updates')
    options.alias('l', 'list').boolean('list').describe('list', 'List the packages that have updates available')
    options.alias('q', 'quiet').boolean('quiet').describe('quiet', 'Set the npm log level to warn')

  getInstalledPackages: ->
    packages = []
    for child in fs.list(@atomPackagesDirectory)
      continue if fs.isSymbolicLinkSync(path.join(@atomPackagesDirectory, child))
      try
        metadata = JSON.parse(fs.readFileSync(path.join(@atomPackagesDirectory, child, 'package.json')))
        packages.push(metadata)
    packages = packages.filter ({name, version}={}) ->
      name and semver.valid(version)
    packages

  getInstalledAtomVersion: ->
    try
      @installedAtomVerson ?= JSON.parse(fs.readFileSync(path.join(config.getResourcePath(), 'package.json')))?.version

  getLatestVersion: (pack, callback) ->
    requestSettings =
      url: "#{config.getAtomPackagesUrl()}/#{pack.name}"
      json: true
      proxy: process.env.http_proxy || process.env.https_proxy
    request.get requestSettings, (error, response, body={}) =>
      if error?
        callback("Request for package information failed: #{error.message}")
      else if response.statusCode is 404
        callback()
      else if response.statusCode isnt 200
        message = body.message ? body.error ? body
        callback("Request for package information failed: #{message}")
      else
        atomVersion = @getInstalledAtomVersion()
        latestVersion = pack.version
        for version, metadata of body.versions ? {}
          continue unless semver.valid(version)
          continue unless metadata

          engine = metadata.engines?.atom ? '*'
          continue unless semver.validRange(engine)
          continue unless semver.satisfies(atomVersion, engine)

          latestVersion = version if semver.gt(version, latestVersion)

        if latestVersion isnt pack.version
          callback(null, {pack, latestVersion})
        else
          callback()

  run: (options) ->
    {callback} = options
    options = @parseOptions(options.commandArgs)

    unless @getInstalledAtomVersion()
      return callback('Could not determine current Atom version installed')

    if options.argv.list
      packages = @getInstalledPackages()
      async.map packages, @getLatestVersion.bind(this), (error, updates) ->
        return callback(error) if error?

        updates = _.compact(updates)
        updates.sort (updateA, updateB) ->
          updateA.name.localeCompare(updateB.name)

        console.log "Package Updates Available".cyan + " (#{updates.length})"
        tree updates, ({pack, latestVersion}) ->
          "#{pack.name.yellow} #{pack.version.red} -> #{latestVersion.green}"
