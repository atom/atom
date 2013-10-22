optimist = require 'optimist'

Clean = require './clean'
Install = require './install'

module.exports =
class Update
  @commandNames: ['update']

  parseOptions: (argv) ->
    options = optimist(argv)
    options.usage """

      Usage: apm update

      Run `apm clean` followed by `apm install`.

      See `apm help clean` and `apm help install` for more information.
    """
    options.alias('h', 'help').describe('help', 'Print this usage message')

  showHelp: (argv) -> @parseOptions(argv).showHelp()

  run: (options) ->
    finalCallback = options.callback
    options.callback = (error) ->
      if error?
        finalCallback(error)
      else
        new Install().installDependencies(options, finalCallback)

    new Clean().run(options)
