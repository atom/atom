crypto = require 'crypto'
path = require 'path'
ipc = require 'ipc'

_ = require 'underscore-plus'
{deprecate} = require 'grim'
{CompositeDisposable, Emitter} = require 'event-kit'
fs = require 'fs-plus'
{mapSourcePosition} = require 'source-map-support'
Model = require './model'
WindowEventHandler = require './window-event-handler'
StylesElement = require './styles-element'
StorageFolder = require './storage-folder'
{getWindowLoadSettings} = require './window-load-settings-helpers'
registerDefaultCommands = require './register-default-commands'

DeserializerManager = require './deserializer-manager'
ViewRegistry = require './view-registry'
NotificationManager = require './notification-manager'
Config = require './config'
KeymapManager = require './keymap-extensions'
TooltipManager = require './tooltip-manager'
CommandRegistry = require './command-registry'
GrammarRegistry = require './grammar-registry'
StyleManager = require './style-manager'
PackageManager = require './package-manager'
ThemeManager = require './theme-manager'
MenuManager = require './menu-manager'
ContextMenuManager = require './context-menu-manager'
CommandInstaller = require './command-installer'
Clipboard = require './clipboard'
Project = require './project'
Workspace = require './workspace'
PanelContainer = require './panel-container'
Panel = require './panel'
PaneContainer = require './pane-container'
PaneAxis = require './pane-axis'
Pane = require './pane'
Project = require './project'
TextEditor = require './text-editor'
TextBuffer = require 'text-buffer'
Gutter = require './gutter'

WorkspaceElement = require './workspace-element'
PanelContainerElement = require './panel-container-element'
PanelElement = require './panel-element'
PaneContainerElement = require './pane-container-element'
PaneAxisElement = require './pane-axis-element'
PaneElement = require './pane-element'
TextEditorElement = require './text-editor-element'
{createGutterView} = require './gutter-component-helpers'

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

  ###
  Section: Construction and Destruction
  ###

  # Call .loadOrCreate instead
  constructor: (params={}) ->
    {@blobStore, @applicationDelegate, @window, @document, configDirPath, @enablePersistence, onlyLoadBaseStyleSheets} = params

    @state = {version: @constructor.version}

    @loadTime = null
    {devMode, safeMode, resourcePath} = @getLoadSettings()

    @emitter = new Emitter
    @disposables = new CompositeDisposable

    @deserializers = new DeserializerManager(this)
    @deserializeTimings = {}

    @views = new ViewRegistry(this)

    @notifications = new NotificationManager

    @config = new Config({configDirPath, resourcePath, notificationManager: @notifications, @enablePersistence})
    @setConfigSchema()

    @keymaps = new KeymapManager({configDirPath, resourcePath, notificationManager: @notifications})

    @tooltips = new TooltipManager(keymapManager: @keymaps)

    @commands = new CommandRegistry
    @commands.attach(@window)

    @grammars = new GrammarRegistry({@config})

    @styles = new StyleManager({configDirPath})

    @packages = new PackageManager({
      devMode, configDirPath, resourcePath, safeMode, @config, styleManager: @styles,
      commandRegistry: @commands, keymapManager: @keymaps, notificationManager: @notifications,
      grammarRegistry: @grammars, deserializerManager: @deserializers, viewRegistry: @views
    })

    @themes = new ThemeManager({
      packageManager: @packages, configDirPath, resourcePath, safeMode, @config,
      styleManager: @styles, notificationManager: @notifications, viewRegistry: @views
    })

    @menu = new MenuManager({resourcePath, keymapManager: @keymaps, packageManager: @packages})

    @contextMenu = new ContextMenuManager({resourcePath, devMode, keymapManager: @keymaps})

    @packages.setMenuManager(@menu)
    @packages.setContextMenuManager(@contextMenu)
    @packages.setThemeManager(@themes)

    @clipboard = new Clipboard()

    @project = new Project({notificationManager: @notifications, packageManager: @packages, @config})

    @commandInstaller = new CommandInstaller(@getVersion(), @applicationDelegate)

    @workspace = new Workspace({
      @config, @project, packageManager: @packages, grammarRegistry: @grammars, deserializerManager: @deserializers,
      notificationManager: @notifications, @applicationDelegate, @clipboard, viewRegistry: @views, assert: @assert.bind(this)
    })
    @themes.workspace = @workspace

    @config.load()

    @themes.loadBaseStylesheets()
    @initialStyleElements = @styles.getSnapshot()
    @themes.initialLoadComplete = true if onlyLoadBaseStyleSheets
    @setBodyPlatformClass()

    @stylesElement = @styles.buildStylesElement()
    @document.head.appendChild(@stylesElement)

    @applicationDelegate.disablePinchToZoom()

    @keymaps.subscribeToFileReadFailure()
    @keymaps.loadBundledKeymaps()

    @registerDefaultCommands()
    @registerDefaultOpeners()
    @registerDefaultDeserializers()
    @registerDefaultViewProviders()

    @installUncaughtErrorHandler()
    @installWindowEventHandler()

    @observeAutoHideMenuBar()

    checkPortableHomeWritable = ->
      responseChannel = "check-portable-home-writable-response"
      ipc.on responseChannel, (response) ->
        ipc.removeAllListeners(responseChannel)
        atom.notifications.addWarning("#{response.message.replace(/([\\\.+\\-_#!])/g, '\\$1')}") if not response.writable
      ipc.send('check-portable-home-writable', responseChannel)

    checkPortableHomeWritable()

  setConfigSchema: ->
    @config.setSchema null, {type: 'object', properties: _.clone(require('./config-schema'))}

  registerDefaultDeserializers: ->
    @deserializers.add(Workspace)
    @deserializers.add(PaneContainer)
    @deserializers.add(PaneAxis)
    @deserializers.add(Pane)
    @deserializers.add(Project)
    @deserializers.add(TextEditor)
    @deserializers.add(TextBuffer)

  registerDefaultCommands: ->
    registerDefaultCommands({commandRegistry: @commands, @config, @commandInstaller})

  registerDefaultViewProviders: ->
    @views.addViewProvider Workspace, (model, env) ->
      new WorkspaceElement().initialize(model, env)
    @views.addViewProvider PanelContainer, (model, env) ->
      new PanelContainerElement().initialize(model, env)
    @views.addViewProvider Panel, (model, env) ->
      new PanelElement().initialize(model, env)
    @views.addViewProvider PaneContainer, (model, env) ->
      new PaneContainerElement().initialize(model, env)
    @views.addViewProvider PaneAxis, (model, env) ->
      new PaneAxisElement().initialize(model, env)
    @views.addViewProvider Pane, (model, env) ->
      new PaneElement().initialize(model, env)
    @views.addViewProvider TextEditor, (model, env) ->
      new TextEditorElement().initialize(model, env)
    @views.addViewProvider(Gutter, createGutterView)

  registerDefaultOpeners: ->
    @workspace.addOpener (uri) =>
      switch uri
        when 'atom://.atom/stylesheet'
          @workspace.open(@styles.getUserStyleSheetPath())
        when 'atom://.atom/keymap'
          @workspace.open(@keymaps.getUserKeymapPath())
        when 'atom://.atom/config'
          @workspace.open(@config.getUserConfigPath())
        when 'atom://.atom/init-script'
          @workspace.open(@getUserInitScriptPath())

  registerDefaultTargetForKeymaps: ->
    @keymaps.defaultTarget = @views.getView(@workspace)

  observeAutoHideMenuBar: ->
    @disposables.add @config.onDidChange 'core.autoHideMenuBar', ({newValue}) =>
      @setAutoHideMenuBar(newValue)
    @setAutoHideMenuBar(true) if @config.get('core.autoHideMenuBar')

  reset: ->
    @deserializers.clear()
    @registerDefaultDeserializers()

    @config.clear()
    @setConfigSchema()

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

    @views.clear()
    @registerDefaultViewProviders()

    @state.packageStates = {}
    delete @state.workspace

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

  # Public: Get the version of the Atom application.
  #
  # Returns the version text {String}.
  getVersion: ->
    @appVersion ?= @getLoadSettings().appVersion

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
    getWindowLoadSettings()

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
    @applicationDelegate.restartWindow()

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
    if fullScreen
      @document.body.classList.add("fullscreen")
    else
      @document.body.classList.remove("fullscreen")

  # Extended: Toggle the full screen state of the current window.
  toggleFullScreen: ->
    @setFullScreen(not @isFullScreen())

  # Restore the window to its previous dimensions and show it.
  #
  # Also restores the full screen and maximized state on the next tick to
  # prevent resize glitches.
  displayWindow: ->
    dimensions = @restoreWindowDimensions()
    @show()
    @focus()

    setImmediate =>
      @setFullScreen(true) if @workspace?.fullScreen
      @maximize() if dimensions?.maximized and process.platform isnt 'darwin'

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
    if width? and height?
      @setSize(width, height)
    if x? and y?
      @setPosition(x, y)
    else
      @center()

  # Returns true if the dimensions are useable, false if they should be ignored.
  # Work around for https://github.com/atom/atom-shell/issues/473
  isValidDimensions: ({x, y, width, height}={}) ->
    width > 0 and height > 0 and x + width > 0 and y + height > 0

  storeDefaultWindowDimensions: ->
    dimensions = @getWindowDimensions()
    if @isValidDimensions(dimensions)
      localStorage.setItem("defaultWindowDimensions", JSON.stringify(dimensions))

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
    dimensions = @state.windowDimensions
    unless @isValidDimensions(dimensions)
      dimensions = @getDefaultWindowDimensions()
    @setWindowDimensions(dimensions)
    dimensions

  storeWindowDimensions: ->
    dimensions = @getWindowDimensions()
    @state.windowDimensions = dimensions if @isValidDimensions(dimensions)

  storeWindowBackground: ->
    return if @inSpecMode()

    workspaceElement = @views.getView(@workspace)
    backgroundColor = @window.getComputedStyle(workspaceElement)['background-color']
    @window.localStorage.setItem('atom:window-background-color', backgroundColor)

  # Call this method when establishing a real application window.
  startEditorWindow: ->
    @commandInstaller.installAtomCommand false, (error) ->
      console.warn error.message if error?
    @commandInstaller.installApmCommand false, (error) ->
      console.warn error.message if error?

    @disposables.add(@applicationDelegate.onDidOpenLocations(@openLocations.bind(this)))
    @disposables.add(@applicationDelegate.onApplicationMenuCommand(@dispatchApplicationMenuCommand.bind(this)))
    @disposables.add(@applicationDelegate.onContextMenuCommand(@dispatchContextMenuCommand.bind(this)))
    @listenForUpdates()

    @registerDefaultTargetForKeymaps()

    @packages.loadPackages()
    @loadStateSync()
    @document.body.appendChild(@views.getView(@workspace))

    @watchProjectPath()

    @packages.activate()
    @keymaps.loadUserKeymap()
    @requireUserInitScript() unless @getLoadSettings().safeMode

    @menu.update()

    @openInitialEmptyEditorIfNecessary()

  unloadEditorWindow: ->
    return if not @project

    @storeWindowBackground()
    @state.grammars = {grammarOverridesByPath: @grammars.grammarOverridesByPath}
    @state.project = @project.serialize()
    @state.workspace = @workspace.serialize()
    @packages.deactivatePackages()
    @state.packageStates = @packages.packageStates
    @state.fullScreen = @isFullScreen()
    @saveStateSync()
    @saveBlobStoreSync()

  openInitialEmptyEditorIfNecessary: ->
    return unless @config.get('core.openEmptyEditorOnStart')
    if @getLoadSettings().initialPaths?.length is 0 and @workspace.getPaneItems().length is 0
      @workspace.open(null)

  installUncaughtErrorHandler: ->
    @previousWindowErrorHandler = @window.onerror
    @window.onerror = =>
      @lastUncaughtError = Array::slice.call(arguments)
      [message, url, line, column, originalError] = @lastUncaughtError

      {line, column} = mapSourcePosition({source: url, line, column})

      eventObject = {message, url, line, column, originalError}

      openDevTools = true
      eventObject.preventDefault = -> openDevTools = false

      @emitter.emit 'will-throw-error', eventObject

      if openDevTools
        @openDevTools().then => @executeJavaScriptInDevTools('DevToolsAPI.showConsole()')

      @emitter.emit 'did-throw-error', {message, url, line, column, originalError}

  uninstallUncaughtErrorHandler: ->
    @window.onerror = @previousWindowErrorHandler

  installWindowEventHandler: ->
    @windowEventHandler = new WindowEventHandler({atomEnvironment: this, @applicationDelegate, @window, @document})

  uninstallWindowEventHandler: ->
    @windowEventHandler?.unsubscribe()

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

  assert: (condition, message, callback) ->
    return true if condition

    error = new Error("Assertion failed: #{message}")
    Error.captureStackTrace(error, @assert)
    callback?(error)

    @emitter.emit 'did-fail-assertion', error

    false

  loadThemes: ->
    @themes.load()

  # Notify the browser project of the window's current project path
  watchProjectPath: ->
    @disposables.add @project.onDidChangePaths =>
      @applicationDelegate.setRepresentedDirectoryPaths(@project.getPaths())

  setDocumentEdited: (edited) ->
    @applicationDelegate.setWindowDocumentEdited?(edited)

  setRepresentedFilename: (filename) ->
    @applicationDelegate.setWindowRepresentedFilename?(filename)

  addProjectFolder: ->
    @pickFolder (selectedPaths = []) =>
      @project.addPath(selectedPath) for selectedPath in selectedPaths

  showSaveDialog: (callback) ->
    callback(showSaveDialogSync())

  showSaveDialogSync: (options={}) ->
    @applicationDelegate.showSaveDialog(options)

  saveBlobStoreSync: ->
    return unless @enablePersistence

    @blobStore.save()

  saveStateSync: ->
    return unless @enablePersistence

    if storageKey = @getStateKey(@project?.getPaths())
      @getStorageFolder().store(storageKey, @state)
    else
      @getCurrentWindow().loadSettings.windowState = JSON.stringify(@state)

  loadStateSync: ->
    return unless @enablePersistence

    startTime = Date.now()

    if stateKey = @getStateKey(@getLoadSettings().initialPaths)
      if state = @getStorageFolder().load(stateKey)
        @state = state

    if not @state? and windowState = @getLoadSettings().windowState
      try
        if state = JSON.parse(@getLoadSettings().windowState)
          @state = state
      catch error
        console.warn "Error parsing window state: #{statePath} #{error.stack}", error

    @deserializeTimings.atom = Date.now() -  startTime

    if grammarOverridesByPath = @state.grammars?.grammarOverridesByPath
      @grammars.grammarOverridesByPath = grammarOverridesByPath

    @setFullScreen(@state.fullScreen)

    @packages.packageStates = @state.packageStates ? {}

    startTime = Date.now()
    @project.deserialize(@state.project, @deserializers) if @state.project?
    @deserializeTimings.project = Date.now() - startTime

    startTime = Date.now()
    @workspace.deserialize(@state.workspace, @deserializers) if @state.workspace?
    @deserializeTimings.workspace = Date.now() - startTime

  getStateKey: (paths) ->
    if paths?.length > 0
      sha1 = crypto.createHash('sha1').update(paths.slice().sort().join("\n")).digest('hex')
      "editor-#{sha1}"
    else
      null

  getConfigDirPath: ->
    @configDirPath ?= process.env.ATOM_HOME

  getStorageFolder: ->
    @storageFolder ?= new StorageFolder(@getConfigDirPath())

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

  onUpdateAvailable: (callback) ->
    @emitter.on 'update-available', callback

  updateAvailable: (details) ->
    @emitter.emit 'update-available', details

  listenForUpdates: ->
    @disposables.add(@applicationDelegate.onUpdateAvailable(@updateAvailable.bind(this)))

  setBodyPlatformClass: ->
    @document.body.classList.add("platform-#{process.platform}")

  setAutoHideMenuBar: (autoHide) ->
    @applicationDelegate.setAutoHideWindowMenuBar(autoHide)
    @applicationDelegate.setWindowMenuBarVisibility(not autoHide)

  dispatchApplicationMenuCommand: (command, arg) ->
    activeElement = @document.activeElement
    # Use the workspace element if body has focus
    if activeElement is @document.body and workspaceElement = @views.getView(@workspace)
      activeElement = workspaceElement
    @commands.dispatch(activeElement, command, arg)

  dispatchContextMenuCommand: (command, args...) ->
    @commands.dispatch(@contextMenu.activeElement, command, args)

  openLocations: (locations) ->
    needsProjectPaths = @project?.getPaths().length is 0

    for {pathToOpen, initialLine, initialColumn} in locations
      if pathToOpen? and needsProjectPaths
        if fs.existsSync(pathToOpen)
          @project.addPath(pathToOpen)
        else if fs.existsSync(path.dirname(pathToOpen))
          @project.addPath(path.dirname(pathToOpen))
        else
          @project.addPath(pathToOpen)

      @applicationDelegate.addRecentDocument(pathToOpen)

      unless fs.isDirectorySync(pathToOpen)
        @workspace?.open(pathToOpen, {initialLine, initialColumn})

    return

# Preserve this deprecation until 2.0. Sorry. Should have removed Q sooner.
Promise.prototype.done = (callback) ->
  deprecate("Atom now uses ES6 Promises instead of Q. Call promise.then instead of promise.done")
  @then(callback)
