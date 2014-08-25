_ = require 'underscore-plus'
optimist = require 'optimist'

Command = require './command'
config = require './config'
request = require './request'
tree = require './tree'

module.exports =
class Featured extends Command
  @commandNames: ['featured']

  parseOptions: (argv) ->
    options = optimist(argv)
    options.usage """

      Usage: apm featured
             apm featured --themes
             apm featured --compatible 0.49.0

      List the Atom packages/themes that are currently featured in the atom.io
      registry.
    """
    options.alias('h', 'help').describe('help', 'Print this usage message')
    options.alias('t', 'themes').boolean('themes').describe('themes', 'Only list themes')
    options.alias('c', 'compatible').string('compatible').describe('compatible', 'Only list packages/themes compatible with this Atom version')
    options.boolean('json').describe('json', 'Output featured packages as JSON array')

  getFeaturedPackages: (atomVersion, callback) ->
    [callback, atomVersion] = [atomVersion, null] if _.isFunction(atomVersion)

    requestSettings =
      url: "#{config.getAtomPackagesUrl()}/featured"
      json: true
    requestSettings.qs = engine: atomVersion if atomVersion

    request.get requestSettings, (error, response, body=[]) ->
      if error?
        callback(error)
      else if response.statusCode is 200
        packages = body.filter (pack) -> pack?.releases?.latest?
        packages = packages.map ({readme, metadata, downloads, stargazers_count}) -> _.extend({}, metadata, {readme, downloads, stargazers_count})
        packages = _.sortBy(packages, 'name')
        callback(null, packages)
      else
        message = body.message ? body.error ? body
        callback("Requesting packages failed: #{message}")

  run: (options) ->
    {callback} = options
    options = @parseOptions(options.commandArgs)

    @getFeaturedPackages options.argv.compatible, (error, packages) ->
      if error?
        callback(error)
        return

      if options.argv.themes
        packages = packages.filter ({theme}) -> theme

      if options.argv.json
        console.log(JSON.stringify(packages))
      else
        if options.argv.themes
          console.log "#{'Featured Atom Themes'.cyan} (#{packages.length})"
        else
          console.log "#{'Featured Atom Packages'.cyan} (#{packages.length})"

        tree packages, ({name, version, description, downloads, stargazers_count}) ->
          label = name.yellow
          label += " #{description.replace(/\s+/g, ' ')}" if description
          label += " (#{_.pluralize(downloads, 'download')}, #{_.pluralize(stargazers_count, 'star')})".grey if downloads >= 0 and stargazers_count >= 0
          label

        console.log()
        console.log "Use `apm install` to install them or visit #{'http://atom.io/packages'.underline} to read more about them."
        console.log()

      callback()
