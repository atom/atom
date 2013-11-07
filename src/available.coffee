_ = require 'underscore-plus'
optimist = require 'optimist'
request = require 'request'
semver = require 'semver'

auth = require './auth'
config = require './config'
tree = require './tree'

module.exports =
class Available
  @commandNames: ['available']

  parseOptions: (argv) ->
    options = optimist(argv)
    options.usage """

      Usage: apm available

      List all the Atom packages that have been published to the apm registry.
    """
    options.alias('h', 'help').describe('help', 'Print this usage message')
    options.boolean('json').describe('json', 'Output available packages as JSON array')

  showHelp: (argv) -> @parseOptions(argv).showHelp()

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
            callback(null, packages)
          else
            message = body.message ? body.error ? body
            callback("Requesting packages failed: #{message}")

  run: (options) ->
    @getAvailablePackages options.argv.atomVersion, (error, packages) ->
      if error?
        options.callback(error)
      else
        if options.argv.json
          console.log(JSON.stringify(packages))
        else
          console.log "#{'Available Atom packages'.cyan} (#{packages.length})"
          tree packages, ({name, version}) ->
            "#{name}@#{version}"
        options.callback()
