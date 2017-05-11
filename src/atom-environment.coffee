crypto = require 'crypto'
path = require 'path'
{ipcRenderer} = require 'electron'

_ = require 'underscore-plus'
{deprecate} = require 'grim'
{CompositeDisposable, Disposable, Emitter} = require 'event-kit'
fs = require 'fs-plus'
{mapSourcePosition} = require '@atom/source-map-support'
Model = require './model'
WindowEventHandler = require './window-event-handler'
StateStore = require './state-store'
StorageFolder = require './storage-folder'
registerDefaultCommands = require './register-default-commands'
{updateProcessEnv} = require './update-process-env'
ConfigSchema = require './config-schema'

DeserializerManager = require './deserializer-manager'
ViewRegistry = require './view-registry'
NotificationManager = require './notification-manager'
Config = require './config'
KeymapManager = require './keymap-extensions'
TooltipManager = require './tooltip-manager'
CommandRegistry = require './command-registry'
GrammarRegistry = require './grammar-registry'
{HistoryManager, HistoryProject} = require './history-manager'
ReopenProjectMenuManager = require './reopen-project-menu-manager'
StyleManager = require './style-manager'
PackageManager = require './package-manager'
ThemeManager = require './theme-manager'
MenuManager = require './menu-manager'
ContextMenuManager = require './context-menu-manager'
CommandInstaller = require './command-installer'
Project = require './project'
TitleBar = require './title-bar'
Workspace = require './workspace'
PanelContainer = require './panel-container'
Panel = require './panel'
PaneContainer = require './pane-container'
PaneAxis = require './pane-axis'
Pane = require './pane'
Dock = require './dock'
Project = require './project'
TextEditor = require './text-editor'
TextBuffer = require 'text-buffer'
Gutter = require './gutter'
TextEditorRegistry = require './text-editor-registry'
AutoUpdateManager = require './auto-update-manager'

# Essential: Atom global for dealing with packages, themes, menus, and the window.
#
# An instance of this class is always available as the `atom` global.
module.exports =
class AtomEnvironment extends Model
  @version: 1  # Increment this when the serialization format changes

  lastUncaughtError: null

  ###
  Section: Properties
  ###

  # Public: A {CommandRegistry} instance
  commands: null

  # Public: A {Config} instance
  config: null

  # Public: A {Clipboard} instance
  clipboard: null

  # Public: A {ContextMenuManager} instance
  contextMenu: null

  # Public: A {MenuManager} instance
  menu: null

  # Public: A {KeymapManager} instance
  keymaps: null

  # Public: A {TooltipManager} instance
  tooltips: null

  # Public: A {NotificationManager} instance
  notifications: null

  # Public: A {Project} instance
  project: null

  # Public: A {GrammarRegistry} instance
  grammars: null

  # Public: A {HistoryManager} instance
  history: null

  # Public: A {PackageManager} instance
  packages: null

  # Public: A {ThemeManager} instance
  themes: null

  # Public: A {StyleManager} instance
  styles: null

  # Public: A {DeserializerManager} instance
  deserializers: null

  # Public: A {ViewRegistry} instance
  views: null

  # Public: A {Workspace} instance
  workspace: null

  # Public: A {TextEditorRegistry} instance
  textEditors: null

  # Private: An {AutoUpdateManager} instance
  autoUpdater: null

  saveStateDebounceInterval: 1000

  ###
  Section: Construction and Destruction
  ###

  # Call .loadOrCreate instead
  constructor: (params={}) ->
    {@applicationDelegate, @clipboard, @enablePersistence, onlyLoadBaseStyleSheets, @updateProcessEnv} = params

    @nextProxyRequestId = 0
    @unloaded = false
    @loadTime = null
    @emitter = new Emitter
    @disposables = new CompositeDisposable
    @deserializers = new DeserializerManager(this)
    @deserializeTimings = {}
    @views = new ViewRegistry(this)
    @notifications = new NotificationManager
    @updateProcessEnv ?= updateProcessEnv # For testing

    @stateStore = new StateStore('AtomEnvironments', 1)

    @config = new Config({notificationManager: @notifications, @enablePersistence})
    @config.setSchema null, {type: 'object', properties: _.clone(ConfigSchema)}

    @keymaps = new KeymapManager({notificationManager: @notifications})
    @tooltips = new TooltipManager(keymapManager: @keymaps, viewRegistry: @views)
    @commands = new CommandRegistry
    @grammars = new GrammarRegistry({@config})
    @styles = new StyleManager()
    @packages = new PackageManager({
      @config, styleManager: @styles,
      commandRegistry: @commands, keymapManager: @keymaps, notificationManager: @notifications,
      grammarRegistry: @grammars, deserializerManager: @deserializers, viewRegistry: @views
    })
    @themes = new ThemeManager({
      packageManager: @packages, @config, styleManager: @styles,
      notificationManager: @notifications, viewRegistry: @views
    })
    @menu = new MenuManager({keymapManager: @keymaps, packageManager: @packages})
    @contextMenu = new ContextMenuManager({keymapManager: @keymaps})
    @packages.setMenuManager(@menu)
    @packages.setContextMenuManager(@contextMenu)
    @packages.setThemeManager(@themes)

    @project = new Project({notificationManager: @notifications, packageManager: @packages, @config, @applicationDelegate})
    @commandInstaller = new CommandInstaller(@applicationDelegate)

    @textEditors = new TextEditorRegistry({
      @config, grammarRegistry: @grammars, assert: @assert.bind(this),
      packageManager: @packages
    })

    @workspace = new Workspace({
      @config, @project, packageManager: @packages, grammarRegistry: @grammars, deserializerManager: @deserializers,
      notificationManager: @notifications, @applicationDelegate, viewRegistry: @views, assert: @assert.bind(this),
      textEditorRegistry: @textEditors, styleManager: @styles, @enablePersistence
    })

    @themes.workspace = @workspace

    @autoUpdater = new AutoUpdateManager({@applicationDelegate})

    if @keymaps.canLoadBundledKeymapsFromMemory()
      @keymaps.loadBundledKeymaps()

    @registerDefaultCommands()
    @registerDefaultOpeners()
    @registerDefaultDeserializers()

    @windowEventHandler = new WindowEventHandler({atomEnvironment: this, @applicationDelegate})

    @history = new HistoryManager({@project, @commands, @stateStore})
    # Keep instances of HistoryManager in sync
    @disposables.add @history.onDidChangeProjects (e) =>
      @applicationDelegate.didChangeHistoryManager() unless e.reloaded

  initialize: (params={}) ->
    # This will force TextEditorElement to register the custom element, so that
    # using `document.createElement('atom-text-editor')` works if it's called
    # before opening a buffer.
    require './text-editor-element'

    {@window, @document, @blobStore, @configDirPath, onlyLoadBaseStyleSheets} = params
    {devMode, safeMode, resourcePath, clearWindowState} = @getLoadSettings()

    if clearWindowState
      @getStorageFolder().clear()
      @stateStore.clear()

    @views.initialize()

    ConfigSchema.projectHome = {
      type: 'string',
      default: path.join(fs.getHomeDirectory(), 'github'),
      description: 'The directory where projects are assumed to be located. Packages created using the Package Generator will be stored here by default.'
    }
    @config.initialize({@configDirPath, resourcePath, projectHomeSchema: ConfigSchema.projectHome})

    @menu.initialize({resourcePath})
    @contextMenu.initialize({resourcePath, devMode})

    @keymaps.configDirPath = @configDirPath
    @keymaps.resourcePath = resourcePath
    @keymaps.devMode = devMode
    unless @keymaps.canLoadBundledKeymapsFromMemory()
      @keymaps.loadBundledKeymaps()

    @commands.attach(@window)

    @styles.initialize({@configDirPath})
    @packages.initialize({devMode, @configDirPath, resourcePath, safeMode})
    @themes.initialize({@configDirPath, resourcePath, safeMode, devMode})

    @commandInstaller.initialize(@getVersion())
    @autoUpdater.initialize()

    @config.load()

    @themes.loadBaseStylesheets()
    @initialStyleElements = @styles.getSnapshot()
    @themes.initialLoadComplete = true if onlyLoadBaseStyleSheets
    @setBodyPlatformClass()

    @stylesElement = @styles.buildStylesElement()
    @document.head.appendChild(@stylesElement)

    @keymaps.subscribeToFileReadFailure()

    @installUncaughtErrorHandler()
    @attachSaveStateListeners()
    @windowEventHandler.initialize(@window, @document)

    @observeAutoHideMenuBar()

    @history.initialize(@window.localStorage)
    @disposables.add @applicationDelegate.onDidChangeHistoryManager(=> @history.loadState())

  preloadPackages: ->
    @packages.preloadPackages()

  attachSaveStateListeners: ->
    saveState = _.debounce((=>
      window.requestIdleCallback => @saveState({isUnloading: false}) unless @unloaded
    ), @saveStateDebounceInterval)
    @document.addEventListener('mousedown', saveState, true)
    @document.addEventListener('keydown', saveState, true)
    @disposables.add new Disposable =>
      @document.removeEventListener('mousedown', saveState, true)
      @document.removeEventListener('keydown', saveState, true)

  registerDefaultDeserializers: ->
    @deserializers.add(Workspace)
    @deserializers.add(PaneContainer)
    @deserializers.add(PaneAxis)
    @deserializers.add(Pane)
    @deserializers.add(Dock)
    @deserializers.add(Project)
    @deserializers.add(TextEditor)
    @deserializers.add(TextBuffer)

  registerDefaultCommands: ->
    registerDefaultCommands({commandRegistry: @commands, @config, @commandInstaller, notificationManager: @notifications, @project, @clipboard})

  registerDefaultOpeners: ->
    @workspace.addOpener (uri) =>
      switch uri
        when 'atom://.atom/stylesheet'
          @workspace.openTextFile(@styles.getUserStyleSheetPath())
        when 'atom://.atom/keymap'
          @workspace.openTextFile(@keymaps.getUserKeymapPath())
        when 'atom://.atom/config'
          @workspace.openTextFile(@config.getUserConfigPath())
        when 'atom://.atom/init-script'
          @workspace.openTextFile(@getUserInitScriptPath())

  registerDefaultTargetForKeymaps: ->
    @keymaps.defaultTarget = @workspace.getElement()

  observeAutoHideMenuBar: ->
    @disposables.add @config.onDidChange 'core.autoHideMenuBar', ({newValue}) =>
      @setAutoHideMenuBar(newValue)
    @setAutoHideMenuBar(true) if @config.get('core.autoHideMenuBar')

  reset: ->
    @deserializers.clear()
    @registerDefaultDeserializers()

    @config.clear()
    @config.setSchema null, {type: 'object', properties: _.clone(ConfigSchema)}

    @keymaps.clear()
    @keymaps.loadBundledKeymaps()

    @commands.clear()
    @registerDefaultCommands()

    @styles.restoreSnapshot(@initialStyleElements)

    @menu.clear()

    @clipboard.reset()

    @notifications.clear()

    @contextMenu.clear()

    @packages.reset()

    @workspace.reset(@packages)
    @registerDefaultOpeners()

    @project.reset(@packages)

    @workspace.subscribeToEvents()

    @grammars.clear()

    @textEditors.clear()

    @views.clear()

  destroy: ->
    return if not @project

    @disposables.dispose()
    @workspace?.destroy()
    @workspace = null
    @themes.workspace = null
    @project?.destroy()
    @project = null
    @commands.clear()
    @stylesElement.remove()
    @config.unobserveUserConfig()
    @autoUpdater.destroy()

    @uninstallWindowEventHandler()

  ###
  Section: Event Subscription
  ###

  # Extended: Invoke the given callback whenever {::beep} is called.
  #
  # * `callback` {Function} to be called whenever {::beep} is called.
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidBeep: (callback) ->
    @emitter.on 'did-beep', callback

  # Extended: Invoke the given callback when there is an unhandled error, but
  # before the devtools pop open
  #
  # * `callback` {Function} to be called whenever there is an unhandled error
  #   * `event` {Object}
  #     * `originalError` {Object} the original error object
  #     * `message` {String} the original error object
  #     * `url` {String} Url to the file where the error originated.
  #     * `line` {Number}
  #     * `column` {Number}
  #     * `preventDefault` {Function} call this to avoid popping up the dev tools.
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onWillThrowError: (callback) ->
    @emitter.on 'will-throw-error', callback

  # Extended: Invoke the given callback whenever there is an unhandled error.
  #
  # * `callback` {Function} to be called whenever there is an unhandled error
  #   * `event` {Object}
  #     * `originalError` {Object} the original error object
  #     * `message` {String} the original error object
  #     * `url` {String} Url to the file where the error originated.
  #     * `line` {Number}
  #     * `column` {Number}
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidThrowError: (callback) ->
    @emitter.on 'did-throw-error', callback

  # TODO: Make this part of the public API. We should make onDidThrowError
  # match the interface by only yielding an exception object to the handler
  # and deprecating the old behavior.
  onDidFailAssertion: (callback) ->
    @emitter.on 'did-fail-assertion', callback

  # Extended: Invoke the given callback as soon as the shell environment is
  # loaded (or immediately if it was already loaded).
  #
  # * `callback` {Function} to be called whenever there is an unhandled error
  whenShellEnvironmentLoaded: (callback) ->
    if @shellEnvironmentLoaded
      callback()
      new Disposable()
    else
      @emitter.once 'loaded-shell-environment', callback

  ###
  Section: Atom Details
  ###

  # Public: Returns a {Boolean} that is `true` if the current window is in development mode.
  inDevMode: ->
    @devMode ?= @getLoadSettings().devMode

  # Public: Returns a {Boolean} that is `true` if the current window is in safe mode.
  inSafeMode: ->
    @safeMode ?= @getLoadSettings().safeMode

  # Public: Returns a {Boolean} that is `true` if the current window is running specs.
  inSpecMode: ->
    @specMode ?= @getLoadSettings().isSpec

  # Returns a {Boolean} indicating whether this the first time the window's been
  # loaded.
  isFirstLoad: ->
    @firstLoad ?= @getLoadSettings().firstLoad

  # Public: Get the version of the Atom application.
  #
  # Returns the version text {String}.
  getVersion: ->
    @appVersion ?= @getLoadSettings().appVersion

  # Returns the release channel as a {String}. Will return one of `'dev', 'beta', 'stable'`
  getReleaseChannel: ->
    version = @getVersion()
    if version.indexOf('beta') > -1
      'beta'
    else if version.indexOf('dev') > -1
      'dev'
    else
      'stable'

  # Public: Returns a {Boolean} that is `true` if the current version is an official release.
  isReleasedVersion: ->
    not /\w{7}/.test(@getVersion()) # Check if the release is a 7-character SHA prefix

  # Public: Get the time taken to completely load the current window.
  #
  # This time include things like loading and activating packages, creating
  # DOM elements for the editor, and reading the config.
  #
  # Returns the {Number} of milliseconds taken to load the window or null
  # if the window hasn't finished loading yet.
  getWindowLoadTime: ->
    @loadTime

  # Public: Get the load settings for the current window.
  #
  # Returns an {Object} containing all the load setting key/value pairs.
  getLoadSettings: ->
    @applicationDelegate.getWindowLoadSettings()

  ###
  Section: Managing The Atom Window
  ###

  # Essential: Open a new Atom window using the given options.
  #
  # Calling this method without an options parameter will open a prompt to pick
  # a file/folder to open in the new window.
  #
  # * `params` An {Object} with the following keys:
  #   * `pathsToOpen`  An {Array} of {String} paths to open.
  #   * `newWindow` A {Boolean}, true to always open a new window instead of
  #     reusing existing windows depending on the paths to open.
  #   * `devMode` A {Boolean}, true to open the window in development mode.
  #     Development mode loads the Atom source from the locally cloned
  #     repository and also loads all the packages in ~/.atom/dev/packages
  #   * `safeMode` A {Boolean}, true to open the window in safe mode. Safe
  #     mode prevents all packages installed to ~/.atom/packages from loading.
  open: (params) ->
    @applicationDelegate.open(params)

  # Extended: Prompt the user to select one or more folders.
  #
  # * `callback` A {Function} to call once the user has confirmed the selection.
  #   * `paths` An {Array} of {String} paths that the user selected, or `null`
  #     if the user dismissed the dialog.
  pickFolder: (callback) ->
    @applicationDelegate.pickFolder(callback)

  # Essential: Close the current window.
  close: ->
    @applicationDelegate.closeWindow()

  # Essential: Get the size of current window.
  #
  # Returns an {Object} in the format `{width: 1000, height: 700}`
  getSize: ->
    @applicationDelegate.getWindowSize()

  # Essential: Set the size of current window.
  #
  # * `width` The {Number} of pixels.
  # * `height` The {Number} of pixels.
  setSize: (width, height) ->
    @applicationDelegate.setWindowSize(width, height)

  # Essential: Get the position of current window.
  #
  # Returns an {Object} in the format `{x: 10, y: 20}`
  getPosition: ->
    @applicationDelegate.getWindowPosition()

  # Essential: Set the position of current window.
  #
  # * `x` The {Number} of pixels.
  # * `y` The {Number} of pixels.
  setPosition: (x, y) ->
    @applicationDelegate.setWindowPosition(x, y)

  # Extended: Get the current window
  getCurrentWindow: ->
    @applicationDelegate.getCurrentWindow()

  # Extended: Move current window to the center of the screen.
  center: ->
    @applicationDelegate.centerWindow()

  # Extended: Focus the current window.
  focus: ->
    @applicationDelegate.focusWindow()
    @window.focus()

  # Extended: Show the current window.
  show: ->
    @applicationDelegate.showWindow()

  # Extended: Hide the current window.
  hide: ->
    @applicationDelegate.hideWindow()

  # Extended: Reload the current window.
  reload: ->
    @applicationDelegate.reloadWindow()

  # Extended: Relaunch the entire application.
  restartApplication: ->
    @applicationDelegate.restartApplication()

  # Extended: Returns a {Boolean} that is `true` if the current window is maximized.
  isMaximized: ->
    @applicationDelegate.isWindowMaximized()

  maximize: ->
    @applicationDelegate.maximizeWindow()

  # Extended: Returns a {Boolean} that is `true` if the current window is in full screen mode.
  isFullScreen: ->
    @applicationDelegate.isWindowFullScreen()

  # Extended: Set the full screen state of the current window.
  setFullScreen: (fullScreen=false) ->
    @applicationDelegate.setWindowFullScreen(fullScreen)

  # Extended: Toggle the full screen state of the current window.
  toggleFullScreen: ->
    @setFullScreen(not @isFullScreen())

  # Restore the window to its previous dimensions and show it.
  #
  # Restores the full screen and maximized state after the window has resized to
  # prevent resize glitches.
  displayWindow: ->
    @restoreWindowDimensions().then =>
      steps = [
        @restoreWindowBackground(),
        @show(),
        @focus()
      ]
      steps.push(@setFullScreen(true)) if @windowDimensions?.fullScreen
      steps.push(@maximize()) if @windowDimensions?.maximized and process.platform isnt 'darwin'
      Promise.all(steps)

  # Get the dimensions of this window.
  #
  # Returns an {Object} with the following keys:
  #   * `x`      The window's x-position {Number}.
  #   * `y`      The window's y-position {Number}.
  #   * `width`  The window's width {Number}.
  #   * `height` The window's height {Number}.
  getWindowDimensions: ->
    browserWindow = @getCurrentWindow()
    [x, y] = browserWindow.getPosition()
    [width, height] = browserWindow.getSize()
    maximized = browserWindow.isMaximized()
    {x, y, width, height, maximized}

  # Set the dimensions of the window.
  #
  # The window will be centered if either the x or y coordinate is not set
  # in the dimensions parameter. If x or y are omitted the window will be
  # centered. If height or width are omitted only the position will be changed.
  #
  # * `dimensions` An {Object} with the following keys:
  #   * `x` The new x coordinate.
  #   * `y` The new y coordinate.
  #   * `width` The new width.
  #   * `height` The new height.
  setWindowDimensions: ({x, y, width, height}) ->
    steps = []
    if width? and height?
      steps.push(@setSize(width, height))
    if x? and y?
      steps.push(@setPosition(x, y))
    else
      steps.push(@center())
    Promise.all(steps)

  # Returns true if the dimensions are useable, false if they should be ignored.
  # Work around for https://github.com/atom/atom-shell/issues/473
  isValidDimensions: ({x, y, width, height}={}) ->
    width > 0 and height > 0 and x + width > 0 and y + height > 0

  storeWindowDimensions: ->
    @windowDimensions = @getWindowDimensions()
    if @isValidDimensions(@windowDimensions)
      localStorage.setItem("defaultWindowDimensions", JSON.stringify(@windowDimensions))

  getDefaultWindowDimensions: ->
    {windowDimensions} = @getLoadSettings()
    return windowDimensions if windowDimensions?

    dimensions = null
    try
      dimensions = JSON.parse(localStorage.getItem("defaultWindowDimensions"))
    catch error
      console.warn "Error parsing default window dimensions", error
      localStorage.removeItem("defaultWindowDimensions")

    if @isValidDimensions(dimensions)
      dimensions
    else
      {width, height} = @applicationDelegate.getPrimaryDisplayWorkAreaSize()
      {x: 0, y: 0, width: Math.min(1024, width), height}

  restoreWindowDimensions: ->
    unless @windowDimensions? and @isValidDimensions(@windowDimensions)
      @windowDimensions = @getDefaultWindowDimensions()
    @setWindowDimensions(@windowDimensions).then => @windowDimensions

  restoreWindowBackground: ->
    if backgroundColor = window.localStorage.getItem('atom:window-background-color')
      @backgroundStylesheet = document.createElement('style')
      @backgroundStylesheet.type = 'text/css'
      @backgroundStylesheet.innerText = 'html, body { background: ' + backgroundColor + ' !important; }'
      document.head.appendChild(@backgroundStylesheet)

  storeWindowBackground: ->
    return if @inSpecMode()

    backgroundColor = @window.getComputedStyle(@workspace.getElement())['background-color']
    @window.localStorage.setItem('atom:window-background-color', backgroundColor)

  # Call this method when establishing a real application window.
  startEditorWindow: ->
    @unloaded = false
    updateProcessEnvPromise = @updateProcessEnv(@getLoadSettings().env)
    updateProcessEnvPromise.then =>
      @shellEnvironmentLoaded = true
      @emitter.emit('loaded-shell-environment')
      @packages.triggerActivationHook('core:loaded-shell-environment')

    loadStatePromise = @loadState().then (state) =>
      @windowDimensions = state?.windowDimensions
      @displayWindow().then =>
        @commandInstaller.installAtomCommand false, (error) ->
          console.warn error.message if error?
        @commandInstaller.installApmCommand false, (error) ->
          console.warn error.message if error?

        @disposables.add(@applicationDelegate.onDidOpenLocations(@openLocations.bind(this)))
        @disposables.add(@applicationDelegate.onApplicationMenuCommand(@dispatchApplicationMenuCommand.bind(this)))
        @disposables.add(@applicationDelegate.onContextMenuCommand(@dispatchContextMenuCommand.bind(this)))
        @disposables.add @applicationDelegate.onSaveWindowStateRequest =>
          callback = => @applicationDelegate.didSaveWindowState()
          @saveState({isUnloading: true}).catch(callback).then(callback)

        @listenForUpdates()

        @registerDefaultTargetForKeymaps()

        @packages.loadPackages()

        startTime = Date.now()
        @deserialize(state) if state?
        @deserializeTimings.atom = Date.now() - startTime

        if process.platform is 'darwin' and @config.get('core.titleBar') is 'custom'
          @workspace.addHeaderPanel({item: new TitleBar({@workspace, @themes, @applicationDelegate})})
          @document.body.classList.add('custom-title-bar')
        if process.platform is 'darwin' and @config.get('core.titleBar') is 'custom-inset'
          @workspace.addHeaderPanel({item: new TitleBar({@workspace, @themes, @applicationDelegate})})
          @document.body.classList.add('custom-inset-title-bar')
        if process.platform is 'darwin' and @config.get('core.titleBar') is 'hidden'
          @document.body.classList.add('hidden-title-bar')

        @document.body.appendChild(@workspace.getElement())
        @backgroundStylesheet?.remove()

        @watchProjectPaths()

        @packages.activate()
        @keymaps.loadUserKeymap()
        @requireUserInitScript() unless @getLoadSettings().safeMode

        @menu.update()

        @openInitialEmptyEditorIfNecessary()

    loadHistoryPromise = @history.loadState().then =>
      @reopenProjectMenuManager = new ReopenProjectMenuManager({
        @menu, @commands, @history, @config,
        open: (paths) => @open(pathsToOpen: paths)
      })
      @reopenProjectMenuManager.update()

    Promise.all([loadStatePromise, loadHistoryPromise, updateProcessEnvPromise])

  serialize: (options) ->
    version: @constructor.version
    project: @project.serialize(options)
    workspace: @workspace.serialize()
    packageStates: @packages.serialize()
    grammars: {grammarOverridesByPath: @grammars.grammarOverridesByPath}
    fullScreen: @isFullScreen()
    windowDimensions: @windowDimensions
    textEditors: @textEditors.serialize()

  unloadEditorWindow: ->
    return if not @project

    @storeWindowBackground()
    @packages.deactivatePackages()
    @saveBlobStoreSync()
    @unloaded = true

  saveBlobStoreSync: ->
    if @enablePersistence
      @blobStore.save()

  openInitialEmptyEditorIfNecessary: ->
    return unless @config.get('core.openEmptyEditorOnStart')
    if @getLoadSettings().initialPaths?.length is 0 and @workspace.getPaneItems().length is 0
      @workspace.open(null)

  installUncaughtErrorHandler: ->
    @previousWindowErrorHandler = @window.onerror
    @window.onerror = =>
      @lastUncaughtError = Array::slice.call(arguments)
      [message, url, line, column, originalError] = @lastUncaughtError

      {line, column, source} = mapSourcePosition({source: url, line, column})

      if url is '<embedded>'
        url = source

      eventObject = {message, url, line, column, originalError}

      openDevTools = true
      eventObject.preventDefault = -> openDevTools = false

      @emitter.emit 'will-throw-error', eventObject

      if openDevTools
        @openDevTools().then => @executeJavaScriptInDevTools('DevToolsAPI.showPanel("console")')

      @emitter.emit 'did-throw-error', {message, url, line, column, originalError}

  uninstallUncaughtErrorHandler: ->
    @window.onerror = @previousWindowErrorHandler

  installWindowEventHandler: ->
    @windowEventHandler = new WindowEventHandler({atomEnvironment: this, @applicationDelegate})
    @windowEventHandler.initialize(@window, @document)

  uninstallWindowEventHandler: ->
    @windowEventHandler?.unsubscribe()
    @windowEventHandler = null

  ###
  Section: Messaging the User
  ###

  # Essential: Visually and audibly trigger a beep.
  beep: ->
    @applicationDelegate.playBeepSound() if @config.get('core.audioBeep')
    @emitter.emit 'did-beep'

  # Essential: A flexible way to open a dialog akin to an alert dialog.
  #
  # ## Examples
  #
  # ```coffee
  # atom.confirm
  #   message: 'How you feeling?'
  #   detailedMessage: 'Be honest.'
  #   buttons:
  #     Good: -> window.alert('good to hear')
  #     Bad: -> window.alert('bummer')
  # ```
  #
  # * `options` An {Object} with the following keys:
  #   * `message` The {String} message to display.
  #   * `detailedMessage` (optional) The {String} detailed message to display.
  #   * `buttons` (optional) Either an array of strings or an object where keys are
  #     button names and the values are callbacks to invoke when clicked.
  #
  # Returns the chosen button index {Number} if the buttons option was an array.
  confirm: (params={}) ->
    @applicationDelegate.confirm(params)

  ###
  Section: Managing the Dev Tools
  ###

  # Extended: Open the dev tools for the current window.
  #
  # Returns a {Promise} that resolves when the DevTools have been opened.
  openDevTools: ->
    @applicationDelegate.openWindowDevTools()

  # Extended: Toggle the visibility of the dev tools for the current window.
  #
  # Returns a {Promise} that resolves when the DevTools have been opened or
  # closed.
  toggleDevTools: ->
    @applicationDelegate.toggleWindowDevTools()

  # Extended: Execute code in dev tools.
  executeJavaScriptInDevTools: (code) ->
    @applicationDelegate.executeJavaScriptInWindowDevTools(code)

  ###
  Section: Private
  ###

  assert: (condition, message, callbackOrMetadata) ->
    return true if condition

    error = new Error("Assertion failed: #{message}")
    Error.captureStackTrace(error, @assert)

    if callbackOrMetadata?
      if typeof callbackOrMetadata is 'function'
        callbackOrMetadata?(error)
      else
        error.metadata = callbackOrMetadata

    @emitter.emit 'did-fail-assertion', error
    unless @isReleasedVersion()
      throw error

    false

  loadThemes: ->
    @themes.load()

  # Notify the browser project of the window's current project path
  watchProjectPaths: ->
    @disposables.add @project.onDidChangePaths =>
      @applicationDelegate.setRepresentedDirectoryPaths(@project.getPaths())

  setDocumentEdited: (edited) ->
    @applicationDelegate.setWindowDocumentEdited?(edited)

  setRepresentedFilename: (filename) ->
    @applicationDelegate.setWindowRepresentedFilename?(filename)

  addProjectFolder: ->
    @pickFolder (selectedPaths = []) =>
      @addToProject(selectedPaths)

  addToProject: (projectPaths) ->
    @loadState(@getStateKey(projectPaths)).then (state) =>
      if state and @project.getPaths().length is 0
        @attemptRestoreProjectStateForPaths(state, projectPaths)
      else
        @project.addPath(folder) for folder in projectPaths

  attemptRestoreProjectStateForPaths: (state, projectPaths, filesToOpen = []) ->
    paneItemIsEmptyUnnamedTextEditor = (item) ->
      return false unless item instanceof TextEditor
      return false if item.getPath() or item.isModified()
      true

    windowIsUnused = @workspace.getPaneItems().every(paneItemIsEmptyUnnamedTextEditor)
    if windowIsUnused
      @restoreStateIntoThisEnvironment(state)
      Promise.all (@workspace.open(file) for file in filesToOpen)
    else
      nouns = if projectPaths.length is 1 then 'folder' else 'folders'
      btn = @confirm
        message: 'Previous automatically-saved project state detected'
        detailedMessage: "There is previously saved state for the selected #{nouns}. " +
          "Would you like to add the #{nouns} to this window, permanently discarding the saved state, " +
          "or open the #{nouns} in a new window, restoring the saved state?"
        buttons: [
          'Open in new window and recover state'
          'Add to this window and discard state'
        ]
      if btn is 0
        @open
          pathsToOpen: projectPaths.concat(filesToOpen)
          newWindow: true
          devMode: @inDevMode()
          safeMode: @inSafeMode()
        Promise.resolve(null)
      else if btn is 1
        @project.addPath(selectedPath) for selectedPath in projectPaths
        Promise.all (@workspace.open(file) for file in filesToOpen)

  restoreStateIntoThisEnvironment: (state) ->
    state.fullScreen = @isFullScreen()
    pane.destroy() for pane in @workspace.getPanes()
    @deserialize(state)

  showSaveDialog: (callback) ->
    callback(@showSaveDialogSync())

  showSaveDialogSync: (options={}) ->
    @applicationDelegate.showSaveDialog(options)

  saveState: (options, storageKey) ->
    new Promise (resolve, reject) =>
      if @enablePersistence and @project
        state = @serialize(options)
        savePromise =
          if storageKey ?= @getStateKey(@project?.getPaths())
            @stateStore.save(storageKey, state)
          else
            @applicationDelegate.setTemporaryWindowState(state)
        savePromise.catch(reject).then(resolve)
      else
        resolve()

  loadState: (stateKey) ->
    if @enablePersistence
      if stateKey ?= @getStateKey(@getLoadSettings().initialPaths)
        @stateStore.load(stateKey).then (state) =>
          if state
            state
          else
            # TODO: remove this when every user has migrated to the IndexedDb state store.
            @getStorageFolder().load(stateKey)
      else
        @applicationDelegate.getTemporaryWindowState()
    else
      Promise.resolve(null)

  deserialize: (state) ->
    if grammarOverridesByPath = state.grammars?.grammarOverridesByPath
      @grammars.grammarOverridesByPath = grammarOverridesByPath

    @setFullScreen(state.fullScreen)

    @packages.packageStates = state.packageStates ? {}

    startTime = Date.now()
    @project.deserialize(state.project, @deserializers) if state.project?
    @deserializeTimings.project = Date.now() - startTime

    @textEditors.deserialize(state.textEditors) if state.textEditors

    startTime = Date.now()
    @workspace.deserialize(state.workspace, @deserializers) if state.workspace?
    @deserializeTimings.workspace = Date.now() - startTime

  getStateKey: (paths) ->
    if paths?.length > 0
      sha1 = crypto.createHash('sha1').update(paths.slice().sort().join("\n")).digest('hex')
      "editor-#{sha1}"
    else
      null

  getStorageFolder: ->
    @storageFolder ?= new StorageFolder(@getConfigDirPath())

  getConfigDirPath: ->
    @configDirPath ?= process.env.ATOM_HOME

  getUserInitScriptPath: ->
    initScriptPath = fs.resolve(@getConfigDirPath(), 'init', ['js', 'coffee'])
    initScriptPath ? path.join(@getConfigDirPath(), 'init.coffee')

  requireUserInitScript: ->
    if userInitScriptPath = @getUserInitScriptPath()
      try
        require(userInitScriptPath) if fs.isFileSync(userInitScriptPath)
      catch error
        @notifications.addError "Failed to load `#{userInitScriptPath}`",
          detail: error.message
          dismissable: true

  # TODO: We should deprecate the update events here, and use `atom.autoUpdater` instead
  onUpdateAvailable: (callback) ->
    @emitter.on 'update-available', callback

  updateAvailable: (details) ->
    @emitter.emit 'update-available', details

  listenForUpdates: ->
    # listen for updates available locally (that have been successfully downloaded)
    @disposables.add(@autoUpdater.onDidCompleteDownloadingUpdate(@updateAvailable.bind(this)))

  setBodyPlatformClass: ->
    @document.body.classList.add("platform-#{process.platform}")

  setAutoHideMenuBar: (autoHide) ->
    @applicationDelegate.setAutoHideWindowMenuBar(autoHide)
    @applicationDelegate.setWindowMenuBarVisibility(not autoHide)

  dispatchApplicationMenuCommand: (command, arg) ->
    activeElement = @document.activeElement
    # Use the workspace element if body has focus
    if activeElement is @document.body
      activeElement = @workspace.getElement()
    @commands.dispatch(activeElement, command, arg)

  dispatchContextMenuCommand: (command, args...) ->
    @commands.dispatch(@contextMenu.activeElement, command, args)

  openLocations: (locations) ->
    needsProjectPaths = @project?.getPaths().length is 0

    foldersToAddToProject = []
    fileLocationsToOpen = []

    pushFolderToOpen = (folder) ->
      if folder not in foldersToAddToProject
        foldersToAddToProject.push(folder)

    for {pathToOpen, initialLine, initialColumn, forceAddToWindow} in locations
      if pathToOpen? and (needsProjectPaths or forceAddToWindow)
        if fs.existsSync(pathToOpen)
          pushFolderToOpen @project.getDirectoryForProjectPath(pathToOpen).getPath()
        else if fs.existsSync(path.dirname(pathToOpen))
          pushFolderToOpen @project.getDirectoryForProjectPath(path.dirname(pathToOpen)).getPath()
        else
          pushFolderToOpen @project.getDirectoryForProjectPath(pathToOpen).getPath()

      unless fs.isDirectorySync(pathToOpen)
        fileLocationsToOpen.push({pathToOpen, initialLine, initialColumn})

    promise = Promise.resolve(null)
    if foldersToAddToProject.length > 0
      promise = @loadState(@getStateKey(foldersToAddToProject)).then (state) =>
        if state and needsProjectPaths # only load state if this is the first path added to the project
          files = (location.pathToOpen for location in fileLocationsToOpen)
          @attemptRestoreProjectStateForPaths(state, foldersToAddToProject, files)
        else
          promises = []
          @project.addPath(folder) for folder in foldersToAddToProject
          for {pathToOpen, initialLine, initialColumn} in fileLocationsToOpen
            promises.push @workspace?.open(pathToOpen, {initialLine, initialColumn})
          Promise.all(promises)
    else
      promises = []
      for {pathToOpen, initialLine, initialColumn} in fileLocationsToOpen
        promises.push @workspace?.open(pathToOpen, {initialLine, initialColumn})
      promise = Promise.all(promises)

    promise.then ->
      ipcRenderer.send 'window-command', 'window:locations-opened'

  resolveProxy: (url) ->
    return new Promise (resolve, reject) =>
      requestId = @nextProxyRequestId++
      disposable = @applicationDelegate.onDidResolveProxy (id, proxy) ->
        if id is requestId
          disposable.dispose()
          resolve(proxy)

      @applicationDelegate.resolveProxy(requestId, url)

# Preserve this deprecation until 2.0. Sorry. Should have removed Q sooner.
Promise.prototype.done = (callback) ->
  deprecate("Atom now uses ES6 Promises instead of Q. Call promise.then instead of promise.done")
  @then(callback)
