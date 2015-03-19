path = require 'path'
_ = require 'underscore-plus'
optimist = require 'optimist'
apm = require './apm'
Command = require './command'

module.exports =
class Config extends Command
  @commandNames: ['config']

  constructor: ->
    atomDirectory = apm.getAtomDirectory()
    @atomNodeDirectory = path.join(atomDirectory, '.node-gyp')
    @atomNpmPath = require.resolve('npm/bin/npm-cli')

  parseOptions: (argv) ->
    options = optimist(argv)
    options.usage """

      Usage: apm config set <key> <value>
             apm config get <key>
             apm config delete <key>
             apm config list
             apm config edit

    """
    options.alias('h', 'help').describe('help', 'Print this usage message')

  run: (options) ->
    {callback} = options
    options = @parseOptions(options.commandArgs)

    configArgs = ['--globalconfig', apm.getGlobalConfigPath(), '--userconfig', apm.getUserConfigPath(), 'config']
    configArgs = configArgs.concat(options.argv._)

    env = _.extend({}, process.env, HOME: @atomNodeDirectory)
    configOptions = {env}

    @fork @atomNpmPath, configArgs, configOptions, (code, stderr='', stdout='') ->
      if code is 0
        process.stdout.write(stdout) if stdout
        callback()
      else
        process.stdout.write(stderr) if stderr
        callback(new Error("npm config failed: #{code}"))
