_ = require 'underscore'
optimist = require 'optimist'
request = require 'request'
npmconf = require 'npmconf'
semver = require 'semver'

config = require './config'
tree = require './tree'

module.exports =
class Fetcher
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

    npmconf.load config.getUserConfigPath(), (error, userConfig) ->
      if error?
        callback(error)
      else
        requestSettings =
          url: config.getAtomPackagesUrl()
          json: true
          auth:
            username: userConfig.get('username', 'builtin')
            password: userConfig.get('_password', 'builtin')
            sendImmediately: true
        request.get requestSettings, (error, response, body={}) ->
          if error?
            callback(error)
          else
            packages = body.rows ? []
            packages = _.map packages, (pack) ->
              bestMatch = null
              for metadata in _.values(pack.value.releases)
                if atomVersion?
                  continue unless semver.satisfies(atomVersion, metadata.engines.atom)
                if bestMatch?
                  bestMatch = metadata if semver.gt(metadata.version, bestMatch.version)
                else
                  bestMatch = metadata
              bestMatch

            callback(null, _.compact(packages))

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
