fs = require 'fs'
path = require 'path'

async = require 'async'
_ = require 'underscore'
mkdir = require('mkdirp').sync
npm = require 'npm'
npmconf = require 'npmconf'
optimist = require 'optimist'
temp = require 'temp'
cp = require('wrench').copyDirSyncRecursive
rm = require('rimraf').sync
require 'colors'

config = require './config'
Command = require './command'
Linker = require './linker'

module.exports =
class Developer extends Command
  @commandNames: ['dev', 'develop']

  atomDirectory: null
  atomDevPackagesDirectory: null

  constructor: ->
    @atomDirectory = config.getAtomDirectory()
    @atomDevPackagesDirectory = path.join(@atomDirectory, 'dev', 'packages')

  parseOptions: (argv) ->
    options = optimist(argv)

    options.usage """
      Usage: apm develop <name>

      Clone the given package's Git repository to ~/github/<name> and link it
      for development to ~/.atom/packages/dev/<name>.

      Once this command completes you can open a dev window from atom using
      cmd-shift-o to run the package out of the newly cloned repository.
    """

  showHelp: (argv) -> @parseOptions(argv).showHelp()

  loadNpm: (callback) ->
    npmOptions =
      loglevel: 'silent'
      userconfig: config.getUserConfigPath()

    npm.load npmOptions, (error) ->
      if error?
        callback(error)
      else
        callback(null, npm)

  getRepositoryUrl: (packageName, callback) ->
    @loadNpm ->
      npm.commands.view [packageName, 'repository'], true, (error, data={}) ->
        if error?
          callback(error)
        else
          if repoUrl = _.values(data)[0]?.repository?.url
            callback(null, repoUrl)
          else
            callback("#{packageName} has no repository url".red)

  cloneRepository: (repoUrl, packageDirectory, options) ->
    command = "git"
    args = ['clone', '--recursive', repoUrl, packageDirectory]
    process.stdout.write "Cloning #{repoUrl} "
    @spawn command, args, (code, stderr, stdout) =>
      if code is 0
        process.stdout.write '\u2713\n'.green
        @linkPackage(packageDirectory, options)
      else
        process.stdout.write '\u2717\n'.red
        options.callback("#{stdout}\n#{stderr}".red)

  linkPackage: (packageDirectory, options) ->
    linkOptions = _.clone(options)
    linkOptions.commandArgs = [packageDirectory]
    linkOptions.argv = {dev: true}
    new Linker().run(linkOptions)

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
