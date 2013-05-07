fs = require 'fs'
optimist = require 'optimist'
child_process = require 'child_process'
async = require 'async'
_ = require 'underscore'

parseOptions = (args=[]) ->
  options = optimist(args)
  options.usage('Usage: apm <command>')
  options.alias('v', 'version').describe('v', 'Print the apm version')
  options.alias('h', 'help').describe('h', 'Print this usage message')
  options.command = options.argv._[0]
  options

spawn = (command, args, remaining...) ->
  options = remaining.shift() if remaining.length >= 2
  callback = remaining.shift()

  spawned = child_process.spawn(command, args, options)
  spawned.stdout.pipe(process.stdout)
  spawned.stderr.pipe(process.stderr)
  spawned.on('close', callback) if callback?

install = (options) ->
  nodeVersion = '0.10.3'
  nodeUrl = 'https://gh-contractor-zcbenz.s3.amazonaws.com/cefode2/dist'
  atomDirectory = "#{process.env.HOME}/.atom"
  nodeDirectory = "#{atomDirectory}/.node-gyp"

  commands = []
  commands.push (callback) ->
    console.log 'Installing npm locally...'

    installNpm = spawn 'npm', ['install', 'npm', '--silent'], (code) ->
      if code is 0
        callback()
      else
        callback("Installing npm failed with code: #{code}")

  nodeGypExists = fs.existsSync('node_modules/node-gyp')
  unless nodeGypExists
    commands.push (callback) ->
      console.log '\nInstalling node-gyp locally...'

      installNodeGyp = spawn 'node_modules/.bin/npm', ['install', 'node-gyp', '--silent'], (code) ->
        if code is 0
          callback()
        else
          callback("Installing node-gyp failed with code: #{code}")

    commands.push (callback) ->
      console.log '\nInstalling node...'

      installNodeArgs = ['install']
      installNodeArgs.push("--target=#{nodeVersion}")
      installNodeArgs.push("--dist-url=#{nodeUrl}")
      installNodeArgs.push('--arch=ia32')
      env = _.extend({}, process.env, HOME: nodeDirectory)

      installNode = spawn 'node_modules/.bin/node-gyp', installNodeArgs, {env}, (code) ->
        if code is 0
          callback()
        else
          callback("Installing node failed with code: #{code}")

  commands.push (callback) ->
    console.log '\nInstalling modules...'

    installModulesArgs = ['install']
    installModulesArgs.push("--target=#{nodeVersion}")
    installModulesArgs.push('--arch=ia32')
    installModulesArgs.push('--silent')
    env = _.extend({}, process.env, HOME: nodeDirectory)

    installModules = spawn 'node_modules/.bin/npm', installModulesArgs, {env}, (code) ->
      if code is 0
        callback()
      else
        callback("Installing modules failed with code: #{code}")

  async.waterfall commands, (error) ->
    console.error(error) if error?

module.exports =
  run: (args) ->
    options = parseOptions(args)
    args = options.argv
    command = options.command
    if args.v
      console.log JSON.parse(fs.readFileSync('package.json')).version
    else if args.h
      options.showHelp()
    else if command
      switch command
        when 'install' then install(options)
        else console.error "Unrecognized command: #{command}"
    else
      options.showHelp()
