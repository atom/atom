path = require 'path'
Command = require './command'

module.exports =
class Publisher extends Command
  userConfigPath: null
  atomNpmPath: null

  constructor: ->
    @userConfigPath = path.resolve(__dirname, '..', '.apmrc')
    @atomNpmPath = require.resolve('.bin/npm')

  run: (options) ->
    publishArgs = ['--userconfig', @userConfigPath, 'publish']
    @spawn @atomNpmPath, publishArgs, (code) =>
      if code is 0
        options.callback()
      else
        options.callback("Publishing module failed with code: #{code}")
