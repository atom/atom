_ = require 'underscore-plus'
path = require 'path'
CSON = require 'season'
yargs = require 'yargs'

config = require './apm'
Command = require './command'
List = require './list'

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

  getInstalledPackages: (callback) ->
    options =
      argv:
        theme: false
        bare: true

    lister = new List()
    lister.listBundledPackages options, (error, core_packages) ->
      lister.listDevPackages options, (error, dev_packages) ->
        lister.listUserPackages options, (error, user_packages) ->
          callback(null, core_packages.concat(dev_packages, user_packages))

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

    @getInstalledPackages (error, installedPackages) =>
      return callback(error) if error

      installedPackageNames = (pkg.name for pkg in installedPackages)

      # uninstalledPackages = (name for name in packageNames when !installedPackageNames[name])
      uninstalledPackageNames = _.difference(packageNames, installedPackageNames)
      if uninstalledPackageNames.length > 0
        console.log "Not Installed:\n  #{uninstalledPackageNames.join('\n  ')}"

      # only installed packages can be disabled
      packageNames = _.difference(packageNames, uninstalledPackageNames)

      if packageNames.length is 0
        callback("Please specify a package to disable")
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

      console.log "Disabled:\n  #{packageNames.join('\n  ')}"
      @logSuccess()
      callback()
