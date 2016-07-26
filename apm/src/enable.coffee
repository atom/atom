_ = require 'underscore-plus'
path = require 'path'
CSON = require 'season'
yargs = require 'yargs'

config = require './apm'
Command = require './command'

module.exports =
class Enable extends Command
  @commandNames: ['enable']

  parseOptions: (argv) ->
    options = yargs(argv).wrap(100)
    options.usage """

      Usage: apm enable [<package_name>]...

      Enables the named package(s).
    """
    options.alias('h', 'help').describe('help', 'Print this usage message')

  run: (options) ->
    {callback} = options
    options = @parseOptions(options.commandArgs)
    packageNames = @packageNamesFromArgv(options.argv)

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

    errorPackages = _.difference(packageNames, disabledPackages)
    if errorPackages.length > 0
      console.log "Not Disabled:\n  #{errorPackages.join('\n  ')}"

    # can't enable a package that isn't disabled
    packageNames = _.difference(packageNames, errorPackages)

    if packageNames.length is 0
      callback("Please specify a package to enable")
      return

    result = _.difference(disabledPackages, packageNames)
    _.setValueForKeyPath(settings, keyPath, result)

    try
      CSON.writeFileSync(configFilePath, settings)
    catch error
      callback "Failed to save `#{configFilePath}`: #{error.message}"
      return

    console.log "Enabled:\n  #{packageNames.join('\n  ')}"
    @logSuccess()
    callback()
