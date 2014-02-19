_ = require 'underscore-plus'
optimist = require 'optimist'
request = require 'request'

auth = require './auth'
Command = require './command'
config = require './config'
tree = require './tree'

module.exports =
class Search extends Command
  @commandNames: ['view', 'show']

  parseOptions: (argv) ->
    options = optimist(argv)
    options.usage """

      Usage: apm view <package_name>

      View information about a package/theme in the atom.io registry.
    """
    options.alias('h', 'help').describe('help', 'Print this usage message')
    options.boolean('json').describe('json', 'Output featured packages as JSON array')

  getPackage: (packageName, callback) ->
    auth.getToken (error, token) ->
      if error?
        callback(error)
      else
        requestSettings =
          url: "#{config.getAtomPackagesUrl()}/#{packageName}"
          json: true
          proxy: process.env.http_proxy || process.env.https_proxy
          headers:
            authorization: token

        request.get requestSettings, (error, response, body={}) ->
          if error?
            callback(error)
          else if response.statusCode is 200
            callback(null, body)
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

    @getPackage packageName, (error, pack) ->
      if error?
        callback(error)
        return

      if options.argv.json
        console.log(JSON.stringify(pack, null, 2))
      else
        console.log "#{pack.name.cyan}"
        if version = pack.releases?.latest
          items = []
          items.push(version.yellow)
          items.push(pack.repository.url.underline) if pack.repository.url
          {description} = pack.versions?[version] ? {}
          items.push(description.replace(/\s+/g, ' ')) if description
          tree(items)

        console.log()
        console.log "Run `apm install #{pack.name}` to install this package."
        console.log()

      callback()
