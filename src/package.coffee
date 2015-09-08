path = require 'path'
normalizePackageData = null

_ = require 'underscore-plus'
async = require 'async'
CSON = require 'season'
fs = require 'fs-plus'
{Emitter, CompositeDisposable} = require 'event-kit'
Q = require 'q'
{includeDeprecatedAPIs, deprecate} = require 'grim'

ModuleCache = require './module-cache'
ScopedProperties = require './scoped-properties'
BufferedProcess = require './buffered-process'

packagesCache = require('../package.json')?._atomPackages ? {}

# Loads and activates a package's main module and resources such as
# stylesheets, keymaps, grammar, editor properties, and menus.
module.exports =
class Package
  @isBundledPackagePath: (packagePath) ->
    if atom.packages.devMode
      return false unless atom.packages.resourcePath.startsWith("#{process.resourcesPath}#{path.sep}")

    @resourcePathWithTrailingSlash ?= "#{atom.packages.resourcePath}#{path.sep}"
    packagePath?.startsWith(@resourcePathWithTrailingSlash)

  @normalizeMetadata: (metadata) ->
    unless metadata?._id
      normalizePackageData ?= require 'normalize-package-data'
      normalizePackageData(metadata)
      if metadata.repository?.type is 'git' and typeof metadata.repository.url is 'string'
        metadata.repository.url = metadata.repository.url.replace(/^git\+/, '')

  @loadMetadata: (packagePath, ignoreErrors=false) ->
    packageName = path.basename(packagePath)
    if @isBundledPackagePath(packagePath)
      metadata = packagesCache[packageName]?.metadata
    unless metadata?
      if metadataPath = CSON.resolve(path.join(packagePath, 'package'))
        try
          metadata = CSON.readFileSync(metadataPath)
          @normalizeMetadata(metadata)
        catch error
          throw error unless ignoreErrors

    metadata ?= {}
    unless typeof metadata.name is 'string' and metadata.name.length > 0
      metadata.name = packageName

    if includeDeprecatedAPIs and metadata.stylesheetMain?
      deprecate("Use the `mainStyleSheet` key instead of `stylesheetMain` in the `package.json` of `#{packageName}`", {packageName})
      metadata.mainStyleSheet = metadata.stylesheetMain

    if includeDeprecatedAPIs and metadata.stylesheets?
      deprecate("Use the `styleSheets` key instead of `stylesheets` in the `package.json` of `#{packageName}`", {packageName})
      metadata.styleSheets = metadata.stylesheets

    metadata

  keymaps: null
  menus: null
  stylesheets: null
  stylesheetDisposables: null
  grammars: null
  settings: null
  mainModulePath: null
  resolvedMainModulePath: false
  mainModule: null
  mainActivated: false

  ###
  Section: Construction
  ###

  constructor: (@path, @metadata) ->
    @emitter = new Emitter
    @metadata ?= Package.loadMetadata(@path)
    @bundledPackage = Package.isBundledPackagePath(@path)
    @name = @metadata?.name ? path.basename(@path)
    ModuleCache.add(@path, @metadata)
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
    atom.config.removeAtKeyPath('core.disabledPackages', @name)

  disable: ->
    atom.config.pushAtKeyPath('core.disabledPackages', @name)

  isTheme: ->
    @metadata?.theme?

  measure: (key, fn) ->
    startTime = Date.now()
    value = fn()
    @[key] = Date.now() - startTime
    value

  getType: -> 'atom'

  getStyleSheetPriority: -> 0

  load: ->
    @measure 'loadTime', =>
      try
        @loadKeymaps()
        @loadMenus()
        @loadStylesheets()
        @settingsPromise = @loadSettings()
        @requireMainModule() unless @mainModule? or @activationShouldBeDeferred()
      catch error
        @handleError("Failed to load the #{@name} package", error)
    this

  reset: ->
    @stylesheets = []
    @keymaps = []
    @menus = []
    @grammars = []
    @settings = []
    @mainActivated = false

  activate: ->
    @grammarsPromise ?= @loadGrammars()

    unless @activationDeferred?
      @activationDeferred = Q.defer()
      @measure 'activateTime', =>
        try
          @activateResources()
          if @activationShouldBeDeferred()
            @subscribeToDeferredActivation()
          else
            @activateNow()
        catch error
          @handleError("Failed to activate the #{@name} package", error)

    Q.all([@grammarsPromise, @settingsPromise, @activationDeferred.promise])

  activateNow: ->
    try
      @activateConfig()
      @activateStylesheets()
      if @mainModule? and not @mainActivated
        @mainModule.activate?(atom.packages.getPackageState(@name) ? {})
        @mainActivated = true
        @activateServices()
    catch error
      @handleError("Failed to activate the #{@name} package", error)

    @activationDeferred?.resolve()

  activateConfig: ->
    return if @configActivated

    @requireMainModule() unless @mainModule?
    if @mainModule?
      if @mainModule.config? and typeof @mainModule.config is 'object'
        atom.config.setSchema @name, {type: 'object', properties: @mainModule.config}
      else if @mainModule.configDefaults? and typeof @mainModule.configDefaults is 'object'
        deprecate("""Use a config schema instead. See the configuration section
        of https://atom.io/docs/latest/hacking-atom-package-word-count and
        https://atom.io/docs/api/latest/Config for more details""", {packageName: @name})
        atom.config.setDefaults(@name, @mainModule.configDefaults)
      @mainModule.activateConfig?()
    @configActivated = true

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

      @stylesheetDisposables.add(atom.styles.addStyleSheet(source, {sourcePath, priority, context}))
    @stylesheetsActivated = true

  activateResources: ->
    @activationDisposables = new CompositeDisposable

    keymapIsDisabled = _.include(atom.config.get("core.packagesWithKeymapsDisabled") ? [], @name)
    if keymapIsDisabled
      @deactivateKeymaps()
    else
      @activateKeymaps()

    for [menuPath, map] in @menus when map['context-menu']?
      try
        itemsBySelector = map['context-menu']

        # Detect deprecated format for items object
        for key, value of itemsBySelector
          unless _.isArray(value)
            deprecate("""
              The context menu CSON format has changed. Please see
              https://atom.io/docs/api/latest/ContextMenuManager#context-menu-cson-format
              for more info.
            """, {packageName: @name})
            itemsBySelector = atom.contextMenu.convertLegacyItemsBySelector(itemsBySelector)

        @activationDisposables.add(atom.contextMenu.add(itemsBySelector))
      catch error
        if error.code is 'EBADSELECTOR'
          error.message += " in #{menuPath}"
          error.stack += "\n  at #{menuPath}:1:1"
        throw error

    @activationDisposables.add(atom.menu.add(map['menu'])) for [menuPath, map] in @menus when map['menu']?

    unless @grammarsActivated
      grammar.activate() for grammar in @grammars
      @grammarsActivated = true

    settings.activate() for settings in @settings
    @settingsActivated = true

  activateKeymaps: ->
    return if @keymapActivated

    @keymapDisposables = new CompositeDisposable()

    @keymapDisposables.add(atom.keymaps.add(keymapPath, map)) for [keymapPath, map] in @keymaps
    atom.menu.update()

    @keymapActivated = true

  deactivateKeymaps: ->
    return if not @keymapActivated

    @keymapDisposables?.dispose()
    atom.menu.update()

    @keymapActivated = false

  hasKeymaps: ->
    for [path, map] in @keymaps
      if map.length > 0
        return true
    false

  activateServices: ->
    for name, {versions} of @metadata.providedServices
      servicesByVersion = {}
      for version, methodName of versions
        if typeof @mainModule[methodName] is 'function'
          servicesByVersion[version] = @mainModule[methodName]()
      @activationDisposables.add atom.packages.serviceHub.provide(name, servicesByVersion)

    for name, {versions} of @metadata.consumedServices
      for version, methodName of versions
        if typeof @mainModule[methodName] is 'function'
          @activationDisposables.add atom.packages.serviceHub.consume(name, version, @mainModule[methodName].bind(@mainModule))
    return

  loadKeymaps: ->
    if @bundledPackage and packagesCache[@name]?
      @keymaps = (["#{atom.packages.resourcePath}#{path.sep}#{keymapPath}", keymapObject] for keymapPath, keymapObject of packagesCache[@name].keymaps)
    else
      @keymaps = @getKeymapPaths().map (keymapPath) -> [keymapPath, CSON.readFileSync(keymapPath) ? {}]
    return

  loadMenus: ->
    if @bundledPackage and packagesCache[@name]?
      @menus = (["#{atom.packages.resourcePath}#{path.sep}#{menuPath}", menuObject] for menuPath, menuObject of packagesCache[@name].menus)
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
    @stylesheets = @getStylesheetPaths().map (stylesheetPath) ->
      [stylesheetPath, atom.themes.loadStylesheet(stylesheetPath, true)]

  getStylesheetsPath: ->
    if fs.isDirectorySync(path.join(@path, 'stylesheets'))
      deprecate("Store package style sheets in the `styles/` directory instead of `stylesheets/` in the `#{@name}` package", packageName: @name)
      path.join(@path, 'stylesheets')
    else
      path.join(@path, 'styles')

  getStylesheetPaths: ->
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

    grammarsDirPath = path.join(@path, 'grammars')
    grammarPaths = fs.listSync(grammarsDirPath, ['json', 'cson'])
    for grammarPath in grammarPaths
      try
        grammar = atom.grammars.readGrammarSync(grammarPath)
        grammar.packageName = @name
        grammar.bundledPackage = @bundledPackage
        @grammars.push(grammar)
        grammar.activate()
      catch error
        console.warn("Failed to load grammar: #{grammarPath}", error.stack ? error)

    @grammarsLoaded = true
    @grammarsActivated = true

  loadGrammars: ->
    return Q() if @grammarsLoaded

    loadGrammar = (grammarPath, callback) =>
      atom.grammars.readGrammar grammarPath, (error, grammar) =>
        if error?
          detail = "#{error.message} in #{grammarPath}"
          stack = "#{error.stack}\n  at #{grammarPath}:1:1"
          atom.notifications.addFatalError("Failed to load a #{@name} package grammar", {stack, detail, dismissable: true})
        else
          grammar.packageName = @name
          grammar.bundledPackage = @bundledPackage
          @grammars.push(grammar)
          grammar.activate() if @grammarsActivated
        callback()

    deferred = Q.defer()
    grammarsDirPath = path.join(@path, 'grammars')
    fs.exists grammarsDirPath, (grammarsDirExists) ->
      return deferred.resolve() unless grammarsDirExists

      fs.list grammarsDirPath, ['json', 'cson'], (error, grammarPaths=[]) ->
        async.each grammarPaths, loadGrammar, -> deferred.resolve()
    deferred.promise

  loadSettings: ->
    @settings = []

    loadSettingsFile = (settingsPath, callback) =>
      ScopedProperties.load settingsPath, (error, settings) =>
        if error?
          detail = "#{error.message} in #{settingsPath}"
          stack = "#{error.stack}\n  at #{settingsPath}:1:1"
          atom.notifications.addFatalError("Failed to load the #{@name} package settings", {stack, detail, dismissable: true})
        else
          @settings.push(settings)
          settings.activate() if @settingsActivated
        callback()

    deferred = Q.defer()

    if fs.isDirectorySync(path.join(@path, 'scoped-properties'))
      settingsDirPath = path.join(@path, 'scoped-properties')
      deprecate("Store package settings files in the `settings/` directory instead of `scoped-properties/`", packageName: @name)
    else
      settingsDirPath = path.join(@path, 'settings')

    fs.exists settingsDirPath, (settingsDirExists) ->
      return deferred.resolve() unless settingsDirExists

      fs.list settingsDirPath, ['json', 'cson'], (error, settingsPaths=[]) ->
        async.each settingsPaths, loadSettingsFile, -> deferred.resolve()
    deferred.promise

  serialize: ->
    if @mainActivated
      try
        @mainModule?.serialize?()
      catch e
        console.error "Error serializing package '#{@name}'", e.stack

  deactivate: ->
    @activationDeferred?.reject()
    @activationDeferred = null
    @activationCommandSubscriptions?.dispose()
    @deactivateResources()
    @deactivateConfig()
    @deactivateKeymaps()
    if @mainActivated
      try
        @mainModule?.deactivate?()
        @mainActivated = false
      catch e
        console.error "Error deactivating package '#{@name}'", e.stack
    @emit 'deactivated' if includeDeprecatedAPIs
    @emitter.emit 'did-deactivate'

  deactivateConfig: ->
    @mainModule?.deactivateConfig?()
    @configActivated = false

  deactivateResources: ->
    grammar.deactivate() for grammar in @grammars
    settings.deactivate() for settings in @settings
    @stylesheetDisposables?.dispose()
    @activationDisposables?.dispose()
    @keymapDisposables?.dispose()
    @stylesheetsActivated = false
    @grammarsActivated = false
    @settingsActivated = false

  reloadStylesheets: ->
    oldSheets = _.clone(@stylesheets)

    try
      @loadStylesheets()
    catch error
      @handleError("Failed to reload the #{@name} package stylesheets", error)

    @stylesheetDisposables?.dispose()
    @stylesheetDisposables = new CompositeDisposable
    @stylesheetsActivated = false
    @activateStylesheets()

  requireMainModule: ->
    return @mainModule if @mainModuleRequired
    unless @isCompatible()
      console.warn """
        Failed to require the main module of '#{@name}' because it requires an incompatible native module.
        Run `apm rebuild` in the package directory to resolve.
      """
      return
    mainModulePath = @getMainModulePath()
    if fs.isFileSync(mainModulePath)
      @mainModuleRequired = true
      @mainModule = require(mainModulePath)

  getMainModulePath: ->
    return @mainModulePath if @resolvedMainModulePath
    @resolvedMainModulePath = true

    if @bundledPackage and packagesCache[@name]?
      if packagesCache[@name].main
        @mainModulePath = "#{atom.packages.resourcePath}#{path.sep}#{packagesCache[@name].main}"
      else
        @mainModulePath = null
    else
      mainModulePath =
        if @metadata.main
          path.join(@path, @metadata.main)
        else
          path.join(@path, 'index')
      @mainModulePath = fs.resolveExtension(mainModulePath, ["", _.keys(require.extensions)...])

  activationShouldBeDeferred: ->
    @hasActivationCommands() or @hasActivationHooks()

  hasActivationHooks: ->
    @getActivationHooks()?.length > 0

  hasActivationCommands: ->
    for selector, commands of @getActivationCommands()
      return true if commands.length > 0
    false

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
            @activationCommandSubscriptions.add atom.commands.add selector, command, ->
          catch error
            if error.code is 'EBADSELECTOR'
              metadataPath = path.join(@path, 'package.json')
              error.message += " in #{metadataPath}"
              error.stack += "\n  at #{metadataPath}:1:1"
            throw error

          @activationCommandSubscriptions.add atom.commands.onWillDispatch (event) =>
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

    if @metadata.activationEvents?
      deprecate("""
        Use `activationCommands` instead of `activationEvents` in your package.json
        Commands should be grouped by selector as follows:
        ```json
          "activationCommands": {
            "atom-workspace": ["foo:bar", "foo:baz"],
            "atom-text-editor": ["foo:quux"]
          }
        ```
      """, {packageName: @name})
      if _.isArray(@metadata.activationEvents)
        for eventName in @metadata.activationEvents
          @activationCommands['atom-workspace'] ?= []
          @activationCommands['atom-workspace'].push(eventName)
      else if _.isString(@metadata.activationEvents)
        eventName = @metadata.activationEvents
        @activationCommands['atom-workspace'] ?= []
        @activationCommands['atom-workspace'].push(eventName)
      else
        for eventName, selector of @metadata.activationEvents
          selector ?= 'atom-workspace'
          @activationCommands[selector] ?= []
          @activationCommands[selector].push(eventName)

    @activationCommands

  subscribeToActivationHooks: ->
    @activationHookSubscriptions = new CompositeDisposable
    for hook in @getActivationHooks()
      do (hook) =>
        @activationHookSubscriptions.add(atom.packages.onDidTriggerActivationHook(hook, => @activateNow())) if hook? and _.isString(hook) and hook.trim().length > 0

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

  # Does the given module path contain native code?
  isNativeModule: (modulePath) ->
    try
      fs.listSync(path.join(modulePath, 'build', 'Release'), ['.node']).length > 0
    catch error
      false

  # Get an array of all the native modules that this package depends on.
  # This will recurse through all dependencies.
  getNativeModuleDependencyPaths: ->
    nativeModulePaths = []

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

    if @path.indexOf(path.join(atom.packages.resourcePath, 'node_modules') + path.sep) is 0
      # Bundled packages are always considered compatible
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
      command: atom.packages.getApmPath()
      args: ['rebuild', '--no-color']
      options: {cwd: @path}
      stderr: (output) -> stderr += output
      stdout: (output) -> stdout += output
      exit: (code) -> callback({code, stdout, stderr})
    })

  getBuildFailureOutputStorageKey: ->
    "installed-packages:#{@name}:#{@metadata.version}:build-error"

  getIncompatibleNativeModulesStorageKey: ->
    electronVersion = process.versions['electron'] ? process.versions['atom-shell']
    "installed-packages:#{@name}:#{@metadata.version}:electron-#{electronVersion}:incompatible-native-modules"

  # Get the incompatible native modules that this package depends on.
  # This recurses through all dependencies and requires all modules that
  # contain a `.node` file.
  #
  # This information is cached in local storage on a per package/version basis
  # to minimize the impact on startup time.
  getIncompatibleNativeModules: ->
    unless atom.inDevMode()
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

    atom.notifications.addFatalError(message, {stack, detail, dismissable: true})

if includeDeprecatedAPIs
  EmitterMixin = require('emissary').Emitter
  EmitterMixin.includeInto(Package)

  Package::on = (eventName) ->
    switch eventName
      when 'deactivated'
        deprecate 'Use Package::onDidDeactivate instead'
      else
        deprecate 'Package::on is deprecated. Use event subscription methods instead.'
    EmitterMixin::on.apply(this, arguments)
