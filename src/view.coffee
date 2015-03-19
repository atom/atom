_ = require 'underscore-plus'
optimist = require 'optimist'
semver = require 'npm/node_modules/semver'

Command = require './command'
config = require './apm'
request = require './request'
tree = require './tree'

module.exports =
class View extends Command
  @commandNames: ['view', 'show']

  parseOptions: (argv) ->
    options = optimist(argv)
    options.usage """

      Usage: apm view <package_name>

      View information about a package/theme in the atom.io registry.
    """
    options.alias('h', 'help').describe('help', 'Print this usage message')
    options.boolean('json').describe('json', 'Output featured packages as JSON array')
    options.string('compatible').describe('compatible', 'Show the latest version compatible with this Atom version')

  loadInstalledAtomVersion: (options, callback) ->
    process.nextTick =>
      if options.argv.compatible
        version = @normalizeVersion(options.argv.compatible)
        installedAtomVersion = version if semver.valid(version)
      callback(installedAtomVersion)

  getLatestCompatibleVersion: (pack, options, callback) ->
    @loadInstalledAtomVersion options, (installedAtomVersion) =>
      return callback(pack.releases.latest) unless installedAtomVersion

      latestVersion = null
      for version, metadata of pack.versions ? {}
        continue unless semver.valid(version)
        continue unless metadata

        engine = metadata.engines?.atom ? '*'
        continue unless semver.validRange(engine)
        continue unless semver.satisfies(installedAtomVersion, engine)

        latestVersion ?= version
        latestVersion = version if semver.gt(version, latestVersion)

      callback(latestVersion)

  getRepository: (pack) ->
    if repository = pack.repository?.url ? pack.repository
      repository.replace(/\.git$/, '')

  getPackage: (packageName, options, callback) ->
    requestSettings =
      url: "#{config.getAtomPackagesUrl()}/#{packageName}"
      json: true
    request.get requestSettings, (error, response, body={}) =>
      if error?
        callback(error)
      else if response.statusCode is 200
        @getLatestCompatibleVersion body, options, (version) ->
          {name, readme, downloads, stargazers_count} = body
          metadata = body.versions?[version] ? {name}
          pack = _.extend({}, metadata, {readme, downloads, stargazers_count})
          callback(null, pack)
      else
        message = body.message ? body.error ? body
        callback("Requesting package failed: #{message}")

  run: (options) ->
    {callback} = options
    options = @parseOptions(options.commandArgs)
    [packageName] = options.argv._

    unless packageName
      callback("Missing required package name")
      return

    @getPackage packageName, options, (error, pack) =>
      if error?
        callback(error)
        return

      if options.argv.json
        console.log(JSON.stringify(pack, null, 2))
      else
        console.log "#{pack.name.cyan}"
        items = []
        items.push(pack.version.yellow) if pack.version
        if repository = @getRepository(pack)
          items.push(repository.underline)
        items.push(pack.description.replace(/\s+/g, ' ')) if pack.description
        if pack.downloads >= 0
          items.push(_.pluralize(pack.downloads, 'download'))
        if pack.stargazers_count >= 0
          items.push(_.pluralize(pack.stargazers_count, 'star'))

        tree(items)

        console.log()
        console.log "Run `apm install #{pack.name}` to install this package."
        console.log()

      callback()
