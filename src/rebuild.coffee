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

      Usage: apm rebuild [<name> [<name> ...]]

      Rebuild the given modules currently installed in the node_modules folder
      in the current working directory.

      All the modules will be rebuilt if no module names are specified.
    """
    options.alias('h', 'help').describe('help', 'Print this usage message')

  run: (options) ->
    {callback} = options
    options = @parseOptions(options.commandArgs)

    config.loadNpm (error, npm) =>
      install = new Install()
      install.npm = npm
      install.installNode (error) =>
        return callback(error) if error?

        process.stdout.write 'Rebuilding modules '

        rebuildArgs = ['--globalconfig', config.getGlobalConfigPath(), '--userconfig', config.getUserConfigPath(), 'rebuild']
        rebuildArgs.push("--target=#{config.getNodeVersion()}")
        rebuildArgs.push("--arch=#{config.getNodeArch()}")
        rebuildArgs = rebuildArgs.concat(options.argv._)

        env = _.extend({}, process.env, HOME: @atomNodeDirectory)
        env.USERPROFILE = env.HOME if config.isWin32()

        @fork @atomNpmPath, rebuildArgs, {env}, (code, stderr='') =>
          if code is 0
            @logSuccess()
            callback()
          else
            @logFailure()
            callback(stderr)
