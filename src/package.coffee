path = require 'path'

_ = require 'underscore-plus'
async = require 'async'
CSON = require 'season'
fs = require 'fs-plus'
{Emitter, CompositeDisposable} = require 'event-kit'

CompileCache = require './compile-cache'
ModuleCache = require './module-cache'
ScopedProperties = require './scoped-properties'
BufferedProcess = require './buffered-process'

# Extended: Loads and activates a package's main module and resources such as
# stylesheets, keymaps, grammar, editor properties, and menus.
module.exports =
class Package
  keymaps: null
  menus: null
  stylesheets: null
  stylesheetDisposables: null
  grammars: null
  settings: null
  mainModulePath: null
  resolvedMainModulePath: false
  mainModule: null
  mainInitialized: false
  mainActivated: false

  ###
  Section: Construction
  ###

  constructor: (params) ->
    {
      @path, @metadata, @bundledPackage, @preloadedPackage, @packageManager, @config, @styleManager, @commandRegistry,
      @keymapManager, @notificationManager, @grammarRegistry, @themeManager,
      @menuManager, @contextMenuManager, @deserializerManager, @viewRegistry
    } = params

    @emitter = new Emitter
    @metadata ?= @packageManager.loadPackageMetadata(@path)
    @bundledPackage ?= @packageManager.isBundledPackagePath(@path)
    @name = @metadata?.name ? params.name ? path.basename(@path)
    @reset()

  ###
  Section: Event Subscription
  ###

  # Essential: Invoke the given callback when all packages have been activated.
  #
  # * `callback` {Function}
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidDeactivate: (callback) ->
    @emitter.on 'did-deactivate', callback

  ###
  Section: Instance Methods
  ###

  enable: ->
    @config.removeAtKeyPath('core.disabledPackages', @name)

  disable: ->
    @config.pushAtKeyPath('core.disabledPackages', @name)

  isTheme: ->
    @metadata?.theme?

  measure: (key, fn) ->
    startTime = Date.now()
    value = fn()
    @[key] = Date.now() - startTime
    value

  getType: -> 'atom'

  getStyleSheetPriority: -> 0

  preload: ->
    @loadKeymaps()
    @loadMenus()
    @registerDeserializerMethods()
    @activateCoreStartupServices()
    @registerURIHandler()
    @configSchemaRegisteredOnLoad = @registerConfigSchemaFromMetadata()
    @requireMainModule()
    @settingsPromise = @loadSettings()

    @activationDisposables = new CompositeDisposable
    @activateKeymaps()
    @activateMenus()
    settings.activate() for settings in @settings
    @settingsActivated = true

  finishLoading: ->
    @measure 'loadTime', =>
      @path = path.join(@packageManager.resourcePath, @path)
      ModuleCache.add(@path, @metadata)

      @loadStylesheets()
      # Unfortunately some packages are accessing `@mainModulePath`, so we need
      # to compute that variable eagerly also for preloaded packages.
      @getMainModulePath()

  load: ->
    @measure 'loadTime', =>
      try
        ModuleCache.add(@path, @metadata)

        @loadKeymaps()
        @loadMenus()
        @loadStylesheets()
        @registerDeserializerMethods()
        @activateCoreStartupServices()
        @registerURIHandler()
        @registerTranspilerConfig()
        @configSchemaRegisteredOnLoad = @registerConfigSchemaFromMetadata()
        @settingsPromise = @loadSettings()
        if @shouldRequireMainModuleOnLoad() and not @mainModule?
          @requireMainModule()
      catch error
        @handleError("Failed to load the #{@name} package", error)
    this

  unload: ->
    @unregisterTranspilerConfig()

  shouldRequireMainModuleOnLoad: ->
    not (
      @metadata.deserializers? or
      @metadata.viewProviders? or
      @metadata.configSchema? or
      @activationShouldBeDeferred() or
      localStorage.getItem(@getCanDeferMainModuleRequireStorageKey()) is 'true'
    )

  reset: ->
    @stylesheets = []
    @keymaps = []
    @menus = []
    @grammars = []
    @settings = []
    @mainInitialized = false
    @mainActivated = false

  initializeIfNeeded: ->
    return if @mainInitialized
    @measure 'initializeTime', =>
      try
        # The main module's `initialize()` method is guaranteed to be called
        # before its `activate()`. This gives you a chance to handle the
        # serialized package state before the package's derserializers and view
        # providers are used.
        @requireMainModule() unless @mainModule?
        @mainModule.initialize?(@packageManager.getPackageState(@name) ? {})
        @mainInitialized = true
      catch error
        @handleError("Failed to initialize the #{@name} package", error)
    return

  activate: ->
    @grammarsPromise ?= @loadGrammars()
    @activationPromise ?=
      new Promise (resolve, reject) =>
        @resolveActivationPromise = resolve
        @measure 'activateTime', =>
          try
            @activateResources()
            if @activationShouldBeDeferred()
              @subscribeToDeferredActivation()
            else
              @activateNow()
          catch error
            @handleError("Failed to activate the #{@name} package", error)

    Promise.all([@grammarsPromise, @settingsPromise, @activationPromise])

  activateNow: ->
    try
      @requireMainModule() unless @mainModule?
      @configSchemaRegisteredOnActivate = @registerConfigSchemaFromMainModule()
      @registerViewProviders()
      @activateStylesheets()
      if @mainModule? and not @mainActivated
        @initializeIfNeeded()
        @mainModule.activateConfig?()
        @mainModule.activate?(@packageManager.getPackageState(@name) ? {})
        @mainActivated = true
        @activateServices()
      @activationCommandSubscriptions?.dispose()
      @activationHookSubscriptions?.dispose()
    catch error
      @handleError("Failed to activate the #{@name} package", error)

    @resolveActivationPromise?()

  registerConfigSchemaFromMetadata: ->
    if configSchema = @metadata.configSchema
      @config.setSchema @name, {type: 'object', properties: configSchema}
      true
    else
      false

  registerConfigSchemaFromMainModule: ->
    if @mainModule? and not @configSchemaRegisteredOnLoad
      if @mainModule.config? and typeof @mainModule.config is 'object'
        @config.setSchema @name, {type: 'object', properties: @mainModule.config}
        return true
    false

  # TODO: Remove. Settings view calls this method currently.
  activateConfig: ->
    return if @configSchemaRegisteredOnLoad
    @requireMainModule()
    @registerConfigSchemaFromMainModule()

  activateStylesheets: ->
    return if @stylesheetsActivated

    @stylesheetDisposables = new CompositeDisposable

    priority = @getStyleSheetPriority()
    for [sourcePath, source] in @stylesheets
      if match = path.basename(sourcePath).match(/[^.]*\.([^.]*)\./)
        context = match[1]
      else if @metadata.theme is 'syntax'
        context = 'atom-text-editor'
      else
        context = undefined

      @stylesheetDisposables.add(
        @styleManager.addStyleSheet(
          source,
          {
            sourcePath,
            priority,
            context,
            skipDeprecatedSelectorsTransformation: @bundledPackage
          }
        )
      )
    @stylesheetsActivated = true

  activateResources: ->
    @activationDisposables ?= new CompositeDisposable

    keymapIsDisabled = _.include(@config.get("core.packagesWithKeymapsDisabled") ? [], @name)
    if keymapIsDisabled
      @deactivateKeymaps()
    else unless @keymapActivated
      @activateKeymaps()

    unless @menusActivated
      @activateMenus()

    unless @grammarsActivated
      grammar.activate() for grammar in @grammars
      @grammarsActivated = true

    unless @settingsActivated
      settings.activate() for settings in @settings
      @settingsActivated = true

  activateKeymaps: ->
    return if @keymapActivated

    @keymapDisposables = new CompositeDisposable()

    validateSelectors = not @preloadedPackage
    @keymapDisposables.add(@keymapManager.add(keymapPath, map, 0, validateSelectors)) for [keymapPath, map] in @keymaps
    @menuManager.update()

    @keymapActivated = true

  deactivateKeymaps: ->
    return if not @keymapActivated

    @keymapDisposables?.dispose()
    @menuManager.update()

    @keymapActivated = false

  hasKeymaps: ->
    for [path, map] in @keymaps
      if map.length > 0
        return true
    false

  activateMenus: ->
    validateSelectors = not @preloadedPackage
    for [menuPath, map] in @menus when map['context-menu']?
      try
        itemsBySelector = map['context-menu']
        @activationDisposables.add(@contextMenuManager.add(itemsBySelector, validateSelectors))
      catch error
        if error.code is 'EBADSELECTOR'
          error.message += " in #{menuPath}"
          error.stack += "\n  at #{menuPath}:1:1"
        throw error

    for [menuPath, map] in @menus when map['menu']?
      @activationDisposables.add(@menuManager.add(map['menu']))

    @menusActivated = true

  activateServices: ->
    for name, {versions} of @metadata.providedServices
      servicesByVersion = {}
      for version, methodName of versions
        if typeof @mainModule[methodName] is 'function'
          servicesByVersion[version] = @mainModule[methodName]()
      @activationDisposables.add @packageManager.serviceHub.provide(name, servicesByVersion)

    for name, {versions} of @metadata.consumedServices
      for version, methodName of versions
        if typeof @mainModule[methodName] is 'function'
          @activationDisposables.add @packageManager.serviceHub.consume(name, version, @mainModule[methodName].bind(@mainModule))
    return

  registerURIHandler: ->
    handlerConfig = @getURIHandler()
    if methodName = handlerConfig?.method
      @uriHandlerSubscription = @packageManager.registerURIHandlerForPackage @name, (args...) =>
        @handleURI(methodName, args)

  unregisterURIHandler: ->
    @uriHandlerSubscription?.dispose()

  handleURI: (methodName, args) ->
    @activate().then => @mainModule[methodName]?.apply(@mainModule, args)
    @activateNow() unless @mainActivated

  registerTranspilerConfig: ->
    if @metadata.atomTranspilers
      CompileCache.addTranspilerConfigForPath(@path, @name, @metadata, @metadata.atomTranspilers)

  unregisterTranspilerConfig: ->
    if @metadata.atomTranspilers
      CompileCache.removeTranspilerConfigForPath(@path)

  loadKeymaps: ->
    if @bundledPackage and @packageManager.packagesCache[@name]?
      @keymaps = (["core:#{keymapPath}", keymapObject] for keymapPath, keymapObject of @packageManager.packagesCache[@name].keymaps)
    else
      @keymaps = @getKeymapPaths().map (keymapPath) -> [keymapPath, CSON.readFileSync(keymapPath, allowDuplicateKeys: false) ? {}]
    return

  loadMenus: ->
    if @bundledPackage and @packageManager.packagesCache[@name]?
      @menus = (["core:#{menuPath}", menuObject] for menuPath, menuObject of @packageManager.packagesCache[@name].menus)
    else
      @menus = @getMenuPaths().map (menuPath) -> [menuPath, CSON.readFileSync(menuPath) ? {}]
    return

  getKeymapPaths: ->
    keymapsDirPath = path.join(@path, 'keymaps')
    if @metadata.keymaps
      @metadata.keymaps.map (name) -> fs.resolve(keymapsDirPath, name, ['json', 'cson', ''])
    else
      fs.listSync(keymapsDirPath, ['cson', 'json'])

  getMenuPaths: ->
    menusDirPath = path.join(@path, 'menus')
    if @metadata.menus
      @metadata.menus.map (name) -> fs.resolve(menusDirPath, name, ['json', 'cson', ''])
    else
      fs.listSync(menusDirPath, ['cson', 'json'])

  loadStylesheets: ->
    @stylesheets = @getStylesheetPaths().map (stylesheetPath) =>
      [stylesheetPath, @themeManager.loadStylesheet(stylesheetPath, true)]

  registerDeserializerMethods: ->
    if @metadata.deserializers?
      Object.keys(@metadata.deserializers).forEach (deserializerName) =>
        methodName = @metadata.deserializers[deserializerName]
        @deserializerManager.add
          name: deserializerName,
          deserialize: (state, atomEnvironment) =>
            @registerViewProviders()
            @requireMainModule()
            @initializeIfNeeded()
            @mainModule[methodName](state, atomEnvironment)
      return

  activateCoreStartupServices: ->
    if directoryProviderService = @metadata.providedServices?['atom.directory-provider']
      @requireMainModule()
      servicesByVersion = {}
      for version, methodName of directoryProviderService.versions
        if typeof @mainModule[methodName] is 'function'
          servicesByVersion[version] = @mainModule[methodName]()
      @packageManager.serviceHub.provide('atom.directory-provider', servicesByVersion)

  registerViewProviders: ->
    if @metadata.viewProviders? and not @registeredViewProviders
      @requireMainModule()
      @metadata.viewProviders.forEach (methodName) =>
        @viewRegistry.addViewProvider (model) =>
          @initializeIfNeeded()
          @mainModule[methodName](model)
      @registeredViewProviders = true

  getStylesheetsPath: ->
    path.join(@path, 'styles')

  getStylesheetPaths: ->
    if @bundledPackage and @packageManager.packagesCache[@name]?.styleSheetPaths?
      styleSheetPaths = @packageManager.packagesCache[@name].styleSheetPaths
      styleSheetPaths.map (styleSheetPath) => path.join(@path, styleSheetPath)
    else
      stylesheetDirPath = @getStylesheetsPath()
      if @metadata.mainStyleSheet
        [fs.resolve(@path, @metadata.mainStyleSheet)]
      else if @metadata.styleSheets
        @metadata.styleSheets.map (name) -> fs.resolve(stylesheetDirPath, name, ['css', 'less', ''])
      else if indexStylesheet = fs.resolve(@path, 'index', ['css', 'less'])
        [indexStylesheet]
      else
        fs.listSync(stylesheetDirPath, ['css', 'less'])

  loadGrammarsSync: ->
    return if @grammarsLoaded

    if @preloadedPackage and @packageManager.packagesCache[@name]?
      grammarPaths = @packageManager.packagesCache[@name].grammarPaths
    else
      grammarPaths = fs.listSync(path.join(@path, 'grammars'), ['json', 'cson'])

    for grammarPath in grammarPaths
      if @preloadedPackage and @packageManager.packagesCache[@name]?
        grammarPath = path.resolve(@packageManager.resourcePath, grammarPath)

      try
        grammar = @grammarRegistry.readGrammarSync(grammarPath)
        grammar.packageName = @name
        grammar.bundledPackage = @bundledPackage
        @grammars.push(grammar)
        grammar.activate()
      catch error
        console.warn("Failed to load grammar: #{grammarPath}", error.stack ? error)

    @grammarsLoaded = true
    @grammarsActivated = true

  loadGrammars: ->
    return Promise.resolve() if @grammarsLoaded

    loadGrammar = (grammarPath, callback) =>
      if @preloadedPackage
        grammarPath = path.resolve(@packageManager.resourcePath, grammarPath)

      @grammarRegistry.readGrammar grammarPath, (error, grammar) =>
        if error?
          detail = "#{error.message} in #{grammarPath}"
          stack = "#{error.stack}\n  at #{grammarPath}:1:1"
          @notificationManager.addFatalError("Failed to load a #{@name} package grammar", {stack, detail, packageName: @name, dismissable: true})
        else
          grammar.packageName = @name
          grammar.bundledPackage = @bundledPackage
          @grammars.push(grammar)
          grammar.activate() if @grammarsActivated
        callback()

    new Promise (resolve) =>
      if @preloadedPackage and @packageManager.packagesCache[@name]?
        grammarPaths = @packageManager.packagesCache[@name].grammarPaths
        async.each grammarPaths, loadGrammar, -> resolve()
      else
        grammarsDirPath = path.join(@path, 'grammars')
        fs.exists grammarsDirPath, (grammarsDirExists) ->
          return resolve() unless grammarsDirExists

          fs.list grammarsDirPath, ['json', 'cson'], (error, grammarPaths=[]) ->
            async.each grammarPaths, loadGrammar, -> resolve()

  loadSettings: ->
    @settings = []

    loadSettingsFile = (settingsPath, callback) =>
      ScopedProperties.load settingsPath, @config, (error, settings) =>
        if error?
          detail = "#{error.message} in #{settingsPath}"
          stack = "#{error.stack}\n  at #{settingsPath}:1:1"
          @notificationManager.addFatalError("Failed to load the #{@name} package settings", {stack, detail, packageName: @name, dismissable: true})
        else
          @settings.push(settings)
          settings.activate() if @settingsActivated
        callback()

    new Promise (resolve) =>
      if @preloadedPackage and @packageManager.packagesCache[@name]?
        for settingsPath, scopedProperties of @packageManager.packagesCache[@name].settings
          settings = new ScopedProperties("core:#{settingsPath}", scopedProperties ? {}, @config)
          @settings.push(settings)
          settings.activate() if @settingsActivated
        resolve()
      else
        settingsDirPath = path.join(@path, 'settings')
        fs.exists settingsDirPath, (settingsDirExists) ->
          return resolve() unless settingsDirExists

          fs.list settingsDirPath, ['json', 'cson'], (error, settingsPaths=[]) ->
            async.each settingsPaths, loadSettingsFile, -> resolve()

  serialize: ->
    if @mainActivated
      try
        @mainModule?.serialize?()
      catch e
        console.error "Error serializing package '#{@name}'", e.stack

  deactivate: ->
    @activationPromise = null
    @resolveActivationPromise = null
    @activationCommandSubscriptions?.dispose()
    @activationHookSubscriptions?.dispose()
    @configSchemaRegisteredOnActivate = false
    @unregisterURIHandler()
    @deactivateResources()
    @deactivateKeymaps()

    unless @mainActivated
      @emitter.emit 'did-deactivate'
      return

    try
      deactivationResult = @mainModule?.deactivate?()
    catch e
      console.error "Error deactivating package '#{@name}'", e.stack

    # We support then-able async promises as well as sync ones from deactivate
    if typeof deactivationResult?.then is 'function'
      deactivationResult.then => @afterDeactivation()
    else
      @afterDeactivation()

  afterDeactivation: ->
    try
      @mainModule?.deactivateConfig?()
    catch e
      console.error "Error deactivating package '#{@name}'", e.stack
    @mainActivated = false
    @mainInitialized = false
    @emitter.emit 'did-deactivate'

  deactivateResources: ->
    grammar.deactivate() for grammar in @grammars
    settings.deactivate() for settings in @settings
    @stylesheetDisposables?.dispose()
    @activationDisposables?.dispose()
    @keymapDisposables?.dispose()
    @stylesheetsActivated = false
    @grammarsActivated = false
    @settingsActivated = false
    @menusActivated = false

  reloadStylesheets: ->
    try
      @loadStylesheets()
    catch error
      @handleError("Failed to reload the #{@name} package stylesheets", error)

    @stylesheetDisposables?.dispose()
    @stylesheetDisposables = new CompositeDisposable
    @stylesheetsActivated = false
    @activateStylesheets()

  requireMainModule: ->
    if @bundledPackage and @packageManager.packagesCache[@name]?
      if @packageManager.packagesCache[@name].main?
        @mainModule = require(@packageManager.packagesCache[@name].main)
    else if @mainModuleRequired
      @mainModule
    else if not @isCompatible()
      console.warn """
        Failed to require the main module of '#{@name}' because it requires one or more incompatible native modules (#{_.pluck(@incompatibleModules, 'name').join(', ')}).
        Run `apm rebuild` in the package directory and restart Atom to resolve.
      """
      return
    else
      mainModulePath = @getMainModulePath()
      if fs.isFileSync(mainModulePath)
        @mainModuleRequired = true

        previousViewProviderCount = @viewRegistry.getViewProviderCount()
        previousDeserializerCount = @deserializerManager.getDeserializerCount()
        @mainModule = require(mainModulePath)
        if (@viewRegistry.getViewProviderCount() is previousViewProviderCount and
            @deserializerManager.getDeserializerCount() is previousDeserializerCount)
          localStorage.setItem(@getCanDeferMainModuleRequireStorageKey(), 'true')

  getMainModulePath: ->
    return @mainModulePath if @resolvedMainModulePath
    @resolvedMainModulePath = true

    if @bundledPackage and @packageManager.packagesCache[@name]?
      if @packageManager.packagesCache[@name].main
        @mainModulePath = path.resolve(@packageManager.resourcePath, 'static', @packageManager.packagesCache[@name].main)
      else
        @mainModulePath = null
    else
      mainModulePath =
        if @metadata.main
          path.join(@path, @metadata.main)
        else
          path.join(@path, 'index')
      @mainModulePath = fs.resolveExtension(mainModulePath, ["", CompileCache.supportedExtensions...])

  activationShouldBeDeferred: ->
    @hasActivationCommands() or @hasActivationHooks() or @hasDeferredURIHandler()

  hasActivationHooks: ->
    @getActivationHooks()?.length > 0

  hasActivationCommands: ->
    for selector, commands of @getActivationCommands()
      return true if commands.length > 0
    false

  hasDeferredURIHandler: ->
    @getURIHandler() and @getURIHandler().deferActivation isnt false

  subscribeToDeferredActivation: ->
    @subscribeToActivationCommands()
    @subscribeToActivationHooks()

  subscribeToActivationCommands: ->
    @activationCommandSubscriptions = new CompositeDisposable
    for selector, commands of @getActivationCommands()
      for command in commands
        do (selector, command) =>
          # Add dummy command so it appears in menu.
          # The real command will be registered on package activation
          try
            @activationCommandSubscriptions.add @commandRegistry.add selector, command, ->
          catch error
            if error.code is 'EBADSELECTOR'
              metadataPath = path.join(@path, 'package.json')
              error.message += " in #{metadataPath}"
              error.stack += "\n  at #{metadataPath}:1:1"
            throw error

          @activationCommandSubscriptions.add @commandRegistry.onWillDispatch (event) =>
            return unless event.type is command
            currentTarget = event.target
            while currentTarget
              if currentTarget.webkitMatchesSelector(selector)
                @activationCommandSubscriptions.dispose()
                @activateNow()
                break
              currentTarget = currentTarget.parentElement
            return
    return

  getActivationCommands: ->
    return @activationCommands if @activationCommands?

    @activationCommands = {}

    if @metadata.activationCommands?
      for selector, commands of @metadata.activationCommands
        @activationCommands[selector] ?= []
        if _.isString(commands)
          @activationCommands[selector].push(commands)
        else if _.isArray(commands)
          @activationCommands[selector].push(commands...)

    @activationCommands

  subscribeToActivationHooks: ->
    @activationHookSubscriptions = new CompositeDisposable
    for hook in @getActivationHooks()
      do (hook) =>
        @activationHookSubscriptions.add(@packageManager.onDidTriggerActivationHook(hook, => @activateNow())) if hook? and _.isString(hook) and hook.trim().length > 0

    return

  getActivationHooks: ->
    return @activationHooks if @metadata? and @activationHooks?

    @activationHooks = []

    if @metadata.activationHooks?
      if _.isArray(@metadata.activationHooks)
        @activationHooks.push(@metadata.activationHooks...)
      else if _.isString(@metadata.activationHooks)
        @activationHooks.push(@metadata.activationHooks)

    @activationHooks = _.uniq(@activationHooks)

  getURIHandler: ->
    @metadata?.uriHandler

  # Does the given module path contain native code?
  isNativeModule: (modulePath) ->
    try
      fs.listSync(path.join(modulePath, 'build', 'Release'), ['.node']).length > 0
    catch error
      false

  # Get an array of all the native modules that this package depends on.
  #
  # First try to get this information from
  # @metadata._atomModuleCache.extensions. If @metadata._atomModuleCache doesn't
  # exist, recurse through all dependencies.
  getNativeModuleDependencyPaths: ->
    nativeModulePaths = []

    if @metadata._atomModuleCache?
      relativeNativeModuleBindingPaths = @metadata._atomModuleCache.extensions?['.node'] ? []
      for relativeNativeModuleBindingPath in relativeNativeModuleBindingPaths
        nativeModulePath = path.join(@path, relativeNativeModuleBindingPath, '..', '..', '..')
        nativeModulePaths.push(nativeModulePath)
      return nativeModulePaths

    traversePath = (nodeModulesPath) =>
      try
        for modulePath in fs.listSync(nodeModulesPath)
          nativeModulePaths.push(modulePath) if @isNativeModule(modulePath)
          traversePath(path.join(modulePath, 'node_modules'))
      return

    traversePath(path.join(@path, 'node_modules'))
    nativeModulePaths

  ###
  Section: Native Module Compatibility
  ###

  # Extended: Are all native modules depended on by this package correctly
  # compiled against the current version of Atom?
  #
  # Incompatible packages cannot be activated.
  #
  # Returns a {Boolean}, true if compatible, false if incompatible.
  isCompatible: ->
    return @compatible if @compatible?

    if @preloadedPackage
      # Preloaded packages are always considered compatible
      @compatible = true
    else if @getMainModulePath()
      @incompatibleModules = @getIncompatibleNativeModules()
      @compatible = @incompatibleModules.length is 0 and not @getBuildFailureOutput()?
    else
      @compatible = true

  # Extended: Rebuild native modules in this package's dependencies for the
  # current version of Atom.
  #
  # Returns a {Promise} that resolves with an object containing `code`,
  # `stdout`, and `stderr` properties based on the results of running
  # `apm rebuild` on the package.
  rebuild: ->
    new Promise (resolve) =>
      @runRebuildProcess (result) =>
        if result.code is 0
          global.localStorage.removeItem(@getBuildFailureOutputStorageKey())
        else
          @compatible = false
          global.localStorage.setItem(@getBuildFailureOutputStorageKey(), result.stderr)
        global.localStorage.setItem(@getIncompatibleNativeModulesStorageKey(), '[]')
        resolve(result)

  # Extended: If a previous rebuild failed, get the contents of stderr.
  #
  # Returns a {String} or null if no previous build failure occurred.
  getBuildFailureOutput: ->
    global.localStorage.getItem(@getBuildFailureOutputStorageKey())

  runRebuildProcess: (callback) ->
    stderr = ''
    stdout = ''
    new BufferedProcess({
      command: @packageManager.getApmPath()
      args: ['rebuild', '--no-color']
      options: {cwd: @path}
      stderr: (output) -> stderr += output
      stdout: (output) -> stdout += output
      exit: (code) -> callback({code, stdout, stderr})
    })

  getBuildFailureOutputStorageKey: ->
    "installed-packages:#{@name}:#{@metadata.version}:build-error"

  getIncompatibleNativeModulesStorageKey: ->
    electronVersion = process.versions.electron
    "installed-packages:#{@name}:#{@metadata.version}:electron-#{electronVersion}:incompatible-native-modules"

  getCanDeferMainModuleRequireStorageKey: ->
    "installed-packages:#{@name}:#{@metadata.version}:can-defer-main-module-require"

  # Get the incompatible native modules that this package depends on.
  # This recurses through all dependencies and requires all modules that
  # contain a `.node` file.
  #
  # This information is cached in local storage on a per package/version basis
  # to minimize the impact on startup time.
  getIncompatibleNativeModules: ->
    unless @packageManager.devMode
      try
        if arrayAsString = global.localStorage.getItem(@getIncompatibleNativeModulesStorageKey())
          return JSON.parse(arrayAsString)

    incompatibleNativeModules = []
    for nativeModulePath in @getNativeModuleDependencyPaths()
      try
        require(nativeModulePath)
      catch error
        try
          version = require("#{nativeModulePath}/package.json").version
        incompatibleNativeModules.push
          path: nativeModulePath
          name: path.basename(nativeModulePath)
          version: version
          error: error.message

    global.localStorage.setItem(@getIncompatibleNativeModulesStorageKey(), JSON.stringify(incompatibleNativeModules))
    incompatibleNativeModules

  handleError: (message, error) ->
    if atom.inSpecMode()
      throw error

    if error.filename and error.location and (error instanceof SyntaxError)
      location = "#{error.filename}:#{error.location.first_line + 1}:#{error.location.first_column + 1}"
      detail = "#{error.message} in #{location}"
      stack = """
        SyntaxError: #{error.message}
          at #{location}
      """
    else if error.less and error.filename and error.column? and error.line?
      # Less errors
      location = "#{error.filename}:#{error.line}:#{error.column}"
      detail = "#{error.message} in #{location}"
      stack = """
        LessError: #{error.message}
          at #{location}
      """
    else
      detail = error.message
      stack = error.stack ? error

    @notificationManager.addFatalError(message, {stack, detail, packageName: @name, dismissable: true})
