{Emitter} = require 'emissary'
fsUtils = require './fs-utils'
_ = require 'underscore-plus'
Package = require './package'
path = require 'path'

###
Packages have a lifecycle

* The paths to all non-disabled packages and themes are found on disk (these are available packages)
* Every package (except those in core.disabledPackages) is 'loaded', meaning
  `Package` objects are created, and their metadata loaded. This includes themes,
  as themes are packages
* The ThemeManager.activateThemes() is called 'activating' all the themes, meaning
  their stylesheets are loaded into the window.
* The PackageManager.activatePackages() function is called 'activating' non-theme
  package, meaning its resources -- keymaps, classes, etc. -- are loaded, and
  the package's activate() method is called.
* Packages and themes can then be enabled and disabled via the public
  .enablePackage(name) and .disablePackage(name) functions.
###
module.exports =
class PackageManager
  Emitter.includeInto(this)

  constructor: ({configDirPath, devMode, @resourcePath}) ->
    @packageDirPaths = [path.join(configDirPath, "packages")]
    if devMode
      @packageDirPaths.unshift(path.join(configDirPath, "dev", "packages"))

    @loadedPackages = {}
    @activePackages = {}
    @packageStates = {}
    @observingDisabledPackages = false

  getPackageState: (name) ->
    @packageStates[name]

  setPackageState: (name, state) ->
    @packageStates[name] = state

  # Public:
  enablePackage: (name) ->
    pack = @loadPackage(name)
    pack?.enable()
    pack

  # Public:
  disablePackage: (name) ->
    pack = @loadPackage(name)
    pack?.disable()
    pack

  activatePackages: ->
    # ThemeManager handles themes. Only activate non theme packages
    # This is the only part I dislike
    @activatePackage(pack.name) for pack in @getLoadedPackages() when not pack.isTheme()
    @observeDisabledPackages()

  activatePackage: (name, options) ->
    return pack if pack = @getActivePackage(name)
    if pack = @loadPackage(name, options)
      @activePackages[pack.name] = pack
      pack.activate(options)
      pack

  deactivatePackages: ->
    @deactivatePackage(pack.name) for pack in @getActivePackages()
    @unobserveDisabledPackages()

  deactivatePackage: (name) ->
    if pack = @getActivePackage(name)
      @setPackageState(pack.name, state) if state = pack.serialize?()
      pack.deactivate()
      delete @activePackages[pack.name]
    else
      throw new Error("No active package for name '#{name}'")

  getActivePackages: ->
    _.values(@activePackages)

  getActivePackage: (name) ->
    @activePackages[name]

  isPackageActive: (name) ->
    @getActivePackage(name)?

  unobserveDisabledPackages: ->
    return unless @observingDisabledPackages
    config.unobserve('core.disabledPackages')
    @observingDisabledPackages = false

  observeDisabledPackages: ->
    return if @observingDisabledPackages

    config.observe 'core.disabledPackages', callNow: false, (disabledPackages, {previous}) =>
      packagesToEnable = _.difference(previous, disabledPackages)
      packagesToDisable = _.difference(disabledPackages, previous)

      @deactivatePackage(packageName) for packageName in packagesToDisable when @getActivePackage(packageName)
      @activatePackage(packageName) for packageName in packagesToEnable
      null

    @observingDisabledPackages = true

  loadPackages: ->
    # Ensure atom exports is already in the require cache so the load time
    # of the first package isn't skewed by being the first to require atom
    require '../exports/atom'

    @loadPackage(name) for name in @getAvailablePackageNames() when not @isPackageDisabled(name)
    @emit 'loaded'

  loadPackage: (name, options) ->
    if packagePath = @resolvePackagePath(name)
      return pack if pack = @getLoadedPackage(name)

      pack = Package.load(packagePath, options)
      @loadedPackages[pack.name] = pack if pack?
      pack
    else
      throw new Error("Could not resolve '#{name}' to a package path")

  unloadPackages: ->
    @unloadPackage(name) for name in _.keys(@loadedPackages)
    null

  unloadPackage: (name) ->
    if @isPackageActive(name)
      throw new Error("Tried to unload active package '#{name}'")

    if pack = @getLoadedPackage(name)
      delete @loadedPackages[pack.name]
    else
      throw new Error("No loaded package for name '#{name}'")

  getLoadedPackage: (name) ->
    @loadedPackages[name]

  isPackageLoaded: (name) ->
    @getLoadedPackage(name)?

  getLoadedPackages: ->
    _.values(@loadedPackages)

  resolvePackagePath: (name) ->
    return name if fsUtils.isDirectorySync(name)

    packagePath = fsUtils.resolve(@packageDirPaths..., name)
    return packagePath if fsUtils.isDirectorySync(packagePath)

    packagePath = path.join(@resourcePath, 'node_modules', name)
    return packagePath if @isInternalPackage(packagePath)

  isPackageDisabled: (name) ->
    _.include(config.get('core.disabledPackages') ? [], name)

  isInternalPackage: (packagePath) ->
    {engines} = Package.loadMetadata(packagePath, true)
    engines?.atom?

  getAvailablePackagePaths: ->
    packagePaths = []

    for packageDirPath in @packageDirPaths
      for packagePath in fsUtils.listSync(packageDirPath)
        packagePaths.push(packagePath) if fsUtils.isDirectorySync(packagePath)

    for packagePath in fsUtils.listSync(path.join(@resourcePath, 'node_modules'))
      packagePaths.push(packagePath) if @isInternalPackage(packagePath)

    _.uniq(packagePaths)

  getAvailablePackageNames: ->
    _.uniq _.map @getAvailablePackagePaths(), (packagePath) -> path.basename(packagePath)

  getAvailablePackageMetadata: ->
    packages = []
    for packagePath in @getAvailablePackagePaths()
      name = path.basename(packagePath)
      metadata = @getLoadedPackage(name)?.metadata ? Package.loadMetadata(packagePath, true)
      packages.push(metadata)
    packages
