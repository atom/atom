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
* Each non-theme package is 'activated', meaning its resources are loaded into the
* Packages and themes can be enabled and disabled, and

TODO:
* test that it doesnt activate all the theme packages
* originally disabled packages can be enabled, and loaded without reloading
* config.observe the core.disabledPackages
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

  getPackageState: (name) ->
    @packageStates[name]

  setPackageState: (name, state) ->
    @packageStates[name] = state

  enablePackage: (name) ->
    pack = @loadPackage(name)
    pack?.enable()

  disablePackage: (name) ->
    pack = @loadPackage(name)
    pack?.disable()

  activatePackages: ->
    # ThemeManager handles themes. Only activate non theme packages
    # This is the only part I dislike
    @activatePackage(pack.name) for pack in @getLoadedPackages() when not pack.isTheme()

  activatePackage: (name, options) ->
    return if @getActivePackage(name)
    if pack = @loadPackage(name, options)
      @activePackages[pack.name] = pack
      pack.activate(options)
      pack

  deactivatePackages: ->
    @deactivatePackage(pack.name) for pack in @getActivePackages()

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

  loadPackages: ->
    # Ensure atom exports is already in the require cache so the load time
    # of the first package isn't skewed by being the first to require atom
    require '../exports/atom'

    @loadPackage(name) for name in @getAvailablePackageNames() when not @isPackageDisabled(name)
    @emit 'loaded'

  loadPackage: (name, options) ->
    if @isPackageDisabled(name)
      return console.warn("Tried to load disabled package '#{name}'")

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
