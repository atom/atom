path = require 'path'
config = require './config'
Command = require './command'

module.exports =
class Publisher extends Command
  userConfigPath: null
  atomNpmPath: null

  constructor: ->
    @userConfigPath = config.getUserConfigPath()
    @atomNpmPath = require.resolve('.bin/npm')

  run: (options) ->
    publishArgs = ['--userconfig', @userConfigPath, 'publish']
    @fork @atomNpmPath, publishArgs, (code) =>
      if code is 0
        options.callback()
      else
        options.callback("Publishing module failed with code: #{code}")
