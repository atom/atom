path = require 'path'
_ = require 'underscore'
config = require './config'
Command = require './command'
Installer = require './installer'

module.exports =
class Rebuilder extends Command
  atomNodeDirectory: null
  atomNpmPath: null

  constructor: ->
    @atomNodeDirectory = path.join(config.getAtomDirectory(), '.node-gyp')
    @atomNpmPath = require.resolve('.bin/npm')

  run: ({callback}) ->
    new Installer().installNode (error) =>
      if error?
        callback(error)
      else
        console.log '\nRebuilding module...'

        rebuildArgs = ['rebuild']
        rebuildArgs.push("--target=#{config.getNodeVersion()}")
        rebuildArgs.push('--arch=ia32')
        env = _.extend({}, process.env, HOME: @atomNodeDirectory)

        @spawn @atomNpmPath, rebuildArgs, {env}, (code) ->
          if code is 0
            callback()
          else
            callback("Rebuilding module failed with code: #{code}")
