_ = require 'underscore-plus'
path = require 'path'
CSON = require 'season'
yargs = require 'yargs'

config = require './apm'
Command = require './command'

module.exports =
class Disable extends Command
  @commandNames: ['disable']

  parseOptions: (argv) ->
    options = yargs(argv).wrap(100)
    options.usage """

      Usage: apm disable [<package_name>]...

      Disables the named package(s).
    """
    options.alias('h', 'help').describe('help', 'Print this usage message')

  run: (options) ->
    {callback} = options
    options = @parseOptions(options.commandArgs)

    packageNames = @packageNamesFromArgv(options.argv)
    if packageNames.length is 0
      callback("Please specify a package to disable")
      return

    configFilePath = CSON.resolve(path.join(config.getAtomDirectory(), 'config'))
    unless configFilePath
      callback("Could not find config.cson. Run Atom first?")
      return

    try
      settings = CSON.readFileSync(configFilePath)
    catch error
      callback "Failed to load `#{configFilePath}`: #{error.message}"
      return

    keyPath = '*.core.disabledPackages'
    disabledPackages = _.valueForKeyPath(settings, keyPath) ? []
    result = _.union(disabledPackages, packageNames...)
    _.setValueForKeyPath(settings, keyPath, result)

    try
      CSON.writeFileSync(configFilePath, settings)
    catch error
      callback "Failed to save `#{configFilePath}`: #{error.message}"
      return

    console.log "Disabled:\n  #{packageNames.join('\n  ')} "
    @logSuccess()
    callback()
