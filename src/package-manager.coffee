path = require 'path'
normalizePackageData = null

_ = require 'underscore-plus'
{Emitter} = require 'event-kit'
fs = require 'fs-plus'
CSON = require 'season'

ServiceHub = require 'service-hub'
Package = require './package'
ThemePackage = require './theme-package'
{isDeprecatedPackage, getDeprecatedPackageMetadata} = require './deprecated-packages'

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
  constructor: (params) ->
    {
      configDirPath, @devMode, safeMode, @resourcePath, @config, @styleManager,
      @notificationManager, @keymapManager, @commandRegistry, @grammarRegistry
    } = params

    @emitter = new Emitter
    @activationHookEmitter = new Emitter
    @packageDirPaths = []
    @deferredActivationHooks = []
    if configDirPath? and not safeMode
      if @devMode
        @packageDirPaths.push(path.join(configDirPath, "dev", "packages"))
      @packageDirPaths.push(path.join(configDirPath, "packages"))

    @packagesCache = require('../package.json')?._atomPackages ? {}
    @loadedPackages = {}
    @activePackages = {}
    @packageStates = {}
    @serviceHub = new ServiceHub

    @packageActivators = []
    @registerPackageActivator(this, ['atom', 'textmate'])

  setContextMenuManager: (@contextMenuManager) ->

  setMenuManager: (@menuManager) ->

  setThemeManager: (@themeManager) ->

  reset: ->
    @serviceHub.clear()
    @deactivatePackages()
    @packageStates = {}

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

  # Public: Invoke the given callback when all packages have been activated.
  #
  # * `callback` {Function}
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidActivateInitialPackages: (callback) ->
    @emitter.on 'did-activate-initial-packages', callback

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
    apmRoot = path.join(process.resourcesPath, 'app', 'apm')
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

  isDeprecatedPackage: (name, version) ->
    isDeprecatedPackage(name, version)

  getDeprecatedPackageMetadata: (name) ->
    getDeprecatedPackageMetadata(name)

  ###
  Section: Enabling and disabling packages
  ###

  # Public: Enable the package with the given name.
  #
  # * `name` - The {String} package name.
  #
  # Returns the {Package} that was enabled or null if it isn't loaded.
  enablePackage: (name) ->
    pack = @loadPackage(name)
    pack?.enable()
    pack

  # Public: Disable the package with the given name.
  #
  # * `name` - The {String} package name.
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
    _.include(@config.get('core.disabledPackages') ? [], name)

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

  # Public: Returns an {Array} of {String}s of all the available package paths.
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

  # Public: Returns an {Array} of {String}s of all the available package names.
  getAvailablePackageNames: ->
    _.uniq _.map @getAvailablePackagePaths(), (packagePath) -> path.basename(packagePath)

  # Public: Returns an {Array} of {String}s of all the available package metadata.
  getAvailablePackageMetadata: ->
    packages = []
    for packagePath in @getAvailablePackagePaths()
      name = path.basename(packagePath)
      metadata = @getLoadedPackage(name)?.metadata ? @loadPackageMetadata(packagePath, true)
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
        @packageDependencies = require('../package.json')?.packageDependencies
      @packageDependencies ?= {}

    @packageDependencies

  hasAtomEngine: (packagePath) ->
    metadata = @loadPackageMetadata(packagePath, true)
    metadata?.engines?.atom?

  unobserveDisabledPackages: ->
    @disabledPackagesSubscription?.dispose()
    @disabledPackagesSubscription = null

  observeDisabledPackages: ->
    @disabledPackagesSubscription ?= @config.onDidChange 'core.disabledPackages', ({newValue, oldValue}) =>
      packagesToEnable = _.difference(oldValue, newValue)
      packagesToDisable = _.difference(newValue, oldValue)

      @deactivatePackage(packageName) for packageName in packagesToDisable when @getActivePackage(packageName)
      @activatePackage(packageName) for packageName in packagesToEnable
      null

  unobservePackagesWithKeymapsDisabled: ->
    @packagesWithKeymapsDisabledSubscription?.dispose()
    @packagesWithKeymapsDisabledSubscription = null

  observePackagesWithKeymapsDisabled: ->
    @packagesWithKeymapsDisabledSubscription ?= @config.onDidChange 'core.packagesWithKeymapsDisabled', ({newValue, oldValue}) =>
      keymapsToEnable = _.difference(oldValue, newValue)
      keymapsToDisable = _.difference(newValue, oldValue)

      for packageName in keymapsToDisable when not @isPackageDisabled(packageName)
        @getLoadedPackage(packageName)?.deactivateKeymaps()
      for packageName in keymapsToEnable when not @isPackageDisabled(packageName)
        @getLoadedPackage(packageName)?.activateKeymaps()
      null

  loadPackages: ->
    # Ensure atom exports is already in the require cache so the load time
    # of the first package isn't skewed by being the first to require atom
    require '../exports/atom'

    packagePaths = @getAvailablePackagePaths()
    packagePaths = packagePaths.filter (packagePath) => not @isPackageDisabled(path.basename(packagePath))
    packagePaths = _.uniq packagePaths, (packagePath) -> path.basename(packagePath)
    @loadPackage(packagePath) for packagePath in packagePaths
    @emitter.emit 'did-load-initial-packages'

  loadPackage: (nameOrPath) ->
    return pack if pack = @getLoadedPackage(nameOrPath)

    if packagePath = @resolvePackagePath(nameOrPath)
      name = path.basename(nameOrPath)
      return pack if pack = @getLoadedPackage(name)

      try
        metadata = @loadPackageMetadata(packagePath) ? {}
      catch error
        @handleMetadataError(error, packagePath)
        return null

      unless @isBundledPackage(metadata.name)
        if @isDeprecatedPackage(metadata.name, metadata.version)
          console.warn "Could not load #{metadata.name}@#{metadata.version} because it uses deprecated APIs that have been removed."
          return null

      options = {
        path: packagePath, metadata, packageManager: this, @config, @styleManager,
        @commandRegistry, @keymapManager, @devMode, @notificationManager,
        @grammarRegistry, @themeManager, @menuManager, @contextMenuManager
      }
      if metadata.theme
        pack = new ThemePackage(options)
      else
        pack = new Package(options)
      pack.load()
      @loadedPackages[pack.name] = pack
      @emitter.emit 'did-load-package', pack
      return pack
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
    Promise.all(promises).then =>
      @triggerDeferredActivationHooks()
      @emitter.emit 'did-activate-initial-packages'

  # another type of package manager can handle other package types.
  # See ThemeManager
  registerPackageActivator: (activator, types) ->
    @packageActivators.push([activator, types])

  activatePackages: (packages) ->
    promises = []
    @config.transactAsync =>
      for pack in packages
        promise = @activatePackage(pack.name)
        promises.push(promise) unless pack.activationShouldBeDeferred()
      Promise.all(promises)
    @observeDisabledPackages()
    @observePackagesWithKeymapsDisabled()
    promises

  # Activate a single package by name
  activatePackage: (name) ->
    if pack = @getActivePackage(name)
      Promise.resolve(pack)
    else if pack = @loadPackage(name)
      pack.activate().then =>
        @activePackages[pack.name] = pack
        @emitter.emit 'did-activate-package', pack
        pack
    else
      Promise.reject(new Error("Failed to load package '#{name}'"))

  triggerDeferredActivationHooks: ->
    return unless @deferredActivationHooks?
    @activationHookEmitter.emit(hook) for hook in @deferredActivationHooks
    @deferredActivationHooks = null

  triggerActivationHook: (hook) ->
    return new Error("Cannot trigger an empty activation hook") unless hook? and _.isString(hook) and hook.length > 0
    if @deferredActivationHooks?
      @deferredActivationHooks.push hook
    else
      @activationHookEmitter.emit(hook)

  onDidTriggerActivationHook: (hook, callback) ->
    return unless hook? and _.isString(hook) and hook.length > 0
    @activationHookEmitter.on(hook, callback)

  # Deactivate all packages
  deactivatePackages: ->
    @config.transact =>
      @deactivatePackage(pack.name) for pack in @getLoadedPackages()
      return
    @unobserveDisabledPackages()
    @unobservePackagesWithKeymapsDisabled()

  # Deactivate the package with the given name
  deactivatePackage: (name) ->
    pack = @getLoadedPackage(name)
    if @isPackageActive(name)
      @setPackageState(pack.name, state) if state = pack.serialize?()
    pack.deactivate()
    delete @activePackages[pack.name]
    @emitter.emit 'did-deactivate-package', pack

  handleMetadataError: (error, packagePath) ->
    metadataPath = path.join(packagePath, 'package.json')
    detail = "#{error.message} in #{metadataPath}"
    stack = "#{error.stack}\n  at #{metadataPath}:1:1"
    message = "Failed to load the #{path.basename(packagePath)} package"
    @notificationManager.addError(message, {stack, detail, packageName: path.basename(packagePath), dismissable: true})

  uninstallDirectory: (directory) ->
    symlinkPromise = new Promise (resolve) ->
      fs.isSymbolicLink directory, (isSymLink) -> resolve(isSymLink)

    dirPromise = new Promise (resolve) ->
      fs.isDirectory directory, (isDir) -> resolve(isDir)

    Promise.all([symlinkPromise, dirPromise]).then (values) ->
      [isSymLink, isDir] = values
      if not isSymLink and isDir
        fs.remove directory, ->

  reloadActivePackageStyleSheets: ->
    for pack in @getActivePackages() when pack.getType() isnt 'theme'
      pack.reloadStylesheets?()
    return

  isBundledPackagePath: (packagePath) ->
    if @devMode
      return false unless @resourcePath.startsWith("#{process.resourcesPath}#{path.sep}")

    @resourcePathWithTrailingSlash ?= "#{@resourcePath}#{path.sep}"
    packagePath?.startsWith(@resourcePathWithTrailingSlash)

  loadPackageMetadata: (packagePath, ignoreErrors=false) ->
    packageName = path.basename(packagePath)
    if @isBundledPackagePath(packagePath)
      metadata = @packagesCache[packageName]?.metadata
    unless metadata?
      if metadataPath = CSON.resolve(path.join(packagePath, 'package'))
        try
          metadata = CSON.readFileSync(metadataPath)
          @normalizePackageMetadata(metadata)
        catch error
          throw error unless ignoreErrors

    metadata ?= {}
    unless typeof metadata.name is 'string' and metadata.name.length > 0
      metadata.name = packageName

    metadata

  normalizePackageMetadata: (metadata) ->
    unless metadata?._id
      normalizePackageData ?= require 'normalize-package-data'
      normalizePackageData(metadata)
      if metadata.repository?.type is 'git' and typeof metadata.repository.url is 'string'
        metadata.repository.url = metadata.repository.url.replace(/^git\+/, '')
