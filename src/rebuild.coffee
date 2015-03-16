path = require 'path'

_ = require 'underscore-plus'
optimist = require 'optimist'

config = require './apm'
Command = require './command'
Install = require './install'

module.exports =
class Rebuild extends Command
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

  run: ({callback}) ->
    config.loadNpm (error, npm) =>
      install = new Install()
      install.npm = npm
      install.installNode (error) =>
        return callback(error) if error?

        process.stdout.write 'Rebuilding modules '

        rebuildArgs = ['rebuild']
        rebuildArgs.push("--target=#{config.getNodeVersion()}")
        rebuildArgs.push("--arch=#{config.getNodeArch()}")
        env = _.extend({}, process.env, HOME: @atomNodeDirectory)
        env.USERPROFILE = env.HOME if config.isWin32()

        @fork @atomNpmPath, rebuildArgs, {env}, (code, stderr='') =>
          if code is 0
            @logSuccess()
            callback()
          else
            @logFailure()
            callback(stderr)
