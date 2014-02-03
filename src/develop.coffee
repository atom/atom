fs = require 'fs'
path = require 'path'

_ = require 'underscore-plus'
optimist = require 'optimist'
request = require 'request'

auth = require './auth'
config = require './config'
Command = require './command'
Install = require './install'
Link = require './link'

module.exports =
class Develop extends Command
  @commandNames: ['dev', 'develop']

  atomDirectory: null
  atomDevPackagesDirectory: null

  constructor: ->
    @atomDirectory = config.getAtomDirectory()
    @atomDevPackagesDirectory = path.join(@atomDirectory, 'dev', 'packages')

  parseOptions: (argv) ->
    options = optimist(argv)

    options.usage """
      Usage: apm develop <package_name>

      Clone the given package's Git repository to ~/github/<package_name>,
      install its dependencies, and link it for development to
      ~/.atom/packages/dev/<package_name>.

      Once this command completes you can open a dev window from atom using
      cmd-shift-o to run the package out of the newly cloned repository.
    """
    options.alias('h', 'help').describe('help', 'Print this usage message')

  getRepositoryUrl: (packageName, callback) ->
    auth.getToken (error, token) ->
      if error?
        callback(error)
        return

      requestSettings =
        url: "#{config.getAtomPackagesUrl()}/#{packageName}"
        json: true
        proxy: process.env.http_proxy || process.env.https_proxy
        headers:
          authorization: token
      request.get requestSettings, (error, response, body={}) ->
        if error?
          callback("Request for package information failed: #{error.message}")
        else if response.statusCode is 200
          if repositoryUrl = body.repository.url
            callback(null, repositoryUrl)
          else
            callback("No repository URL found for package: #{packageName}")
        else
          message = body.message ? body.error ? body
          callback("Request for package information failed: #{message}")


  cloneRepository: (repoUrl, packageDirectory, options) ->
    command = "git"
    args = ['clone', '--recursive', repoUrl, packageDirectory]
    process.stdout.write "Cloning #{repoUrl} "
    @spawn command, args, (code, stderr='', stdout='') =>
      if code is 0
        process.stdout.write '\u2713\n'.green
        @installDependencies(packageDirectory, options)
      else
        process.stdout.write '\u2717\n'.red
        options.callback("#{stdout}\n#{stderr}")

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
    packageDirectory = path.join(config.getReposDirectory(), packageName)

    if fs.existsSync(packageDirectory)
      @linkPackage(packageDirectory, options)
    else
      @getRepositoryUrl packageName, (error, repoUrl) =>
        if error?
          options.callback(error)
        else
          @cloneRepository repoUrl, packageDirectory, options
