_ = require 'underscore-plus'
optimist = require 'optimist'
request = require 'request'

auth = require './auth'
Command = require './command'
config = require './config'
tree = require './tree'

module.exports =
class Search extends Command
  @commandNames: ['search']

  parseOptions: (argv) ->
    options = optimist(argv)
    options.usage """

      Usage: apm search <package_name>

      Search for Atom packages/themes on the atom.io registry.
    """
    options.alias('h', 'help').describe('help', 'Print this usage message')
    options.boolean('json').describe('json', 'Output featured packages as JSON array')

  searchPackages: (query, callback) ->
    auth.getToken (error, token) ->
      if error?
        callback(error)
      else
        requestSettings =
          url: "#{config.getAtomPackagesUrl()}/search"
          qs:
            q: query
          json: true
          proxy: process.env.http_proxy || process.env.https_proxy
          headers:
            authorization: token

        request.get requestSettings, (error, response, body={}) ->
          if error?
            callback(error)
          else if response.statusCode is 200
            packages = body.filter (pack) -> pack.releases?.latest?
            packages = packages.map ({readme, metadata}) -> _.extend({}, metadata, {readme})
            packages = _.sortBy(packages, 'name')
            callback(null, packages)
          else
            message = body.message ? body.error ? body
            callback("Searching packages failed: #{message}")

  run: (options) ->
    {callback} = options
    options = @parseOptions(options.commandArgs)
    [query] = options.argv._

    unless query
      callback("Missing required search query")
      return

    @searchPackages query, (error, packages) ->
      if error?
        callback(error)
        return

      if options.argv.json
        console.log(JSON.stringify(packages))
      else
        heading = "Search Results For '#{query}'".cyan
        console.log "#{heading} (#{packages.length})"

        tree packages, ({name, version, description}) ->
          label = name.yellow
          label += " #{description.replace(/[\r\n\t ]+/g, ' ')}" if description
          label

        console.log()
        console.log "Use `apm install` to install them or visit #{'http://atom.io/packages'.underline} to read more about them."
        console.log()

      callback()
