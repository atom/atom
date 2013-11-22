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

  # Private:
  getPackageState: (name) ->
    @packageStates[name]

  # Private:
  setPackageState: (name, state) ->
    @packageStates[name] = state

  # Public: Enable the package with the given name
  enablePackage: (name) ->
    pack = @loadPackage(name)
    pack?.enable()
    pack

  # Public: Disable the package with the given name
  disablePackage: (name) ->
    pack = @loadPackage(name)
    pack?.disable()
    pack

  # Private: Activate all the packages that should be activated.
  activate: ->
    for [activator, types] in @packageActivators
      packages = @getLoadedPackagesForTypes(types)
      activator.activatePackages(packages)
    @emit 'activated'

  # Private: another type of package manager can handle other package types.
  # See ThemeManager
  registerPackageActivator: (activator, types) ->
    @packageActivators.push([activator, types])

  # Private:
  activatePackages: (packages) ->
    @activatePackage(pack.name) for pack in packages
    @observeDisabledPackages()

  # Private: Activate a single package by name
  activatePackage: (name, options) ->
    return pack if pack = @getActivePackage(name)
    if pack = @loadPackage(name, options)
      @activePackages[pack.name] = pack
      pack.activate(options)
      pack

  # Private: Deactivate all packages
  deactivatePackages: ->
    @deactivatePackage(pack.name) for pack in @getActivePackages()
    @unobserveDisabledPackages()

  # Private: Deactivate the package with the given name
  deactivatePackage: (name) ->
    if pack = @getActivePackage(name)
      @setPackageState(pack.name, state) if state = pack.serialize?()
      pack.deactivate()
      delete @activePackages[pack.name]
    else
      throw new Error("No active package for name '#{name}'")

  # Public: Get an array of all the active packages
  getActivePackages: ->
    _.values(@activePackages)

  # Public: Get the active package with the given name
  getActivePackage: (name) ->
    @activePackages[name]

  # Public: Is the package with the given name active?
  isPackageActive: (name) ->
    @getActivePackage(name)?

  # Private:
  unobserveDisabledPackages: ->
    return unless @observingDisabledPackages
    atom.config.unobserve('core.disabledPackages')
    @observingDisabledPackages = false

  # Private:
  observeDisabledPackages: ->
    return if @observingDisabledPackages

    atom.config.observe 'core.disabledPackages', callNow: false, (disabledPackages, {previous}) =>
      packagesToEnable = _.difference(previous, disabledPackages)
      packagesToDisable = _.difference(disabledPackages, previous)

      @deactivatePackage(packageName) for packageName in packagesToDisable when @getActivePackage(packageName)
      @activatePackage(packageName) for packageName in packagesToEnable
      null

    @observingDisabledPackages = true

  # Private:
  loadPackages: (options) ->
    # Ensure atom exports is already in the require cache so the load time
    # of the first package isn't skewed by being the first to require atom
    require '../exports/atom'

    packagePaths = @getAvailablePackagePaths()
    packagePaths = packagePaths.filter (packagePath) => not @isPackageDisabled(path.basename(packagePath))
    packagePaths = _.uniq packagePaths, (packagePath) -> path.basename(packagePath)
    @loadPackage(packagePath, options) for packagePath in packagePaths
    @emit 'loaded'

  # Private:
  loadPackage: (nameOrPath, options) ->
    if packagePath = @resolvePackagePath(nameOrPath)
      name = path.basename(nameOrPath)
      return pack if pack = @getLoadedPackage(name)

      pack = Package.load(packagePath, options)
      @loadedPackages[pack.name] = pack if pack?
      pack
    else
      throw new Error("Could not resolve '#{nameOrPath}' to a package path")

  # Private:
  unloadPackages: ->
    @unloadPackage(name) for name in _.keys(@loadedPackages)
    null

  # Private:
  unloadPackage: (name) ->
    if @isPackageActive(name)
      throw new Error("Tried to unload active package '#{name}'")

    if pack = @getLoadedPackage(name)
      delete @loadedPackages[pack.name]
    else
      throw new Error("No loaded package for name '#{name}'")

  # Public: Get the loaded package with the given name
  getLoadedPackage: (name) ->
    @loadedPackages[name]

  # Public: Is the package with the given name loaded?
  isPackageLoaded: (name) ->
    @getLoadedPackage(name)?

  # Public: Get an array of all the loaded packages
  getLoadedPackages: ->
    _.values(@loadedPackages)

  # Private: Get packages for a certain package type
  #
  # * types: an {Array} of {String}s like ['atom', 'textmate']
  getLoadedPackagesForTypes: (types) ->
    pack for pack in @getLoadedPackages() when pack.getType() in types

  # Public: Resolve the given package name to a path on disk.
  resolvePackagePath: (name) ->
    return name if fs.isDirectorySync(name)

    packagePath = fs.resolve(@packageDirPaths..., name)
    return packagePath if fs.isDirectorySync(packagePath)

    packagePath = path.join(@resourcePath, 'node_modules', name)
    return packagePath if @hasAtomEngine(packagePath)

  # Public: Is the package with the given name disabled?
  isPackageDisabled: (name) ->
    _.include(atom.config.get('core.disabledPackages') ? [], name)

  # Private:
  hasAtomEngine: (packagePath) ->
    metadata = Package.loadMetadata(packagePath, true)
    metadata?.engines?.atom?

  # Public: Is the package with the given name bundled with Atom?
  isBundledPackage: (name) ->
    @getPackageDependencies().hasOwnProperty(name)

  # Private:
  getPackageDependencies: ->
    unless @packageDependencies?
      try
        metadataPath = path.join(@resourcePath, 'package.json')
        {@packageDependencies} = JSON.parse(fs.readFileSync(metadataPath)) ? {}
      @packageDependencies ?= {}

    @packageDependencies

  # Public: Get an array of all the available package paths.
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

  # Public: Get an array of all the available package names.
  getAvailablePackageNames: ->
    _.uniq _.map @getAvailablePackagePaths(), (packagePath) -> path.basename(packagePath)

  # Public: Get an array of all the available package metadata.
  getAvailablePackageMetadata: ->
    packages = []
    for packagePath in @getAvailablePackagePaths()
      name = path.basename(packagePath)
      metadata = @getLoadedPackage(name)?.metadata ? Package.loadMetadata(packagePath, true)
      packages.push(metadata)
    packages
