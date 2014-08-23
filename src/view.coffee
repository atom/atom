_ = require 'underscore-plus'
optimist = require 'optimist'

Command = require './command'
config = require './config'
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

  getRepository: (pack) ->
    if repository = pack.repository?.url ? pack.repository
      repository.replace(/\.git$/, '')

  getPackage: (packageName, callback) ->
    requestSettings =
      url: "#{config.getAtomPackagesUrl()}/#{packageName}"
      json: true
    request.get requestSettings, (error, response, body={}) ->
      if error?
        callback(error)
      else if response.statusCode is 200
        {metadata, readme, repository, downloads, stargazers_count} = body
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

    @getPackage packageName, (error, pack) =>
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
