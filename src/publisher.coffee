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

  run: (options) ->
    process.stdout.write 'Publishing '
    try
      {name, version} = CSON.readFileSync(CSON.resolve('package')) ? {}
      process.stdout.write "#{name}@#{version} "
    catch e
    publishArgs = ['--userconfig', @userConfigPath, 'publish']
    @fork @atomNpmPath, publishArgs, (code, stderr='') =>
      if code is 0
        process.stdout.write '\u2713\n'.green
        options.callback()
      else
        process.stdout.write '\u2717\n'.red
        options.callback(stderr.red)
