_ = require 'underscore'
optimist = require 'optimist'
request = require 'request'
npmconf = require 'npmconf'
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
          else
            packages = body.filter (pack) -> pack['dist-tags']?.latest?
            packages = packages.map (pack) ->
              _.extend(version: pack['dist-tags'].latest, pack)
            callback(null, packages)

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
