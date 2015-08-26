crypto = require 'crypto'
ipc = require 'ipc'
os = require 'os'
path = require 'path'
remote = require 'remote'
shell = require 'shell'

_ = require 'underscore-plus'
{deprecate, includeDeprecatedAPIs} = require 'grim'
{CompositeDisposable, Emitter} = require 'event-kit'
fs = require 'fs-plus'
{mapSourcePosition} = require 'source-map-support'
Model = require './model'
{$} = require './space-pen-extensions'
WindowEventHandler = require './window-event-handler'
StylesElement = require './styles-element'
StorageFolder = require './storage-folder'

# Essential: Atom global for dealing with packages, themes, menus, and the window.
#
# An instance of this class is always available as the `atom` global.
module.exports =
class Atom extends Model
  @version: 1  # Increment this when the serialization format changes

  # Load or create the Atom environment in the given mode.
  #
  # * `mode` A {String} mode that is either 'editor' or 'spec' depending on the
  #   kind of environment you want to build.
  #
  # Returns an Atom instance, fully initialized
  @loadOrCreate: (mode) ->
    startTime = Date.now()
    atom = @deserialize(@loadState(mode)) ? new this({mode, @version})
    atom.deserializeTimings.atom = Date.now() -  startTime

    if includeDeprecatedAPIs
      workspaceViewDeprecationMessage = """
        atom.workspaceView is no longer available.
        In most cases you will not need the view. See the Workspace docs for
        alternatives: https://atom.io/docs/api/latest/Workspace.
        If you do need the view, please use `atom.views.getView(atom.workspace)`,
        which returns an HTMLElement.
      """

      serviceHubDeprecationMessage = """
        atom.services is no longer available. To register service providers and
        consumers, use the `providedServices` and `consumedServices` fields in
        your package's package.json.
      """

      Object.defineProperty atom, 'workspaceView',
        get: ->
          deprecate(workspaceViewDeprecationMessage)
          atom.__workspaceView
        set: (newValue) ->
          deprecate(workspaceViewDeprecationMessage)
          atom.__workspaceView = newValue

      Object.defineProperty atom, 'services',
        get: ->
          deprecate(serviceHubDeprecationMessage)
          atom.packages.serviceHub
        set: (newValue) ->
          deprecate(serviceHubDeprecationMessage)
          atom.packages.serviceHub = newValue

    atom

  # Deserializes the Atom environment from a state object
  @deserialize: (state) ->
    new this(state) if state?.version is @version

  # Loads and returns the serialized state corresponding to this window
  # if it exists; otherwise returns undefined.
  @loadState: (mode) ->
    if stateKey = @getStateKey(@getLoadSettings().initialPaths, mode)
      if state = @getStorageFolder().load(stateKey)
        return state

    if windowState = @getLoadSettings().windowState
      try
        JSON.parse(@getLoadSettings().windowState)
      catch error
        console.warn "Error parsing window state: #{statePath} #{error.stack}", error

  # Returns the path where the state for the current window will be
  # located if it exists.
  @getStateKey: (paths, mode) ->
    if mode is 'spec'
      'spec'
    else if mode is 'editor' and paths?.length > 0
      sha1 = crypto.createHash('sha1').update(paths.slice().sort().join("\n")).digest('hex')
      "editor-#{sha1}"
    else
      null

  # Get the directory path to Atom's configuration area.
  #
  # Returns the absolute path to ~/.atom
  @getConfigDirPath: ->
    @configDirPath ?= process.env.ATOM_HOME

  @getStorageFolder: ->
    @storageFolder ?= new StorageFolder(@getConfigDirPath())

  # Returns the load settings hash associated with the current window.
  @getLoadSettings: ->
    @loadSettings ?= JSON.parse(decodeURIComponent(location.hash.substr(1)))
    cloned = _.deepClone(@loadSettings)
    # The loadSettings.windowState could be large, request it only when needed.
    cloned.__defineGetter__ 'windowState', =>
      @getCurrentWindow().loadSettings.windowState
    cloned.__defineSetter__ 'windowState', (value) =>
      @getCurrentWindow().loadSettings.windowState = value
    cloned

  @updateLoadSetting: (key, value) ->
    @getLoadSettings()
    @loadSettings[key] = value
    location.hash = encodeURIComponent(JSON.stringify(@loadSettings))

  @getCurrentWindow: ->
    remote.getCurrentWindow()

  workspaceViewParentSelector: 'body'
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
  constructor: (@state) ->
    @emitter = new Emitter
    @disposables = new CompositeDisposable
    {@mode} = @state
    DeserializerManager = require './deserializer-manager'
    @deserializers = new DeserializerManager()
    @deserializeTimings = {}

  # Sets up the basic services that should be available in all modes
  # (both spec and application).
  #
  # Call after this instance has been assigned to the `atom` global.
  initialize: ->
    window.onerror = =>
      @lastUncaughtError = Array::slice.call(arguments)
      [message, url, line, column, originalError] = @lastUncaughtError

      {line, column} = mapSourcePosition({source: url, line, column})

      eventObject = {message, url, line, column, originalError}

      openDevTools = true
      eventObject.preventDefault = -> openDevTools = false

      @emitter.emit 'will-throw-error', eventObject

      if openDevTools
        @openDevTools()
        @executeJavaScriptInDevTools('DevToolsAPI.showConsole()')

      @emit 'uncaught-error', arguments... if includeDeprecatedAPIs
      @emitter.emit 'did-throw-error', {message, url, line, column, originalError}

    @disposables?.dispose()
    @disposables = new CompositeDisposable

    @displayWindow() unless @inSpecMode()

    @setBodyPlatformClass()

    @loadTime = null

    Config = require './config'
    KeymapManager = require './keymap-extensions'
    ViewRegistry = require './view-registry'
    CommandRegistry = require './command-registry'
    TooltipManager = require './tooltip-manager'
    NotificationManager = require './notification-manager'
    PackageManager = require './package-manager'
    Clipboard = require './clipboard'
    GrammarRegistry = require './grammar-registry'
    ThemeManager = require './theme-manager'
    StyleManager = require './style-manager'
    ContextMenuManager = require './context-menu-manager'
    MenuManager = require './menu-manager'
    {devMode, safeMode, resourcePath} = @getLoadSettings()
    configDirPath = @getConfigDirPath()

    # Add 'exports' to module search path.
    exportsPath = path.join(resourcePath, 'exports')
    require('module').globalPaths.push(exportsPath)
    # Still set NODE_PATH since tasks may need it.
    process.env.NODE_PATH = exportsPath

    # Make react.js faster
    process.env.NODE_ENV ?= 'production' unless devMode

    @config = new Config({configDirPath, resourcePath})
    @keymaps = new KeymapManager({configDirPath, resourcePath})

    if includeDeprecatedAPIs
      @keymap = @keymaps # Deprecated

    @keymaps.subscribeToFileReadFailure()
    @tooltips = new TooltipManager
    @notifications = new NotificationManager
    @commands = new CommandRegistry
    @views = new ViewRegistry
    @registerViewProviders()
    @packages = new PackageManager({devMode, configDirPath, resourcePath, safeMode})
    @styles = new StyleManager
    document.head.appendChild(new StylesElement)
    @themes = new ThemeManager({packageManager: @packages, configDirPath, resourcePath, safeMode})
    @contextMenu = new ContextMenuManager({resourcePath, devMode})
    @menu = new MenuManager({resourcePath})
    @clipboard = new Clipboard()

    @grammars = @deserializers.deserialize(@state.grammars ? @state.syntax) ? new GrammarRegistry()

    if includeDeprecatedAPIs
      Object.defineProperty this, 'syntax', get: ->
        deprecate "The atom.syntax global is deprecated. Use atom.grammars instead."
        @grammars

    @disposables.add @packages.onDidActivateInitialPackages => @watchThemes()

    Project = require './project'
    TextBuffer = require 'text-buffer'
    @deserializers.add(TextBuffer)
    TokenizedBuffer = require './tokenized-buffer'
    DisplayBuffer = require './display-buffer'
    TextEditor = require './text-editor'

    @windowEventHandler = new WindowEventHandler

  # Register the core views as early as possible in case they are needed for
  # package deserialization.
  registerViewProviders: ->
    Gutter = require './gutter'
    Pane = require './pane'
    PaneElement = require './pane-element'
    PaneContainer = require './pane-container'
    PaneContainerElement = require './pane-container-element'
    PaneAxis = require './pane-axis'
    PaneAxisElement = require './pane-axis-element'
    TextEditor = require './text-editor'
    TextEditorElement = require './text-editor-element'
    {createGutterView} = require './gutter-component-helpers'

    atom.views.addViewProvider PaneContainer, (model) ->
      new PaneContainerElement().initialize(model)
    atom.views.addViewProvider PaneAxis, (model) ->
      new PaneAxisElement().initialize(model)
    atom.views.addViewProvider Pane, (model) ->
      new PaneElement().initialize(model)
    atom.views.addViewProvider TextEditor, (model) ->
      new TextEditorElement().initialize(model)
    atom.views.addViewProvider(Gutter, createGutterView)

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

  # Public: Get the directory path to Atom's configuration area.
  #
  # Returns the absolute path to `~/.atom`.
  getConfigDirPath: ->
    @constructor.getConfigDirPath()

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
    @constructor.getLoadSettings()

  ###
  Section: Managing The Atom Window
  ###

  # Essential: Open a new Atom window using the given options.
  #
  # Calling this method without an options parameter will open a prompt to pick
  # a file/folder to open in the new window.
  #
  # * `options` An {Object} with the following keys:
  #   * `pathsToOpen`  An {Array} of {String} paths to open.
  #   * `newWindow` A {Boolean}, true to always open a new window instead of
  #     reusing existing windows depending on the paths to open.
  #   * `devMode` A {Boolean}, true to open the window in development mode.
  #     Development mode loads the Atom source from the locally cloned
  #     repository and also loads all the packages in ~/.atom/dev/packages
  #   * `safeMode` A {Boolean}, true to open the window in safe mode. Safe
  #     mode prevents all packages installed to ~/.atom/packages from loading.
  open: (options) ->
    ipc.send('open', options)

  # Extended: Prompt the user to select one or more folders.
  #
  # * `callback` A {Function} to call once the user has confirmed the selection.
  #   * `paths` An {Array} of {String} paths that the user selected, or `null`
  #     if the user dismissed the dialog.
  pickFolder: (callback) ->
    responseChannel = "atom-pick-folder-response"
    ipc.on responseChannel, (path) ->
      ipc.removeAllListeners(responseChannel)
      callback(path)
    ipc.send("pick-folder", responseChannel)

  # Essential: Close the current window.
  close: ->
    @getCurrentWindow().close()

  # Essential: Get the size of current window.
  #
  # Returns an {Object} in the format `{width: 1000, height: 700}`
  getSize: ->
    [width, height] = @getCurrentWindow().getSize()
    {width, height}

  # Essential: Set the size of current window.
  #
  # * `width` The {Number} of pixels.
  # * `height` The {Number} of pixels.
  setSize: (width, height) ->
    @getCurrentWindow().setSize(width, height)

  # Essential: Get the position of current window.
  #
  # Returns an {Object} in the format `{x: 10, y: 20}`
  getPosition: ->
    [x, y] = @getCurrentWindow().getPosition()
    {x, y}

  # Essential: Set the position of current window.
  #
  # * `x` The {Number} of pixels.
  # * `y` The {Number} of pixels.
  setPosition: (x, y) ->
    ipc.send('call-window-method', 'setPosition', x, y)

  # Extended: Get the current window
  getCurrentWindow: ->
    @constructor.getCurrentWindow()

  # Extended: Move current window to the center of the screen.
  center: ->
    ipc.send('call-window-method', 'center')

  # Extended: Focus the current window.
  focus: ->
    ipc.send('call-window-method', 'focus')
    $(window).focus()

  # Extended: Show the current window.
  show: ->
    ipc.send('call-window-method', 'show')

  # Extended: Hide the current window.
  hide: ->
    ipc.send('call-window-method', 'hide')

  # Extended: Reload the current window.
  reload: ->
    ipc.send('call-window-method', 'restart')

  # Extended: Returns a {Boolean} that is `true` if the current window is maximized.
  isMaximized: ->
    @getCurrentWindow().isMaximized()

  isMaximixed: ->
    deprecate "Use atom.isMaximized() instead"
    @isMaximized()

  maximize: ->
    ipc.send('call-window-method', 'maximize')

  # Extended: Returns a {Boolean} that is `true` if the current window is in full screen mode.
  isFullScreen: ->
    @getCurrentWindow().isFullScreen()

  # Extended: Set the full screen state of the current window.
  setFullScreen: (fullScreen=false) ->
    ipc.send('call-window-method', 'setFullScreen', fullScreen)
    if fullScreen
      document.body.classList.add("fullscreen")
    else
      document.body.classList.remove("fullscreen")

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
      screen = remote.require 'screen'
      {width, height} = screen.getPrimaryDisplay().workAreaSize
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
    backgroundColor = window.getComputedStyle(workspaceElement)['background-color']
    window.localStorage.setItem('atom:window-background-color', backgroundColor)

  # Call this method when establishing a real application window.
  startEditorWindow: ->
    {safeMode} = @getLoadSettings()

    CommandInstaller = require './command-installer'
    CommandInstaller.installAtomCommand false, (error) ->
      console.warn error.message if error?
    CommandInstaller.installApmCommand false, (error) ->
      console.warn error.message if error?

    @loadConfig()
    @keymaps.loadBundledKeymaps()
    @themes.loadBaseStylesheets()
    @packages.loadPackages()
    @deserializeEditorWindow()

    @watchProjectPath()

    @packages.activate()
    @keymaps.loadUserKeymap()
    @requireUserInitScript() unless safeMode

    @menu.update()
    @disposables.add @config.onDidChange 'core.autoHideMenuBar', ({newValue}) =>
      @setAutoHideMenuBar(newValue)
    @setAutoHideMenuBar(true) if @config.get('core.autoHideMenuBar')

    @openInitialEmptyEditorIfNecessary()

  unloadEditorWindow: ->
    return if not @project

    @storeWindowBackground()
    @state.grammars = @grammars.serialize()
    @state.project = @project.serialize()
    @state.workspace = @workspace.serialize()
    @packages.deactivatePackages()
    @state.packageStates = @packages.packageStates
    @saveSync()
    @windowState = null

  removeEditorWindow: ->
    return if not @project

    @workspace?.destroy()
    @workspace = null
    @project?.destroy()
    @project = null

    @windowEventHandler?.unsubscribe()

  openInitialEmptyEditorIfNecessary: ->
    return unless @config.get('core.openEmptyEditorOnStart')
    if @getLoadSettings().initialPaths?.length is 0 and @workspace.getPaneItems().length is 0
      @workspace.open(null)

  ###
  Section: Messaging the User
  ###

  # Essential: Visually and audibly trigger a beep.
  beep: ->
    shell.beep() if @config.get('core.audioBeep')
    @__workspaceView?.trigger 'beep'
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
  confirm: ({message, detailedMessage, buttons}={}) ->
    buttons ?= {}
    if _.isArray(buttons)
      buttonLabels = buttons
    else
      buttonLabels = Object.keys(buttons)

    dialog = remote.require('dialog')
    chosen = dialog.showMessageBox @getCurrentWindow(),
      type: 'info'
      message: message
      detail: detailedMessage
      buttons: buttonLabels

    if _.isArray(buttons)
      chosen
    else
      callback = buttons[buttonLabels[chosen]]
      callback?()

  ###
  Section: Managing the Dev Tools
  ###

  # Extended: Open the dev tools for the current window.
  openDevTools: ->
    ipc.send('call-window-method', 'openDevTools')

  # Extended: Toggle the visibility of the dev tools for the current window.
  toggleDevTools: ->
    ipc.send('call-window-method', 'toggleDevTools')

  # Extended: Execute code in dev tools.
  executeJavaScriptInDevTools: (code) ->
    ipc.send('call-window-method', 'executeJavaScriptInDevTools', code)

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

  deserializeProject: ->
    Project = require './project'

    startTime = Date.now()
    @project ?= @deserializers.deserialize(@state.project) ? new Project()
    @deserializeTimings.project = Date.now() - startTime

  deserializeWorkspaceView: ->
    Workspace = require './workspace'

    if includeDeprecatedAPIs
      WorkspaceView = require './workspace-view'

    startTime = Date.now()
    @workspace = Workspace.deserialize(@state.workspace) ? new Workspace

    workspaceElement = @views.getView(@workspace)

    if includeDeprecatedAPIs
      @__workspaceView = workspaceElement.__spacePenView

    @deserializeTimings.workspace = Date.now() - startTime

    @keymaps.defaultTarget = workspaceElement
    document.querySelector(@workspaceViewParentSelector).appendChild(workspaceElement)

  deserializePackageStates: ->
    @packages.packageStates = @state.packageStates ? {}
    delete @state.packageStates

  deserializeEditorWindow: ->
    @deserializePackageStates()
    @deserializeProject()
    @deserializeWorkspaceView()

  loadConfig: ->
    @config.setSchema null, {type: 'object', properties: _.clone(require('./config-schema'))}
    @config.load()

  loadThemes: ->
    @themes.load()

  watchThemes: ->
    @themes.onDidChangeActiveThemes =>
      # Only reload stylesheets from non-theme packages
      for pack in @packages.getActivePackages() when pack.getType() isnt 'theme'
        pack.reloadStylesheets?()
      return

  # Notify the browser project of the window's current project path
  watchProjectPath: ->
    @disposables.add @project.onDidChangePaths =>
      @constructor.updateLoadSetting('initialPaths', @project.getPaths())

  exit: (status) ->
    app = remote.require('app')
    app.emit('will-exit')
    remote.process.exit(status)

  setDocumentEdited: (edited) ->
    ipc.send('call-window-method', 'setDocumentEdited', edited)

  setRepresentedFilename: (filename) ->
    ipc.send('call-window-method', 'setRepresentedFilename', filename)

  addProjectFolder: ->
    @pickFolder (selectedPaths = []) =>
      @project.addPath(selectedPath) for selectedPath in selectedPaths

  showSaveDialog: (callback) ->
    callback(showSaveDialogSync())

  showSaveDialogSync: (options={}) ->
    if _.isString(options)
      options = defaultPath: options
    else
      options = _.clone(options)
    currentWindow = @getCurrentWindow()
    dialog = remote.require('dialog')
    options.title ?= 'Save File'
    options.defaultPath ?= @project?.getPaths()[0]
    dialog.showSaveDialog currentWindow, options

  saveSync: ->
    if storageKey = @constructor.getStateKey(@project?.getPaths(), @mode)
      @constructor.getStorageFolder().store(storageKey, @state)
    else
      @getCurrentWindow().loadSettings.windowState = JSON.stringify(@state)

  crashMainProcess: ->
    remote.process.crash()

  crashRenderProcess: ->
    process.crash()

  getUserInitScriptPath: ->
    initScriptPath = fs.resolve(@getConfigDirPath(), 'init', ['js', 'coffee'])
    initScriptPath ? path.join(@getConfigDirPath(), 'init.coffee')

  requireUserInitScript: ->
    if userInitScriptPath = @getUserInitScriptPath()
      try
        require(userInitScriptPath) if fs.isFileSync(userInitScriptPath)
      catch error
        atom.notifications.addError "Failed to load `#{userInitScriptPath}`",
          detail: error.message
          dismissable: true

  # Require the module with the given globals.
  #
  # The globals will be set on the `window` object and removed after the
  # require completes.
  #
  # * `id` The {String} module name or path.
  # * `globals` An optional {Object} to set as globals during require.
  requireWithGlobals: (id, globals={}) ->
    existingGlobals = {}
    for key, value of globals
      existingGlobals[key] = window[key]
      window[key] = value

    require(id)

    for key, value of existingGlobals
      if value is undefined
        delete window[key]
      else
        window[key] = value
    return

  onUpdateAvailable: (callback) ->
    @emitter.on 'update-available', callback

  updateAvailable: (details) ->
    @emitter.emit 'update-available', details

  setBodyPlatformClass: ->
    document.body.classList.add("platform-#{process.platform}")

  setAutoHideMenuBar: (autoHide) ->
    ipc.send('call-window-method', 'setAutoHideMenuBar', autoHide)
    ipc.send('call-window-method', 'setMenuBarVisibility', not autoHide)

if includeDeprecatedAPIs
  # Deprecated: Callers should be converted to use atom.deserializers
  Atom::registerRepresentationClass = ->
    deprecate("Callers should be converted to use atom.deserializers")

  # Deprecated: Callers should be converted to use atom.deserializers
  Atom::registerRepresentationClasses = ->
    deprecate("Callers should be converted to use atom.deserializers")
