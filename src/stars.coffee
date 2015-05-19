_ = require 'underscore-plus'
yargs = require 'yargs'

Command = require './command'
config = require './apm'
Install = require './install'
Login = require './login'
request = require './request'
tree = require './tree'

module.exports =
class Stars extends Command
  @commandNames: ['stars', 'starred']

  parseOptions: (argv) ->
    options = yargs(argv).wrap(100)
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
    options.alias('u', 'user').string('user').describe('user', 'GitHub username to show starred packages for')
    options.boolean('json').describe('json', 'Output packages as a JSON array')

  getStarredPackages: (user, atomVersion, callback) ->
    requestSettings = json: true
    requestSettings.qs = engine: atomVersion if atomVersion

    if user
      requestSettings.url = "#{config.getAtomApiUrl()}/users/#{user}/stars"
      @requestStarredPackages(requestSettings, callback)
    else
      requestSettings.url = "#{config.getAtomApiUrl()}/stars"
      Login.getTokenOrLogin (error, token) =>
        return callback(error) if error?

        requestSettings.headers = authorization: token
        @requestStarredPackages(requestSettings, callback)

  requestStarredPackages: (requestSettings, callback) ->
    request.get requestSettings, (error, response, body=[]) ->
      if error?
        callback(error)
      else if response.statusCode is 200
        packages = body.filter (pack) -> pack?.releases?.latest?
        packages = packages.map ({readme, metadata, downloads, stargazers_count}) -> _.extend({}, metadata, {readme, downloads, stargazers_count})
        packages = _.sortBy(packages, 'name')
        callback(null, packages)
      else
        message = request.getErrorMessage(response, body)
        callback("Requesting packages failed: #{message}")

  installPackages: (packages, callback) ->
    return callback() if packages.length is 0

    commandArgs = packages.map ({name}) -> name
    new Install().run({commandArgs, callback})

  logPackagesAsJson: (packages, callback) ->
    console.log(JSON.stringify(packages))
    callback()

  logPackagesAsText: (user, packagesAreThemes, packages, callback) ->
    userLabel = user ? 'you'
    if packagesAreThemes
      label = "Themes starred by #{userLabel}"
    else
      label = "Packages starred by #{userLabel}"
    console.log "#{label.cyan} (#{packages.length})"

    tree packages, ({name, version, description, downloads, stargazers_count}) ->
      label = name.yellow
      label = "\u2B50  #{label}" if process.platform is 'darwin'
      label += " #{description.replace(/\s+/g, ' ')}" if description
      label += " (#{_.pluralize(downloads, 'download')}, #{_.pluralize(stargazers_count, 'star')})".grey if downloads >= 0 and stargazers_count >= 0
      label

    console.log()
    console.log "Use `apm stars --install` to install them all or visit #{'http://atom.io/packages'.underline} to read more about them."
    console.log()
    callback()

  run: (options) ->
    {callback} = options
    options = @parseOptions(options.commandArgs)
    user = options.argv.user?.toString().trim()

    @getStarredPackages user, options.argv.compatible,  (error, packages) =>
      return callback(error) if error?

      if options.argv.themes
        packages = packages.filter ({theme}) -> theme

      if options.argv.install
        @installPackages(packages, callback)
      else if options.argv.json
        @logPackagesAsJson(packages, callback)
      else
        @logPackagesAsText(user, options.argv.themes, packages, callback)
