fs = require 'fs'
child_process = require 'child_process'
async = require 'async'
_ = require 'underscore'
mkdir = require('mkdirp').sync
path = require 'path'

module.exports =
class Installer
  nodeVersion: null
  nodeUrl: null
  atomDirectory: null
  atomPackagesDirectory: null
  atomNodeDirectory: null
  atomNpmPath: null
  atomNodeGypPath: null

  constructor: ->
    @nodeVersion = '0.10.3'
    @nodeUrl = process.env.ATOM_NODE_URL ? 'https://gh-contractor-zcbenz.s3.amazonaws.com/cefode2/dist'

    @atomDirectory = process.env.ATOM_HOME ? path.join(process.env.HOME, '.atom')
    @atomPackagesDirectory = path.join(@atomDirectory, 'packages')
    @atomNodeDirectory = path.join(@atomDirectory, '.node-gyp')
    @atomNpmPath = require.resolve('.bin/npm')
    @atomNodeGypPath = require.resolve('.bin/node-gyp')

  spawn: (command, args, remaining...) ->
    options = remaining.shift() if remaining.length >= 2
    callback = remaining.shift()

    spawned = child_process.spawn(command, args, options)
    spawned.stdout.pipe(process.stdout)
    spawned.stderr.pipe(process.stderr)
    spawned.on 'error', (error) -> callback?(-1)
    spawned.on('close', callback) if callback?

  installNode: (callback) =>
    console.log '\nInstalling node...'

    installNodeArgs = ['install']
    installNodeArgs.push("--target=#{@nodeVersion}")
    installNodeArgs.push("--dist-url=#{@nodeUrl}")
    installNodeArgs.push('--arch=ia32')
    env = _.extend({}, process.env, HOME: @atomNodeDirectory)

    mkdir(@atomDirectory)
    @spawn @atomNodeGypPath, installNodeArgs, {env, cwd: @atomDirectory}, (code) ->
      if code is 0
        callback()
      else
        callback("Installing node failed with code: #{code}")

  installModule: (modulePath, callback) ->
    console.log '\nInstalling module...'

    installModuleArgs = ['install']
    installModuleArgs.push(modulePath)
    installModuleArgs.push("--target=#{@nodeVersion}")
    installModuleArgs.push('--arch=ia32')
    installModuleArgs.push('--silent')
    env = _.extend({}, process.env, HOME: @atomNodeDirectory)

    mkdir(path.join(@atomPackagesDirectory, 'node_modules'))
    @spawn @atomNpmPath, installModuleArgs, {env, cwd: @atomPackagesDirectory}, (code) ->
      if code is 0
        callback()
      else
        callback("Installing module failed with code: #{code}")

  installModules: (callback) =>
    console.log '\nInstalling modules...'

    installModulesArgs = ['install']
    installModulesArgs.push("--target=#{@nodeVersion}")
    installModulesArgs.push('--arch=ia32')
    installModulesArgs.push('--silent')
    env = _.extend({}, process.env, HOME: @atomNodeDirectory)

    @spawn @atomNpmPath, installModulesArgs, {env}, (code) ->
      if code is 0
        callback()
      else
        callback("Installing modules failed with code: #{code}")

  installPackage: (options, modulePath) ->
    commands = []
    commands.push(@installNode)
    commands.push (callback) => @installModule(modulePath, callback)

    async.waterfall commands, (error) ->
      console.error(error) if error?
      options.callback?()

  installDependencies: (options) ->
    commands = []
    commands.push(@installNode)
    commands.push(@installModules)

    async.waterfall commands, (error) ->
      console.error(error) if error?
      options.callback?()

  installTextMateBundle: (options, bundlePath) ->
    gitArguments = ['clone']
    gitArguments.push(bundlePath)
    gitArguments.push(path.join(@atomPackagesDirectory, path.basename(bundlePath, '.git')))
    @spawn 'git', gitArguments, (code) ->
      console.error("Installing bundle failed with code: #{code}") if code isnt 0
      options.callback?()

  isTextMateBundlePath: (bundlePath) ->
    path.extname(path.basename(bundlePath, '.git')) is '.tmbundle'

  run: (options) ->
    modulePath = options.commandArgs.shift() ? '.'
    if modulePath is '.'
      @installDependencies(options)
    else if @isTextMateBundlePath(modulePath)
      @installTextMateBundle(options, modulePath)
    else
      @installPackage(options, modulePath)
