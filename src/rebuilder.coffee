path = require 'path'

_ = require 'underscore'
require 'colors'

config = require './config'
Command = require './command'
Installer = require './installer'

module.exports =
class Rebuilder extends Command
  constructor: ->
    @atomNodeDirectory = path.join(config.getAtomDirectory(), '.node-gyp')
    @atomNpmPath = require.resolve('npm/bin/npm-cli')

  run: ({callback}) ->
    new Installer().installNode (error) =>
      if error?
        callback(error)
      else
        process.stdout.write 'Rebuilding modules '

        rebuildArgs = ['rebuild']
        rebuildArgs.push("--target=#{config.getNodeVersion()}")
        rebuildArgs.push('--arch=ia32')
        env = _.extend({}, process.env, HOME: @atomNodeDirectory)

        @fork @atomNpmPath, rebuildArgs, {env}, (code, stderr='') ->
          if code is 0
            process.stdout.write '\u2713\n'.green
            callback()
          else
            process.stdout.write '\u2717\n'.red
            callback(stderr.red)
