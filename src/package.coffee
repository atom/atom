path = require 'path'

_ = require 'underscore-plus'
async = require 'async'
CSON = require 'season'
fs = require 'fs-plus'
EmitterMixin = require('emissary').Emitter
{Emitter, CompositeDisposable} = require 'event-kit'
Q = require 'q'
{deprecate} = require 'grim'

ModuleCache = require './module-cache'
ScopedProperties = require './scoped-properties'

try
  packagesCache = require('../package.json')?._atomPackages ? {}
catch error
  packagesCache = {}

# Loads and activates a package's main module and resources such as
# stylesheets, keymaps, grammar, editor properties, and menus.
module.exports =
class Package
  EmitterMixin.includeInto(this)

  @stylesheetsDir: 'stylesheets'

  @isBundledPackagePath: (packagePath) ->
    if atom.packages.devMode
      return false unless atom.packages.resourcePath.startsWith("#{process.resourcesPath}#{path.sep}")

    @resourcePathWithTrailingSlash ?= "#{atom.packages.resourcePath}#{path.sep}"
    packagePath?.startsWith(@resourcePathWithTrailingSlash)

  @loadMetadata: (packagePath, ignoreErrors=false) ->
    packageName = path.basename(packagePath)
    if @isBundledPackagePath(packagePath)
      metadata = packagesCache[packageName]?.metadata
    unless metadata?
      if metadataPath = CSON.resolve(path.join(packagePath, 'package'))
        try
          metadata = CSON.readFileSync(metadataPath)
        catch error
          throw error unless ignoreErrors
    metadata ?= {}
    metadata.name = packageName
    metadata

  keymaps: null
  menus: null
  stylesheets: null
  stylesheetDisposables: null
  grammars: null
  scopedProperties: null
  mainModulePath: null
  resolvedMainModulePath: false
  mainModule: null

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

  on: (eventName) ->
    switch eventName
      when 'deactivated'
        deprecate 'Use Package::onDidDeactivate instead'
      else
        deprecate 'Package::on is deprecated. Use event subscription methods instead.'
    EmitterMixin::on.apply(this, arguments)

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

  getStylesheetType: -> 'bundled'

  load: ->
    @measure 'loadTime', =>
      try
        @loadKeymaps()
        @loadMenus()
        @loadStylesheets()
        @scopedPropertiesPromise = @loadScopedProperties()
        @requireMainModule() unless @hasActivationCommands()

      catch error
        console.warn "Failed to load package named '#{@name}'", error.stack ? error
    this

  reset: ->
    @stylesheets = []
    @keymaps = []
    @menus = []
    @grammars = []
    @scopedProperties = []

  activate: ->
    @grammarsPromise ?= @loadGrammars()

    unless @activationDeferred?
      @activationDeferred = Q.defer()
      @measure 'activateTime', =>
        @activateResources()
        if @hasActivationCommands()
          @subscribeToActivationCommands()
        else
          @activateNow()

    Q.all([@grammarsPromise, @scopedPropertiesPromise, @activationDeferred.promise])

  activateNow: ->
    try
      @activateConfig()
      @activateStylesheets()
      if @requireMainModule()
        @mainModule.activate(atom.packages.getPackageState(@name) ? {})
        @mainActivated = true
    catch e
      console.warn "Failed to activate package named '#{@name}'", e.stack

    @activationDeferred?.resolve()

  activateConfig: ->
    return if @configActivated

    @requireMainModule()
    if @mainModule?
      if @mainModule.config? and typeof @mainModule.config is 'object'
        atom.config.setSchema @name, {type: 'object', properties: @mainModule.config}
      else if @mainModule.configDefaults? and typeof @mainModule.configDefaults is 'object'
        deprecate """Use a config schema instead. See the configuration section
        of https://atom.io/docs/latest/creating-a-package and
        https://atom.io/docs/api/latest/Config for more details"""
        atom.config.setDefaults(@name, @mainModule.configDefaults)
      @mainModule.activateConfig?()
    @configActivated = true

  activateStylesheets: ->
    return if @stylesheetsActivated

    group = @getStylesheetType()
    @stylesheetDisposables = new CompositeDisposable
    for [sourcePath, source] in @stylesheets
      if match = path.basename(sourcePath).match(/[^.]*\.([^.]*)\./)
        context = match[1]
      else if @metadata.theme is 'syntax'
        context = 'atom-text-editor'
      else
        context = undefined

      @stylesheetDisposables.add(atom.styles.addStyleSheet(source, {sourcePath, group, context}))
    @stylesheetsActivated = true

  activateResources: ->
    @activationDisposables = new CompositeDisposable
    @activationDisposables.add(atom.keymaps.add(keymapPath, map)) for [keymapPath, map] in @keymaps
    @activationDisposables.add(atom.contextMenu.add(map['context-menu'])) for [menuPath, map] in @menus when map['context-menu']?
    @activationDisposables.add(atom.menu.add(map['menu'])) for [menuPath, map] in @menus when map['menu']?

    unless @grammarsActivated
      grammar.activate() for grammar in @grammars
      @grammarsActivated = true

    scopedProperties.activate() for scopedProperties in @scopedProperties
    @scopedPropertiesActivated = true

  loadKeymaps: ->
    if @bundledPackage and packagesCache[@name]?
      @keymaps = (["#{atom.packages.resourcePath}#{path.sep}#{keymapPath}", keymapObject] for keymapPath, keymapObject of packagesCache[@name].keymaps)
    else
      @keymaps = @getKeymapPaths().map (keymapPath) -> [keymapPath, CSON.readFileSync(keymapPath)]

  loadMenus: ->
    if @bundledPackage and packagesCache[@name]?
      @menus = (["#{atom.packages.resourcePath}#{path.sep}#{menuPath}", menuObject] for menuPath, menuObject of packagesCache[@name].menus)
    else
      @menus = @getMenuPaths().map (menuPath) -> [menuPath, CSON.readFileSync(menuPath)]

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
    path.join(@path, @constructor.stylesheetsDir)

  getStylesheetPaths: ->
    stylesheetDirPath = @getStylesheetsPath()

    if @metadata.stylesheetMain
      [fs.resolve(@path, @metadata.stylesheetMain)]
    else if @metadata.stylesheets
      @metadata.stylesheets.map (name) -> fs.resolve(stylesheetDirPath, name, ['css', 'less', ''])
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
          console.warn("Failed to load grammar: #{grammarPath}", error.stack ? error)
        else
          grammar.packageName = @name
          @grammars.push(grammar)
          grammar.activate() if @grammarsActivated
        callback()

    deferred = Q.defer()
    grammarsDirPath = path.join(@path, 'grammars')
    fs.list grammarsDirPath, ['json', 'cson'], (error, grammarPaths=[]) ->
      async.each grammarPaths, loadGrammar, -> deferred.resolve()
    deferred.promise

  loadScopedProperties: ->
    @scopedProperties = []

    loadScopedPropertiesFile = (scopedPropertiesPath, callback) =>
      ScopedProperties.load scopedPropertiesPath, (error, scopedProperties) =>
        if error?
          console.warn("Failed to load scoped properties: #{scopedPropertiesPath}", error.stack ? error)
        else
          @scopedProperties.push(scopedProperties)
          scopedProperties.activate() if @scopedPropertiesActivated
        callback()

    deferred = Q.defer()
    scopedPropertiesDirPath = path.join(@path, 'scoped-properties')
    fs.list scopedPropertiesDirPath, ['json', 'cson'], (error, scopedPropertiesPaths=[]) ->
      async.each scopedPropertiesPaths, loadScopedPropertiesFile, -> deferred.resolve()
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
    if @mainActivated
      try
        @mainModule?.deactivate?()
      catch e
        console.error "Error deactivating package '#{@name}'", e.stack
    @emit 'deactivated'
    @emitter.emit 'did-deactivate'

  deactivateConfig: ->
    @mainModule?.deactivateConfig?()
    @configActivated = false

  deactivateResources: ->
    grammar.deactivate() for grammar in @grammars
    scopedProperties.deactivate() for scopedProperties in @scopedProperties
    @stylesheetDisposables?.dispose()
    @activationDisposables?.dispose()
    @stylesheetsActivated = false
    @grammarsActivated = false
    @scopedPropertiesActivated = false

  reloadStylesheets: ->
    oldSheets = _.clone(@stylesheets)
    @loadStylesheets()
    @stylesheetDisposables?.dispose()
    @stylesheetDisposables = new CompositeDisposable
    @stylesheetsActivated = false
    @activateStylesheets()

  requireMainModule: ->
    return @mainModule if @mainModule?
    unless @isCompatible()
      console.warn """
        Failed to require the main module of '#{@name}' because it requires an incompatible native module.
        Run `apm rebuild` in the package directory to resolve.
      """
      return
    mainModulePath = @getMainModulePath()
    @mainModule = require(mainModulePath) if fs.isFileSync(mainModulePath)

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

  hasActivationCommands: ->
    for selector, commands of @getActivationCommands()
      return true if commands.length > 0
    false

  subscribeToActivationCommands: ->
    @activationCommandSubscriptions = new CompositeDisposable
    for selector, commands of @getActivationCommands()
      for command in commands
        do (selector, command) =>
          # Add dummy command so it appears in menu.
          # The real command will be registered on package activation
          @activationCommandSubscriptions.add atom.commands.add selector, command, ->
          @activationCommandSubscriptions.add atom.commands.onWillDispatch (event) =>
            return unless event.type is command
            currentTarget = event.target
            while currentTarget
              if currentTarget.webkitMatchesSelector(selector)
                @activationCommandSubscriptions.dispose()
                @activateNow()
                break
              currentTarget = currentTarget.parentElement

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
      deprecate """
        Use `activationCommands` instead of `activationEvents` in your package.json
        Commands should be grouped by selector as follows:
        ```json
          "activationCommands": {
            "atom-workspace": ["foo:bar", "foo:baz"],
            "atom-text-editor": ["foo:quux"]
          }
        ```
      """
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

    traversePath(path.join(@path, 'node_modules'))
    nativeModulePaths

  # Get the incompatible native modules that this package depends on.
  # This recurses through all dependencies and requires all modules that
  # contain a `.node` file.
  #
  # This information is cached in local storage on a per package/version basis
  # to minimize the impact on startup time.
  getIncompatibleNativeModules: ->
    localStorageKey = "installed-packages:#{@name}:#{@metadata.version}"
    unless atom.inDevMode()
      try
        {incompatibleNativeModules} = JSON.parse(global.localStorage.getItem(localStorageKey)) ? {}
      return incompatibleNativeModules if incompatibleNativeModules?

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

    global.localStorage.setItem(localStorageKey, JSON.stringify({incompatibleNativeModules}))
    incompatibleNativeModules

  # Public: Is this package compatible with this version of Atom?
  #
  # Incompatible packages cannot be activated. This will include packages
  # installed to ~/.atom/packages that were built against node 0.11.10 but
  # now need to be upgrade to node 0.11.13.
  #
  # Returns a {Boolean}, true if compatible, false if incompatible.
  isCompatible: ->
    return @compatible if @compatible?

    if @path.indexOf(path.join(atom.packages.resourcePath, 'node_modules') + path.sep) is 0
      # Bundled packages are always considered compatible
      @compatible = true
    else if packageMain = @getMainModulePath()
      @incompatibleModules = @getIncompatibleNativeModules()
      @compatible = @incompatibleModules.length is 0
    else
      @compatible = true
