path = require 'path'

_ = require 'underscore-plus'
EmitterMixin = require('emissary').Emitter
{Emitter} = require 'event-kit'
fs = require 'fs-plus'
Q = require 'q'
Grim = require 'grim'

ServiceHub = require 'service-hub'
Package = require './package'
ThemePackage = require './theme-package'

# Extended: Package manager for coordinating the lifecycle of Atom packages.
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
# Packages can be enabled/disabled via the `core.disabledPackages` config
# settings and also by calling `enablePackage()/disablePackage()`.
module.exports =
class PackageManager
  EmitterMixin.includeInto(this)

  constructor: ({configDirPath, @devMode, safeMode, @resourcePath}) ->
    @emitter = new Emitter
    @packageDirPaths = []
    unless safeMode
      if @devMode
        @packageDirPaths.push(path.join(configDirPath, "dev", "packages"))
      @packageDirPaths.push(path.join(configDirPath, "packages"))

    @loadedPackages = {}
    @activePackages = {}
    @packageStates = {}
    @serviceHub = new ServiceHub

    @packageActivators = []
    @registerPackageActivator(this, ['atom', 'textmate'])

  ###
  Section: Event Subscription
  ###

  # Public: Invoke the given callback when all packages have been loaded.
  #
  # * `callback` {Function}
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidLoadInitialPackages: (callback) ->
    @emitter.on 'did-load-initial-packages', callback
    @emitter.on 'did-load-all', callback # TODO: Remove once deprecated pre-1.0 APIs are gone

  onDidLoadAll: (callback) ->
    Grim.deprecate("Use `::onDidLoadInitialPackages` instead.")
    @onDidLoadInitialPackages(callback)

  # Public: Invoke the given callback when all packages have been activated.
  #
  # * `callback` {Function}
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidActivateInitialPackages: (callback) ->
    @emitter.on 'did-activate-initial-packages', callback
    @emitter.on 'did-activate-all', callback # TODO: Remove once deprecated pre-1.0 APIs are gone

  onDidActivateAll: (callback) ->
    Grim.deprecate("Use `::onDidActivateInitialPackages` instead.")
    @onDidActivateInitialPackages(callback)

  # Public: Invoke the given callback when a package is activated.
  #
  # * `callback` A {Function} to be invoked when a package is activated.
  #   * `package` The {Package} that was activated.
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidActivatePackage: (callback) ->
    @emitter.on 'did-activate-package', callback

  # Public: Invoke the given callback when a package is deactivated.
  #
  # * `callback` A {Function} to be invoked when a package is deactivated.
  #   * `package` The {Package} that was deactivated.
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidDeactivatePackage: (callback) ->
    @emitter.on 'did-deactivate-package', callback

  # Public: Invoke the given callback when a package is loaded.
  #
  # * `callback` A {Function} to be invoked when a package is loaded.
  #   * `package` The {Package} that was loaded.
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidLoadPackage: (callback) ->
    @emitter.on 'did-load-package', callback

  # Public: Invoke the given callback when a package is unloaded.
  #
  # * `callback` A {Function} to be invoked when a package is unloaded.
  #   * `package` The {Package} that was unloaded.
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidUnloadPackage: (callback) ->
    @emitter.on 'did-unload-package', callback

  on: (eventName) ->
    switch eventName
      when 'loaded'
        Grim.deprecate 'Use PackageManager::onDidLoadInitialPackages instead'
      when 'activated'
        Grim.deprecate 'Use PackageManager::onDidActivateInitialPackages instead'
      else
        Grim.deprecate 'PackageManager::on is deprecated. Use event subscription methods instead.'
    EmitterMixin::on.apply(this, arguments)

  ###
  Section: Package system data
  ###

  # Public: Get the path to the apm command.
  #
  # Return a {String} file path to apm.
  getApmPath: ->
    return @apmPath if @apmPath?

    commandName = 'apm'
    commandName += '.cmd' if process.platform is 'win32'
    apmRoot = path.resolve(__dirname, '..', 'apm')
    @apmPath = path.join(apmRoot, 'bin', commandName)
    unless fs.isFileSync(@apmPath)
      @apmPath = path.join(apmRoot, 'node_modules', 'atom-package-manager', 'bin', commandName)
    @apmPath

  # Public: Get the paths being used to look for packages.
  #
  # Returns an {Array} of {String} directory paths.
  getPackageDirPaths: ->
    _.clone(@packageDirPaths)

  ###
  Section: General package data
  ###

  # Public: Resolve the given package name to a path on disk.
  #
  # * `name` - The {String} package name.
  #
  # Return a {String} folder path or undefined if it could not be resolved.
  resolvePackagePath: (name) ->
    return name if fs.isDirectorySync(name)

    packagePath = fs.resolve(@packageDirPaths..., name)
    return packagePath if fs.isDirectorySync(packagePath)

    packagePath = path.join(@resourcePath, 'node_modules', name)
    return packagePath if @hasAtomEngine(packagePath)

  # Public: Is the package with the given name bundled with Atom?
  #
  # * `name` - The {String} package name.
  #
  # Returns a {Boolean}.
  isBundledPackage: (name) ->
    @getPackageDependencies().hasOwnProperty(name)

  ###
  Section: Enabling and disabling packages
  ###

  # Public: Enable the package with the given name.
  #
  # Returns the {Package} that was enabled or null if it isn't loaded.
  enablePackage: (name) ->
    pack = @loadPackage(name)
    pack?.enable()
    pack

  # Public: Disable the package with the given name.
  #
  # Returns the {Package} that was disabled or null if it isn't loaded.
  disablePackage: (name) ->
    pack = @loadPackage(name)
    pack?.disable()
    pack

  # Public: Is the package with the given name disabled?
  #
  # * `name` - The {String} package name.
  #
  # Returns a {Boolean}.
  isPackageDisabled: (name) ->
    _.include(atom.config.get('core.disabledPackages') ? [], name)

  ###
  Section: Accessing active packages
  ###

  # Public: Get an {Array} of all the active {Package}s.
  getActivePackages: ->
    _.values(@activePackages)

  # Public: Get the active {Package} with the given name.
  #
  # * `name` - The {String} package name.
  #
  # Returns a {Package} or undefined.
  getActivePackage: (name) ->
    @activePackages[name]

  # Public: Is the {Package} with the given name active?
  #
  # * `name` - The {String} package name.
  #
  # Returns a {Boolean}.
  isPackageActive: (name) ->
    @getActivePackage(name)?

  ###
  Section: Accessing loaded packages
  ###

  # Public: Get an {Array} of all the loaded {Package}s
  getLoadedPackages: ->
    _.values(@loadedPackages)

  # Get packages for a certain package type
  #
  # * `types` an {Array} of {String}s like ['atom', 'textmate'].
  getLoadedPackagesForTypes: (types) ->
    pack for pack in @getLoadedPackages() when pack.getType() in types

  # Public: Get the loaded {Package} with the given name.
  #
  # * `name` - The {String} package name.
  #
  # Returns a {Package} or undefined.
  getLoadedPackage: (name) ->
    @loadedPackages[name]

  # Public: Is the package with the given name loaded?
  #
  # * `name` - The {String} package name.
  #
  # Returns a {Boolean}.
  isPackageLoaded: (name) ->
    @getLoadedPackage(name)?

  ###
  Section: Accessing available packages
  ###

  # Public: Get an {Array} of {String}s of all the available package paths.
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

  # Public: Get an {Array} of {String}s of all the available package names.
  getAvailablePackageNames: ->
    _.uniq _.map @getAvailablePackagePaths(), (packagePath) -> path.basename(packagePath)

  # Public: Get an {Array} of {String}s of all the available package metadata.
  getAvailablePackageMetadata: ->
    packages = []
    for packagePath in @getAvailablePackagePaths()
      name = path.basename(packagePath)
      metadata = @getLoadedPackage(name)?.metadata ? Package.loadMetadata(packagePath, true)
      packages.push(metadata)
    packages

  ###
  Section: Private
  ###

  getPackageState: (name) ->
    @packageStates[name]

  setPackageState: (name, state) ->
    @packageStates[name] = state

  getPackageDependencies: ->
    unless @packageDependencies?
      try
        metadataPath = path.join(@resourcePath, 'package.json')
        {@packageDependencies} = JSON.parse(fs.readFileSync(metadataPath)) ? {}
      @packageDependencies ?= {}

    @packageDependencies

  hasAtomEngine: (packagePath) ->
    metadata = Package.loadMetadata(packagePath, true)
    metadata?.engines?.atom?

  unobserveDisabledPackages: ->
    @disabledPackagesSubscription?.dispose()
    @disabledPackagesSubscription = null

  observeDisabledPackages: ->
    @disabledPackagesSubscription ?= atom.config.onDidChange 'core.disabledPackages', ({newValue, oldValue}) =>
      packagesToEnable = _.difference(oldValue, newValue)
      packagesToDisable = _.difference(newValue, oldValue)

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
    @emitter.emit 'did-load-initial-packages'

  loadPackage: (nameOrPath) ->
    return pack if pack = @getLoadedPackage(nameOrPath)

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
        @emitter.emit 'did-load-package', pack
        return pack
      catch error
        console.warn "Failed to load package.json '#{path.basename(packagePath)}'", error.stack ? error
    else
      console.warn "Could not resolve '#{nameOrPath}' to a package path"
    null

  unloadPackages: ->
    @unloadPackage(name) for name in _.keys(@loadedPackages)
    null

  unloadPackage: (name) ->
    if @isPackageActive(name)
      throw new Error("Tried to unload active package '#{name}'")

    if pack = @getLoadedPackage(name)
      delete @loadedPackages[pack.name]
      @emitter.emit 'did-unload-package', pack
    else
      throw new Error("No loaded package for name '#{name}'")

  # Activate all the packages that should be activated.
  activate: ->
    promises = []
    for [activator, types] in @packageActivators
      packages = @getLoadedPackagesForTypes(types)
      promises = promises.concat(activator.activatePackages(packages))
    Q.all(promises).then =>
      @emit 'activated'
      @emitter.emit 'did-activate-initial-packages'

  # another type of package manager can handle other package types.
  # See ThemeManager
  registerPackageActivator: (activator, types) ->
    @packageActivators.push([activator, types])

  activatePackages: (packages) ->
    promises = []
    atom.config.transact =>
      for pack in packages
        promise = @activatePackage(pack.name)
        promises.push(promise) unless pack.hasActivationCommands()
    @observeDisabledPackages()
    promises

  # Activate a single package by name
  activatePackage: (name) ->
    if pack = @getActivePackage(name)
      Q(pack)
    else if pack = @loadPackage(name)
      pack.activate().then =>
        @activePackages[pack.name] = pack
        @emitter.emit 'did-activate-package', pack
        pack
    else
      Q.reject(new Error("Failed to load package '#{name}'"))

  # Deactivate all packages
  deactivatePackages: ->
    atom.config.transact =>
      @deactivatePackage(pack.name) for pack in @getLoadedPackages()
    @unobserveDisabledPackages()

  # Deactivate the package with the given name
  deactivatePackage: (name) ->
    pack = @getLoadedPackage(name)
    if @isPackageActive(name)
      @setPackageState(pack.name, state) if state = pack.serialize?()
    pack.deactivate()
    delete @activePackages[pack.name]
    @emitter.emit 'did-deactivate-package', pack
