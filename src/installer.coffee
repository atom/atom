fs = require 'fs'
path = require 'path'

async = require 'async'
_ = require 'underscore'
mkdir = require('mkdirp').sync
temp = require 'temp'
cp = require('wrench').copyDirSyncRecursive
rm = require('rimraf').sync
require 'colors'

config = require './config'
Command = require './command'

module.exports =
class Installer extends Command
  atomDirectory: null
  atomPackagesDirectory: null
  atomNodeDirectory: null
  atomNpmPath: null
  atomNodeGypPath: null

  constructor: ->
    @atomDirectory = config.getAtomDirectory()
    @atomPackagesDirectory = path.join(@atomDirectory, 'packages')
    @atomNodeDirectory = path.join(@atomDirectory, '.node-gyp')
    @atomNpmPath = require.resolve('.bin/npm')
    @atomNodeGypPath = require.resolve('.bin/node-gyp')

  installNode: (callback) =>
    process.stdout.write "Installing node@#{config.getNodeVersion()} "

    installNodeArgs = ['install']
    installNodeArgs.push("--target=#{config.getNodeVersion()}")
    installNodeArgs.push("--dist-url=#{config.getNodeUrl()}")
    installNodeArgs.push('--arch=ia32')
    env = _.extend({}, process.env, HOME: @atomNodeDirectory)

    mkdir(@atomDirectory)
    @fork @atomNodeGypPath, installNodeArgs, {env, cwd: @atomDirectory}, (code, stderr='') ->
      if code is 0
        process.stdout.write '\u2713\n'.green
        callback()
      else
        process.stdout.write '\u2717\n'.red
        callback(stderr.red)

  installModule: (options, modulePath, callback) ->
    process.stdout.write "Installing #{modulePath} to #{@atomPackagesDirectory} "

    installArgs = ['--userconfig', config.getUserConfigPath(), 'install']
    installArgs.push(modulePath)
    installArgs.push("--target=#{config.getNodeVersion()}")
    installArgs.push('--arch=ia32')
    installArgs.push('--silent') if options.argv.silent
    env = _.extend({}, process.env, HOME: @atomNodeDirectory)

    installDirectory = temp.mkdirSync('apm-install-dir-')
    nodeModulesDirectory = path.join(installDirectory, 'node_modules')
    mkdir(nodeModulesDirectory)
    @fork @atomNpmPath, installArgs, {env, cwd: installDirectory}, (code, stderr='') =>
      if code is 0
        for child in fs.readdirSync(nodeModulesDirectory)
          cp(path.join(nodeModulesDirectory, child), path.join(@atomPackagesDirectory, child), forceDelete: true)
        rm(installDirectory)
        process.stdout.write '\u2713\n'.green
        callback()
      else
        rm(installDirectory)
        process.stdout.write '\u2717\n'.red
        callback(stderr.red)

  installModules: (options, callback) =>
    console.log '\nInstalling modules...'

    installArgs = ['--userconfig', config.getUserConfigPath(), 'install']
    installArgs.push("--target=#{config.getNodeVersion()}")
    installArgs.push('--arch=ia32')
    installArgs.push('--silent') if options.argv.silent
    env = _.extend({}, process.env, HOME: @atomNodeDirectory)

    @fork @atomNpmPath, installArgs, {env}, (code) ->
      if code is 0
        callback()
      else
        callback("Installing modules failed with code: #{code}")

  installPackage: (options, modulePath) ->
    commands = []
    commands.push(@installNode)
    commands.push (callback) => @installModule(options, modulePath, callback)

    async.waterfall(commands, options.callback)

  installDependencies: (options) ->
    commands = []
    commands.push(@installNode)
    commands.push (callback) => @installModules(options, callback)

    async.waterfall commands, options.callback

  installTextMateBundle: (options, bundlePath) ->
    gitArguments = ['clone']
    gitArguments.push(bundlePath)
    gitArguments.push(path.join(@atomPackagesDirectory, path.basename(bundlePath, '.git')))
    @spawn 'git', gitArguments, (code) ->
      if code is 0
        options.callback()
      else
        options.callback("Installing bundle failed with code: #{code}")

  isTextMateBundlePath: (bundlePath) ->
    path.extname(path.basename(bundlePath, '.git')) is '.tmbundle'

  createAtomDirectories: ->
    mkdir(@atomDirectory)
    mkdir(@atomPackagesDirectory)
    mkdir(@atomNodeDirectory)

  run: (options) ->
    @createAtomDirectories()
    modulePath = options.commandArgs.shift() ? '.'
    if modulePath is '.'
      @installDependencies(options)
    else if @isTextMateBundlePath(modulePath)
      @installTextMateBundle(options, modulePath)
    else
      @installPackage(options, modulePath)
