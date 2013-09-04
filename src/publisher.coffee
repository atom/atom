path = require 'path'
colors = require 'colors'
CSON = require 'season'
config = require './config'
Command = require './command'

module.exports =
class Publisher extends Command
  userConfigPath: null
  atomNpmPath: null

  constructor: ->
    @userConfigPath = config.getUserConfigPath()
    @atomNpmPath = require.resolve('npm/bin/npm-cli')

  versionPackage: (version, callback) ->
    process.stdout.write 'Preparing and tagging a new version '
    versionArgs = ['version', version, '-m', 'Prepare %s release']
    @fork @atomNpmPath, versionArgs, (code, stderr='', stdout='') ->
      if code is 0
        process.stdout.write '\u2713\n'.green
        callback()
      else
        process.stdout.write '\u2717\n'.red
        callback("#{stdout}\n#{stderr}".red)

  publishPackage: (options) ->
    process.stdout.write 'Publishing '
    try
      {name, version} = CSON.readFileSync(CSON.resolve('package')) ? {}
      process.stdout.write "#{name}@#{version} "

    publishArgs = ['--userconfig', @userConfigPath, 'publish']
    if tag = options.argv.tag
      publishArgs.push('--tag', tag)
    if force = options.argv.force
      publishArgs.push('--force')

    @fork @atomNpmPath, publishArgs, (code, stderr='', stdout='') ->
      if code is 0
        process.stdout.write '\u2713\n'.green
        options.callback()
      else
        process.stdout.write '\u2717\n'.red
        options.callback("#{stdout}\n#{stderr}".red)

  run: (options) ->
    version = options.commandArgs.shift()
    if version
      @versionPackage version, (error) =>
        if error?
          options.callback(error)
        else
          @publishPackage(options)
    else
      @publishPackage(options)
