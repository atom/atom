_ = require 'underscore-plus'
optimist = require 'optimist'

Command = require './command'
config = require './config'
request = require './request'
tree = require './tree'

module.exports =
class Stars extends Command
  @commandNames: ['stars', 'starred']

  parseOptions: (argv) ->
    options = optimist(argv)
    options.usage """

      Usage: apm stars
             apm stars --install
             apm stars --user thedaniel
             apm stars --themes

      List or install starred Atom packages and themes.
    """
    options.alias('h', 'help').describe('help', 'Print this usage message')
    options.alias('i', 'install').boolean('install').describe('install', 'Install the starred packages')
    options.alias('t', 'themes').boolean('themes').describe('themes', 'Only list themes')
    options.alias('u', 'user').string('user').describe('user', 'GitHub username')
    options.boolean('json').describe('json', 'Output packages as a JSON array')

  getStarredPackages: (user, callback) ->
    requestSettings = json: true

    if user
      requestSettings.url = "#{config.getAtomApiUrl()}/users/#{user}/stars"
    else
      requestSettings.url = "#{config.getAtomApiUrl()}/stars"

    request.get requestSettings, (error, response, body={}) ->
      if error?
        callback(error)
      else if response.statusCode is 200
        packages = body.filter (pack) -> pack.releases?.latest?
        packages = packages.map ({readme, metadata, downloads}) -> _.extend({}, metadata, {readme, downloads})
        packages = _.sortBy(packages, 'name')
        callback(null, packages)
      else
        message = body.message ? body.error ? body
        callback("Requesting packages failed: #{message}")

  run: (options) ->
    {callback} = options
    options = @parseOptions(options.commandArgs)

    user = options.argv.user?.toString().trim()

    @getStarredPackages user, (error, packages) ->
      if error?
        callback(error)
        return

      if options.argv.themes
        packages = packages.filter ({theme}) -> theme

      if options.argv.json
        console.log(JSON.stringify(packages))
      else
        if options.argv.themes
          label = "Themes starred by #{user}"
        else
          label = "Packages starred by #{user}"
        console.log "#{label.cyan} (#{packages.length})"

        tree packages, ({name, version, description, downloads}) ->
          label = name.yellow
          label += " #{description.replace(/\s+/g, ' ')}" if description
          label += " (#{_.pluralize(downloads, 'download')})".grey if downloads >= 0
          label

        console.log()
        console.log "Use `apm install` to install them or visit #{'http://atom.io/packages'.underline} to read more about them."
        console.log()

      callback()
