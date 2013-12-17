_ = require 'underscore-plus'
optimist = require 'optimist'
request = require 'request'

auth = require './auth'
Command = require './command'
config = require './config'
tree = require './tree'

module.exports =
class Available extends Command
  @commandNames: ['available']

  parseOptions: (argv) ->
    options = optimist(argv)
    options.usage """

      Usage: apm available

      List all the Atom packages that have been published to the apm registry.
    """
    options.alias('h', 'help').describe('help', 'Print this usage message')
    options.alias('t', 'themes').describe('themes', 'Only list themes')
    options.boolean('json').describe('json', 'Output available packages as JSON array')

  getAvailablePackages: (atomVersion, callback) ->
    [callback, atomVersion] = [atomVersion, null] if _.isFunction(atomVersion)

    auth.getToken (error, token) ->
      if error?
        callback(error)
      else
        requestSettings =
          url: config.getAtomPackagesUrl()
          json: true
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
            callback("Requesting packages failed: #{message}")

  run: (options) ->
    {callback} = options
    options = @parseOptions(options.commandArgs)

    @getAvailablePackages options.argv.atomVersion, (error, packages) ->
      if error?
        callback(error)
        return

      if options.argv.json
        console.log(JSON.stringify(packages))
      else
        if options.argv.themes
          packages = packages.filter ({theme}) -> theme
          console.log "#{'Available Atom themes'.cyan} (#{packages.length})"
        else
          console.log "#{'Available Atom packages'.cyan} (#{packages.length})"

        tree packages, ({name, version}) -> "#{name}@#{version}"

      callback()
