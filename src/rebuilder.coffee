path = require 'path'

_ = require 'underscore'
require 'colors'
optimist = require 'optimist'

config = require './config'
Command = require './command'
Installer = require './installer'

module.exports =
class Rebuilder extends Command
  @commandNames: ['rebuild']

  constructor: ->
    @atomNodeDirectory = path.join(config.getAtomDirectory(), '.node-gyp')
    @atomNpmPath = require.resolve('npm/bin/npm-cli')

  parseOptions: (argv) ->
    options = optimist(argv)
    options.usage """

      Usage: apm rebuild

      Rebuild all the modules currently installed in the node_modules folder
      in the current working directory.
    """
    options.alias('h', 'help').describe('help', 'Print this usage message')

  showHelp: (argv) -> @parseOptions(argv).showHelp()

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
        env.USERPROFILE = env.HOME if config.isWin32()

        @fork @atomNpmPath, rebuildArgs, {env}, (code, stderr='') ->
          if code is 0
            process.stdout.write '\u2713\n'.green
            callback()
          else
            process.stdout.write '\u2717\n'.red
            callback(stderr)
