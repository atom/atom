fs = require 'fs'
child_process = require 'child_process'
async = require 'async'
_ = require 'underscore'
mkdir = require('mkdirp').sync
path = require 'path'

module.exports =
class Installer
  constructor: ->
    @nodeVersion = '0.10.3'
    @nodeUrl = process.env.ATOM_NODE_URL ? 'https://gh-contractor-zcbenz.s3.amazonaws.com/cefode2/dist'

    @atomDirectory = process.env.ATOM_HOME ? path.join(process.env.HOME, '.atom')
    @atomPackagesDirectory = path.join(@atomDirectory, 'packages')
    @atomNodeDirectory = path.join(@atomDirectory, '.node-gyp')
    @atomModulesDirectory = path.join(@atomDirectory, 'node_modules')
    @atomNpmPath = path.join(@atomModulesDirectory, '.bin', 'npm')
    @atomNodeGypPath = path.join(@atomModulesDirectory, '.bin', 'node-gyp')

  spawn: (command, args, remaining...) ->
    options = remaining.shift() if remaining.length >= 2
    callback = remaining.shift()

    spawned = child_process.spawn(command, args, options)
    spawned.stdout.pipe(process.stdout)
    spawned.stderr.pipe(process.stderr)
    spawned.on 'error', (error) -> callback?(-1)
    spawned.on('close', callback) if callback?

  installNpm: (callback) =>
    console.log 'Installing npm locally...'

    mkdir(@atomModulesDirectory)
    @spawn 'npm', ['install', 'npm@v1.2.18', '--silent'], {cwd: @atomDirectory}, (code) ->
      if code is 0
        callback()
      else
        callback("Installing npm failed with code: #{code}")

  installNodeGyp: (callback) =>
    console.log '\nInstalling node-gyp locally...'

    mkdir(@atomModulesDirectory)
    @spawn @atomNpmPath, ['install', 'node-gyp', '--silent'], {cwd: @atomDirectory}, (code) ->
      if code is 0
        callback()
      else
        callback("Installing node-gyp failed with code: #{code}")

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
    commands.push(@installNpm)
    unless fs.existsSync(@atomNodeGypPath)
      commands.push(@installNodeGyp)
      commands.push(@installNode)
    commands.push (callback) => @installModule(modulePath, callback)

    async.waterfall commands, (error) ->
      console.error(error) if error?
      options.callback?()

  installDependencies: (options) ->
    commands = []
    commands.push(@installNpm)
    unless fs.existsSync(@atomNodeGypPath)
      commands.push(@installNodeGyp)
      commands.push(@installNode)
    commands.push(@installModules)

    async.waterfall commands, (error) ->
      console.error(error) if error?
      options.callback?()

  run: (options) ->
    modulePath = options.commandArgs.shift() ? '.'
    if path isnt '.'
      @installPackage(options, modulePath)
    else
      @installDependencies(options)
