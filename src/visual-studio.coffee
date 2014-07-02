optimist = require 'optimist'
Command = require './command'
config = require './config'

module.exports =
class VisualStudio extends Command
  @commandNames: ['vs']

  parseOptions: (argv) ->
    options = optimist(argv)
    options.usage """

      Usage: apm vs

      Output the detected version of Visual Studio that is installed.
    """
    options.alias('h', 'help').describe('help', 'Print this usage message')

  run: (options) ->
    {callback} = options
    options = @parseOptions(options.commandArgs)

    if version = config.getInstalledVisualStudioFlag()
      console.log version
      callback()
    else
      callback("Could not detect installed Visual Studio version")
