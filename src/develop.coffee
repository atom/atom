fs = require 'fs'
path = require 'path'

_ = require 'underscore-plus'
optimist = require 'optimist'

config = require './apm'
Command = require './command'
Install = require './install'
git = require './git'
Link = require './link'
request = require './request'

module.exports =
class Develop extends Command
  @commandNames: ['dev', 'develop']

  constructor: ->
    @atomDirectory = config.getAtomDirectory()
    @atomDevPackagesDirectory = path.join(@atomDirectory, 'dev', 'packages')

  parseOptions: (argv) ->
    options = optimist(argv)

    options.usage """
      Usage: apm develop <package_name> [<directory>]

      Clone the given package's Git repository to the directory specified,
      install its dependencies, and link it for development to
      ~/.atom/dev/packages/<package_name>.

      If no directory is specified then the repository is cloned to
      ~/github/<package_name>. The default folder to clone packages into can
      be overridden using the ATOM_REPOS_HOME environment variable.

      Once this command completes you can open a dev window from atom using
      cmd-shift-o to run the package out of the newly cloned repository.
    """
    options.alias('h', 'help').describe('help', 'Print this usage message')

  getRepositoryUrl: (packageName, callback) ->
    requestSettings =
      url: "#{config.getAtomPackagesUrl()}/#{packageName}"
      json: true
    request.get requestSettings, (error, response, body={}) ->
      if error?
        callback("Request for package information failed: #{error.message}")
      else if response.statusCode is 200
        if repositoryUrl = body.repository.url
          callback(null, repositoryUrl)
        else
          callback("No repository URL found for package: #{packageName}")
      else
        message = request.getErrorMessage(response, body)
        callback("Request for package information failed: #{message}")

  cloneRepository: (repoUrl, packageDirectory, options) ->
    config.getSetting 'git', (command) =>
      command ?= 'git'
      args = ['clone', '--recursive', repoUrl, packageDirectory]
      process.stdout.write "Cloning #{repoUrl} "
      git.addGitToEnv(process.env)
      @spawn command, args, (code, stderr='', stdout='') =>
        if code is 0
          @logSuccess()
          @installDependencies(packageDirectory, options)
        else
          @logFailure()
          options.callback("#{stdout}\n#{stderr}".trim())

  installDependencies: (packageDirectory, options) ->
    process.chdir(packageDirectory)
    installOptions = _.clone(options)
    installOptions.callback = (error) =>
      if error?
        options.callback(error)
      else
        @linkPackage(packageDirectory, options)

    new Install().run(installOptions)

  linkPackage: (packageDirectory, options) ->
    linkOptions = _.clone(options)
    linkOptions.commandArgs = [packageDirectory, '--dev']
    new Link().run(linkOptions)

  run: (options) ->
    packageName = options.commandArgs.shift()

    unless packageName?.length > 0
      return options.callback("Missing required package name")

    packageDirectory = options.commandArgs.shift() ? path.join(config.getReposDirectory(), packageName)
    packageDirectory = path.resolve(packageDirectory)

    if fs.existsSync(packageDirectory)
      @linkPackage(packageDirectory, options)
    else
      @getRepositoryUrl packageName, (error, repoUrl) =>
        if error?
          options.callback(error)
        else
          @cloneRepository repoUrl, packageDirectory, options
