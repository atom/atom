{Emitter} = require 'emissary'
fs = require 'fs-plus'
_ = require 'underscore-plus'
Package = require './package'
path = require 'path'

# Public: Package manager for coordinating the lifecycle of Atom packages.
#
# Packages can be loaded, activated, and deactivated, and unloaded:
#  * Loading a package reads and parses the package's metadata and resources
#    such as keymaps, menus, stylesheets, etc.
#  * Activating a package registers the loaded resources and calls `activate()`
#    on the package's main module.
#  * Deactivating a package unregisters the package's resources  and calls
#    `deactivate()` on the package's main module.
#  * Unloading a package removes it completely from the package manager.
#
# Packages can also be enabled/disabled via the `core.disabledPackages` config
# settings and also by calling `enablePackage()/disablePackage()`.
#
# An instance of this class is globally available via `atom.packages`.
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

    @packageActivators = []
    @registerPackageActivator(this, ['atom', 'textmate'])

  # Public: Get the path to the apm command
  getApmPath: ->
    @apmPath ?= require.resolve('atom-package-manager/bin/apm')

  # Public: Get the paths being used to look for packages.
  #
  # Returns an Array of String directory paths.
  getPackageDirPaths: ->
    _.clone(@packageDirPaths)

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

  # Internal-only: Activate all the packages that should be activated.
  activate: ->
    for [activator, types] in @packageActivators
      packages = @getLoadedPackagesForTypes(types)
      activator.activatePackages(packages)
    @emit 'activated'

  # Public: another type of package manager can handle other package types.
  # See ThemeManager
  registerPackageActivator: (activator, types) ->
    @packageActivators.push([activator, types])

  # Internal-only:
  activatePackages: (packages) ->
    @activatePackage(pack.name) for pack in packages
    @observeDisabledPackages()

  # Internal-only: Activate a single package by name
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
    atom.config.unobserve('core.disabledPackages')
    @observingDisabledPackages = false

  observeDisabledPackages: ->
    return if @observingDisabledPackages

    atom.config.observe 'core.disabledPackages', callNow: false, (disabledPackages, {previous}) =>
      packagesToEnable = _.difference(previous, disabledPackages)
      packagesToDisable = _.difference(disabledPackages, previous)

      @deactivatePackage(packageName) for packageName in packagesToDisable when @getActivePackage(packageName)
      @activatePackage(packageName) for packageName in packagesToEnable
      null

    @observingDisabledPackages = true

  loadPackages: (options) ->
    # Ensure atom exports is already in the require cache so the load time
    # of the first package isn't skewed by being the first to require atom
    require '../exports/atom'

    packagePaths = @getAvailablePackagePaths()
    packagePaths = packagePaths.filter (packagePath) => not @isPackageDisabled(path.basename(packagePath))
    packagePaths = _.uniq packagePaths, (packagePath) -> path.basename(packagePath)
    @loadPackage(packagePath, options) for packagePath in packagePaths
    @emit 'loaded'

  loadPackage: (nameOrPath, options) ->
    if packagePath = @resolvePackagePath(nameOrPath)
      name = path.basename(nameOrPath)
      return pack if pack = @getLoadedPackage(name)

      pack = Package.load(packagePath, options)
      @loadedPackages[pack.name] = pack if pack?
      pack
    else
      throw new Error("Could not resolve '#{nameOrPath}' to a package path")

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

  # Private: Get packages for a certain package type
  #
  # * types: an {Array} of {String}s like ['atom', 'textmate']
  getLoadedPackagesForTypes: (types) ->
    pack for pack in @getLoadedPackages() when pack.getType() in types

  resolvePackagePath: (name) ->
    return name if fs.isDirectorySync(name)

    packagePath = fs.resolve(@packageDirPaths..., name)
    return packagePath if fs.isDirectorySync(packagePath)

    packagePath = path.join(@resourcePath, 'node_modules', name)
    return packagePath if @isInternalPackage(packagePath)

  isPackageDisabled: (name) ->
    _.include(atom.config.get('core.disabledPackages') ? [], name)

  isInternalPackage: (packagePath) ->
    {engines} = Package.loadMetadata(packagePath, true)
    engines?.atom?

  isBundledPackage: (packageName) ->
    @getPackageDependencies().hasOwnProperty(packageName)

  getPackageDependencies: ->
    unless @packageDependencies?
      try
        metadataPath = path.join(@resourcePath, 'package.json')
        {@packageDependencies} = JSON.parse(fs.readFileSync(metadataPath)) ? {}
      @packageDependencies ?= {}

    @packageDependencies

  getAvailablePackagePaths: ->
    packagePaths = []

    for packageDirPath in @packageDirPaths
      for packagePath in fs.listSync(packageDirPath)
        packagePaths.push(packagePath) if fs.isDirectorySync(packagePath)

    packagesPath = path.join(@resourcePath, 'node_modules')
    for packageName, packageVersion of @getPackageDependencies()
      packagePath = path.join(packagesPath, packageName)
      packagePaths.push(packagePath) if fs.isDirectorySync(packagePath)

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
