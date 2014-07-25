path = require 'path'

_ = require 'underscore-plus'
{Emitter} = require 'emissary'
fs = require 'fs-plus'
Q = require 'q'

Package = require './package'
ThemePackage = require './theme-package'

# Public: Package manager for coordinating the lifecycle of Atom packages.
#
# An instance of this class is always available as the `atom.packages` global.
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
module.exports =
class PackageManager
  Emitter.includeInto(this)

  constructor: ({configDirPath, devMode, safeMode, @resourcePath}) ->
    @packageDirPaths = []
    unless safeMode
      if devMode
        @packageDirPaths.push(path.join(configDirPath, "dev", "packages"))
      @packageDirPaths.push(path.join(configDirPath, "packages"))

    @loadedPackages = {}
    @activePackages = {}
    @packageStates = {}

    @packageActivators = []
    @registerPackageActivator(this, ['atom', 'textmate'])

  # Public: Get the path to the apm command
  getApmPath: ->
    commandName = 'apm'
    commandName += '.cmd' if process.platform is 'win32'
    @apmPath ?= path.resolve(__dirname, '..', 'apm', 'node_modules', 'atom-package-manager', 'bin', commandName)

  # Public: Get the paths being used to look for packages.
  #
  # Returns an Array of String directory paths.
  getPackageDirPaths: ->
    _.clone(@packageDirPaths)

  getPackageState: (name) ->
    @packageStates[name]

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

  # Activate all the packages that should be activated.
  activate: ->
    for [activator, types] in @packageActivators
      packages = @getLoadedPackagesForTypes(types)
      activator.activatePackages(packages)
    @emit 'activated'

  # another type of package manager can handle other package types.
  # See ThemeManager
  registerPackageActivator: (activator, types) ->
    @packageActivators.push([activator, types])

  activatePackages: (packages) ->
    @activatePackage(pack.name) for pack in packages
    @observeDisabledPackages()

  # Activate a single package by name
  activatePackage: (name) ->
    if pack = @getActivePackage(name)
      Q(pack)
    else
      pack = @loadPackage(name)
      pack.activate().then =>
        @activePackages[pack.name] = pack
        pack

  # Deactivate all packages
  deactivatePackages: ->
    @deactivatePackage(pack.name) for pack in @getLoadedPackages()
    @unobserveDisabledPackages()

  # Deactivate the package with the given name
  deactivatePackage: (name) ->
    pack = @getLoadedPackage(name)
    if @isPackageActive(name)
      @setPackageState(pack.name, state) if state = pack.serialize?()
    pack.deactivate()
    delete @activePackages[pack.name]

  # Public: Get an array of all the active packages
  getActivePackages: ->
    _.values(@activePackages)

  # Public: Get the active package with the given name
  getActivePackage: (name) ->
    @activePackages[name]

  # Public: Is the package with the given name active?
  isPackageActive: (name) ->
    @getActivePackage(name)?

  unobserveDisabledPackages: ->
    @disabledPackagesSubscription?.off()
    @disabledPackagesSubscription = null

  observeDisabledPackages: ->
    @disabledPackagesSubscription ?= atom.config.observe 'core.disabledPackages', callNow: false, (disabledPackages, {previous}) =>
      packagesToEnable = _.difference(previous, disabledPackages)
      packagesToDisable = _.difference(disabledPackages, previous)

      @deactivatePackage(packageName) for packageName in packagesToDisable when @getActivePackage(packageName)
      @activatePackage(packageName) for packageName in packagesToEnable
      null

  loadPackages: ->
    # Ensure atom exports is already in the require cache so the load time
    # of the first package isn't skewed by being the first to require atom
    require '../exports/atom'

    packagePaths = @getAvailablePackagePaths()
    packagePaths = packagePaths.filter (packagePath) => not @isPackageDisabled(path.basename(packagePath))
    packagePaths = _.uniq packagePaths, (packagePath) -> path.basename(packagePath)
    @loadPackage(packagePath) for packagePath in packagePaths
    @emit 'loaded'

  loadPackage: (nameOrPath) ->
    if packagePath = @resolvePackagePath(nameOrPath)
      name = path.basename(nameOrPath)
      return pack if pack = @getLoadedPackage(name)

      try
        metadata = Package.loadMetadata(packagePath) ? {}
        if metadata.theme
          pack = new ThemePackage(packagePath, metadata)
        else
          pack = new Package(packagePath, metadata)
        pack.load()
        @loadedPackages[pack.name] = pack
        pack
      catch error
        console.warn "Failed to load package.json '#{path.basename(packagePath)}'", error.stack ? error

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

  # Public: Get the loaded package with the given name
  getLoadedPackage: (name) ->
    @loadedPackages[name]

  # Public: Is the package with the given name loaded?
  isPackageLoaded: (name) ->
    @getLoadedPackage(name)?

  # Public: Get an array of all the loaded packages
  getLoadedPackages: ->
    _.values(@loadedPackages)

  # Get packages for a certain package type
  #
  # types - an {Array} of {String}s like ['atom', 'textmate'].
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

  hasAtomEngine: (packagePath) ->
    metadata = Package.loadMetadata(packagePath, true)
    metadata?.engines?.atom?

  # Public: Is the package with the given name bundled with Atom?
  isBundledPackage: (name) ->
    @getPackageDependencies().hasOwnProperty(name)

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
