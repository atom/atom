fs = require 'fs'
path = require 'path'

async = require 'async'
_ = require 'underscore'
mkdir = require('mkdirp').sync
optimist = require 'optimist'
temp = require 'temp'
require 'colors'

config = require './config'
Command = require './command'
fs = require './fs'

module.exports =
class Installer extends Command
  @commandNames: ['install']

  constructor: ->
    @atomDirectory = config.getAtomDirectory()
    @atomPackagesDirectory = path.join(@atomDirectory, 'packages')
    @atomNodeDirectory = path.join(@atomDirectory, '.node-gyp')
    @atomNpmPath = require.resolve('npm/bin/npm-cli')
    @atomNodeGypPath = require.resolve('node-gyp/bin/node-gyp')

  parseOptions: (argv) ->
    options = optimist(argv)
    options.usage """

      Usage: apm install [<package_name>]

      Install the given Atom package to ~/.atom/packages/<package_name>.

      If no package name is given then all the dependencies in the package.json
      file are installed into the node_modules folder for the current working
      directory.
    """
    options.alias('h', 'help').describe('help', 'Print this usage message')
    options.boolean('silent').describe('silent', 'Minimize output')

  showHelp: (argv) -> @parseOptions(argv).showHelp()

  installNode: (callback) =>
    process.stdout.write "Installing node@#{config.getNodeVersion()} "

    installNodeArgs = ['install']
    installNodeArgs.push("--target=#{config.getNodeVersion()}")
    installNodeArgs.push("--dist-url=#{config.getNodeUrl()}")
    installNodeArgs.push('--arch=ia32')

    env = _.extend({}, process.env, HOME: @atomNodeDirectory)
    env.USERPROFILE = env.HOME if config.isWin32()

    mkdir(@atomDirectory)
    @fork @atomNodeGypPath, installNodeArgs, {env, cwd: @atomDirectory}, (code, stderr='', stdout='') ->
      if code is 0
        process.stdout.write '\u2713\n'.green
        callback()
      else
        process.stdout.write '\u2717\n'.red
        callback(stdout.red + stderr.red)

  installModule: (options, modulePath, callback) ->
    process.stdout.write "Installing #{modulePath} to #{@atomPackagesDirectory} "

    installArgs = ['--userconfig', config.getUserConfigPath(), 'install']
    installArgs.push(modulePath)
    installArgs.push("--target=#{config.getNodeVersion()}")
    installArgs.push('--arch=ia32')
    installArgs.push('--silent') if options.argv.silent
    installArgs.push('--msvs_version=2012') if config.isWin32()
    env = _.extend({}, process.env, HOME: @atomNodeDirectory)
    env.USERPROFILE = env.HOME if config.isWin32()

    installDirectory = temp.mkdirSync('apm-install-dir-')
    nodeModulesDirectory = path.join(installDirectory, 'node_modules')
    mkdir(nodeModulesDirectory)
    @fork @atomNpmPath, installArgs, {env, cwd: installDirectory}, (code, stderr='', stdout='') =>
      if code is 0
        for child in fs.readdirSync(nodeModulesDirectory)
          fs.cp(path.join(nodeModulesDirectory, child), path.join(@atomPackagesDirectory, child), forceDelete: true)
        fs.rm(installDirectory)
        process.stdout.write '\u2713\n'.green
        callback()
      else
        fs.rm(installDirectory)
        process.stdout.write '\u2717\n'.red
        callback(stdout.red + stderr.red)

  installModules: (options, callback) =>
    process.stdout.write 'Installing modules '

    installArgs = ['--userconfig', config.getUserConfigPath(), 'install']
    installArgs.push("--target=#{config.getNodeVersion()}")
    installArgs.push('--arch=ia32')
    installArgs.push('--silent') if options.argv.silent
    installArgs.push('--msvs_version=2012') if config.isWin32()
    env = _.extend({}, process.env, HOME: @atomNodeDirectory)
    env.USERPROFILE = env.HOME if config.isWin32()

    @fork @atomNpmPath, installArgs, {env}, (code, stderr='', stdout='') ->
      if code is 0
        process.stdout.write '\u2713\n'.green
        callback()
      else
        process.stdout.write '\u2717\n'.red
        callback(stdout.red + stderr.red)

  installPackage: (options, modulePath, callback) ->
    commands = []
    commands.push(@installNode)
    commands.push (callback) => @installModule(options, modulePath, callback)

    async.waterfall(commands, callback)

  installDependencies: (options, callback) ->
    commands = []
    commands.push(@installNode)
    commands.push (callback) => @installModules(options, callback)

    async.waterfall commands, callback

  installTextMateBundle: (options, bundlePath, callback) ->
    gitArguments = ['clone']
    gitArguments.push(bundlePath)
    gitArguments.push(path.join(@atomPackagesDirectory, path.basename(bundlePath, '.git')))
    @spawn 'git', gitArguments, (code) ->
      if code is 0
        callback()
      else
        callback("Installing bundle failed with code: #{code}")

  isTextMateBundlePath: (bundlePath) ->
    path.extname(path.basename(bundlePath, '.git')) is '.tmbundle'

  createAtomDirectories: ->
    mkdir(@atomDirectory)
    mkdir(@atomPackagesDirectory)
    mkdir(@atomNodeDirectory)

  run: (options) ->
    {callback} = options
    options = @parseOptions(options.commandArgs)

    @createAtomDirectories()
    modulePath = options.argv._[0] ? '.'
    if modulePath is '.'
      @installDependencies(options, callback)
    else if @isTextMateBundlePath(modulePath)
      @installTextMateBundle(options, modulePath, callback)
    else
      @installPackage(options, modulePath, callback)
