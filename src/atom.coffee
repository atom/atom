crypto = require 'crypto'
ipc = require 'ipc'
os = require 'os'
path = require 'path'
remote = require 'remote'
screen = require 'screen'
shell = require 'shell'

_ = require 'underscore-plus'
{deprecated} = require 'grim'
{Model} = require 'theorist'
fs = require 'fs-plus'

{$} = require './space-pen-extensions'
WindowEventHandler = require './window-event-handler'

# Public: Atom global for dealing with packages, themes, menus, and the window.
#
# An instance of this class is always available as the `atom` global.
#
# ## Useful properties available:
#
#  * `atom.clipboard`     - A {Clipboard} instance
#  * `atom.config`        - A {Config} instance
#  * `atom.contextMenu`   - A {ContextMenuManager} instance
#  * `atom.deserializers` - A {DeserializerManager} instance
#  * `atom.keymaps`        - A {KeymapManager} instance
#  * `atom.menu`          - A {MenuManager} instance
#  * `atom.packages`      - A {PackageManager} instance
#  * `atom.project`       - A {Project} instance
#  * `atom.syntax`        - A {Syntax} instance
#  * `atom.themes`        - A {ThemeManager} instance
#  * `atom.workspace`     - A {Workspace} instance
#  * `atom.workspaceView` - A {WorkspaceView} instance
module.exports =
class Atom extends Model
  @version: 1  # Increment this when the serialization format changes

  # Public: Load or create the Atom environment in the given mode.
  #
  # mode - Pass 'editor' or 'spec' depending on the kind of environment you
  #        want to build.
  #
  # Returns an Atom instance, fully initialized
  @loadOrCreate: (mode) ->
    @deserialize(@loadState(mode)) ? new this({mode, @version})

  # Deserializes the Atom environment from a state object
  @deserialize: (state) ->
    new this(state) if state?.version is @version

  # Loads and returns the serialized state corresponding to this window
  # if it exists; otherwise returns undefined.
  @loadState: (mode) ->
    statePath = @getStatePath(mode)

    if fs.existsSync(statePath)
      try
        stateString = fs.readFileSync(statePath, 'utf8')
      catch error
        console.warn "Error reading window state: #{statePath}", error.stack, error
    else
      stateString = @getLoadSettings().windowState

    try
      JSON.parse(stateString) if stateString?
    catch error
      console.warn "Error parsing window state: #{statePath} #{error.stack}", error

  # Returns the path where the state for the current window will be
  # located if it exists.
  @getStatePath: (mode) ->
    switch mode
      when 'spec'
        filename = 'spec'
      when 'editor'
        {initialPath} = @getLoadSettings()
        if initialPath
          sha1 = crypto.createHash('sha1').update(initialPath).digest('hex')
          filename = "editor-#{sha1}"

    if filename
      path.join(@getStorageDirPath(), filename)
    else
      null

  # Get the directory path to Atom's configuration area.
  #
  # Returns the absolute path to ~/.atom
  @getConfigDirPath: ->
    @configDirPath ?= fs.absolute('~/.atom')

  # Get the path to Atom's storage directory.
  #
  # Returns the absolute path to ~/.atom/storage
  @getStorageDirPath: ->
    @storageDirPath ?= path.join(@getConfigDirPath(), 'storage')

  # Returns the load settings hash associated with the current window.
  @getLoadSettings: ->
    @loadSettings ?= JSON.parse(decodeURIComponent(location.search.substr(14)))
    cloned = _.deepClone(@loadSettings)
    # The loadSettings.windowState could be large, request it only when needed.
    cloned.__defineGetter__ 'windowState', =>
      @getCurrentWindow().loadSettings.windowState
    cloned.__defineSetter__ 'windowState', (value) =>
      @getCurrentWindow().loadSettings.windowState = value
    cloned

  @getCurrentWindow: ->
    remote.getCurrentWindow()

  workspaceViewParentSelector: 'body'

  # Call .loadOrCreate instead
  constructor: (@state) ->
    {@mode} = @state
    DeserializerManager = require './deserializer-manager'
    @deserializers = new DeserializerManager()

  # Public: Sets up the basic services that should be available in all modes
  # (both spec and application). Call after this instance has been assigned to
  # the `atom` global.
  initialize: ->
    window.onerror = =>
      @openDevTools()
      @executeJavaScriptInDevTools('InspectorFrontendAPI.showConsole()')
      @emit 'uncaught-error', arguments...

    @unsubscribe()
    @setBodyPlatformClass()

    @loadTime = null

    Config = require './config'
    KeymapManager = require './keymap-extensions'
    PackageManager = require './package-manager'
    Clipboard = require './clipboard'
    Syntax = require './syntax'
    ThemeManager = require './theme-manager'
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
    @keymap = @keymaps # Deprecated
    @packages = new PackageManager({devMode, configDirPath, resourcePath, safeMode})
    @themes = new ThemeManager({packageManager: @packages, configDirPath, resourcePath, safeMode})
    @contextMenu = new ContextMenuManager(devMode)
    @menu = new MenuManager({resourcePath})
    @clipboard = new Clipboard()

    @syntax = @deserializers.deserialize(@state.syntax) ? new Syntax()

    @subscribe @packages, 'activated', => @watchThemes()

    Project = require './project'
    TextBuffer = require 'text-buffer'
    @deserializers.add(TextBuffer)
    TokenizedBuffer = require './tokenized-buffer'
    DisplayBuffer = require './display-buffer'
    Editor = require './editor'

    @windowEventHandler = new WindowEventHandler

  # Deprecated: Callers should be converted to use atom.deserializers
  registerRepresentationClass: ->
    deprecated("Callers should be converted to use atom.deserializers")

  # Deprecated: Callers should be converted to use atom.deserializers
  registerRepresentationClasses: ->
    deprecated("Callers should be converted to use atom.deserializers")

  setBodyPlatformClass: ->
    document.body.classList.add("platform-#{process.platform}")

  # Public: Get the current window
  getCurrentWindow: ->
    @constructor.getCurrentWindow()

  # Public: Get the dimensions of this window.
  #
  # Returns an object with x, y, width, and height keys.
  getWindowDimensions: ->
    browserWindow = @getCurrentWindow()
    [x, y] = browserWindow.getPosition()
    [width, height] = browserWindow.getSize()
    {x, y, width, height}

  # Public: Set the dimensions of the window.
  #
  # The window will be centered if either the x or y coordinate is not set
  # in the dimensions parameter. If x or y are omitted the window will be
  # centered. If height or width are omitted only the position will be changed.
  #
  # dimensions - An {Object} with the following keys:
  #   :x - The new x coordinate.
  #   :y - The new y coordinate.
  #   :width - The new width.
  #   :height - The new height.
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
      {width, height} = screen.getPrimaryDisplay().workAreaSize
      {x: 0, y: 0, width: Math.min(1024, width), height}

  restoreWindowDimensions: ->
    dimensions = @state.windowDimensions
    unless @isValidDimensions(dimensions)
      dimensions = @getDefaultWindowDimensions()
    @setWindowDimensions(dimensions)

  storeWindowDimensions: ->
    dimensions = @getWindowDimensions()
    @state.windowDimensions = dimensions if @isValidDimensions(dimensions)

  # Public: Get the load settings for the current window.
  #
  # Returns an object containing all the load setting key/value pairs.
  getLoadSettings: ->
    @constructor.getLoadSettings()

  deserializeProject: ->
    Project = require './project'

    startTime = Date.now()
    @project ?= @deserializers.deserialize(@state.project) ? new Project(path: @getLoadSettings().initialPath)
    @deserializeTimings.project = Date.now() - startTime

  deserializeWorkspaceView: ->
    Workspace = require './workspace'
    WorkspaceView = require './workspace-view'

    startTime = Date.now()
    @workspace = Workspace.deserialize(@state.workspace) ? new Workspace
    @workspaceView = new WorkspaceView(@workspace)
    @deserializeTimings.workspace = Date.now() - startTime

    @keymaps.defaultTarget = @workspaceView[0]
    $(@workspaceViewParentSelector).append(@workspaceView)

  deserializePackageStates: ->
    @packages.packageStates = @state.packageStates ? {}
    delete @state.packageStates

  deserializeEditorWindow: ->
    @deserializeTimings = {}
    @deserializePackageStates()
    @deserializeProject()
    @deserializeWorkspaceView()

  # Call this method when establishing a real application window.
  startEditorWindow: ->
    CommandInstaller = require './command-installer'
    resourcePath = atom.getLoadSettings().resourcePath
    CommandInstaller.installAtomCommand resourcePath, false, (error) ->
      console.warn error.message if error?
    CommandInstaller.installApmCommand resourcePath, false, (error) ->
      console.warn error.message if error?

    @restoreWindowDimensions()
    @config.load()
    @config.setDefaults('core', require('./workspace-view').configDefaults)
    @config.setDefaults('editor', require('./editor-view').configDefaults)
    @keymaps.loadBundledKeymaps()
    @themes.loadBaseStylesheets()
    @packages.loadPackages()
    @deserializeEditorWindow()
    @packages.activate()
    @keymaps.loadUserKeymap()
    @requireUserInitScript()
    @menu.update()

    @displayWindow()

  unloadEditorWindow: ->
    return if not @project and not @workspaceView

    @state.syntax = @syntax.serialize()
    @state.project = @project.serialize()
    @state.workspace = @workspace.serialize()
    @packages.deactivatePackages()
    @state.packageStates = @packages.packageStates
    @saveSync()
    @windowState = null

  removeEditorWindow: ->
    return if not @project and not @workspaceView

    @workspaceView?.remove()
    @workspaceView = null
    @project?.destroy()
    @project = null

    @windowEventHandler?.unsubscribe()

  loadThemes: ->
    @themes.load()

  watchThemes: ->
    @themes.on 'reloaded', =>
      # Only reload stylesheets from non-theme packages
      for pack in @packages.getActivePackages() when pack.getType() isnt 'theme'
        pack.reloadStylesheets?()
      null

  # Public: Open a new Atom window using the given options.
  #
  # Calling this method without an options parameter will open a prompt to pick
  # a file/folder to open in the new window.
  #
  # options - An {Object} with the following keys:
  #   :pathsToOpen -  An {Array} of {String} paths to open.
  open: (options) ->
    ipc.send('open', options)

  # Public: Open a confirm dialog.
  #
  # ## Example
  #
  # ```coffee
  #   atom.confirm
  #     message: 'How you feeling?'
  #     detailedMessage: 'Be honest.'
  #     buttons:
  #       Good: -> window.alert('good to hear')
  #       Bad:  -> window.alert('bummer')
  # ```
  #
  # options - An {Object} with the following keys:
  #   :message - The {String} message to display.
  #   :detailedMessage - The {String} detailed message to display.
  #   :buttons - Either an array of strings or an object where keys are
  #              button names and the values are callbacks to invoke when
  #              clicked.
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

  showSaveDialog: (callback) ->
    callback(showSaveDialogSync())

  showSaveDialogSync: (defaultPath) ->
    defaultPath ?= @project?.getPath()
    currentWindow = @getCurrentWindow()
    dialog = remote.require('dialog')
    dialog.showSaveDialog currentWindow, {title: 'Save File', defaultPath}

  # Public: Open the dev tools for the current window.
  openDevTools: ->
    ipc.send('call-window-method', 'openDevTools')

  # Public: Toggle the visibility of the dev tools for the current window.
  toggleDevTools: ->
    ipc.send('call-window-method', 'toggleDevTools')

  # Public: Execute code in dev tools.
  executeJavaScriptInDevTools: (code) ->
    ipc.send('call-window-method', 'executeJavaScriptInDevTools', code)

  # Public: Reload the current window.
  reload: ->
    ipc.send('call-window-method', 'restart')

  # Public: Focus the current window.
  focus: ->
    ipc.send('call-window-method', 'focus')
    $(window).focus()

  # Public: Show the current window.
  show: ->
    ipc.send('call-window-method', 'show')

  # Public: Hide the current window.
  hide: ->
    ipc.send('call-window-method', 'hide')

  # Public: Set the size of current window.
  #
  # width  - The {Number} of pixels.
  # height - The {Number} of pixels.
  setSize: (width, height) ->
    @getCurrentWindow().setSize(width, height)

  # Public: Set the position of current window.
  #
  # x - The {Number} of pixels.
  # y - The {Number} of pixels.
  setPosition: (x, y) ->
    ipc.send('call-window-method', 'setPosition', x, y)

  # Public: Move current window to the center of the screen.
  center: ->
    ipc.send('call-window-method', 'center')

  # Schedule the window to be shown and focused on the next tick.
  #
  # This is done in a next tick to prevent a white flicker from occurring
  # if called synchronously.
  displayWindow: ->
    setImmediate =>
      @show()
      @focus()
      @setFullScreen(true) if @workspaceView.fullScreen

  # Public: Close the current window.
  close: ->
    @getCurrentWindow().close()

  exit: (status) ->
    app = remote.require('app')
    app.emit('will-exit')
    remote.process.exit(status)

  # Public: Is the current window in development mode?
  inDevMode: ->
    @getLoadSettings().devMode

  # Public: Is the current window running specs?
  inSpecMode: ->
    @getLoadSettings().isSpec

  # Public: Toggle the full screen state of the current window.
  toggleFullScreen: ->
    @setFullScreen(!@isFullScreen())

  # Public: Set the full screen state of the current window.
  setFullScreen: (fullScreen=false) ->
    ipc.send('call-window-method', 'setFullScreen', fullScreen)
    if fullScreen then document.body.classList.add("fullscreen") else document.body.classList.remove("fullscreen")

  # Public: Is the current window in full screen mode?
  isFullScreen: ->
    @getCurrentWindow().isFullScreen()

  # Public: Get the version of the Atom application.
  #
  # Returns the version text {String}.
  getVersion: ->
    @appVersion ?= @getLoadSettings().appVersion

  # Public: Determine whether the current version is an official release.
  isReleasedVersion: ->
    not /\w{7}/.test(@getVersion()) # Check if the release is a 7-character SHA prefix

  # Public: Get the directory path to Atom's configuration area.
  #
  # Returns the absolute path to `~/.atom`.
  getConfigDirPath: ->
    @constructor.getConfigDirPath()

  saveSync: ->
    stateString = JSON.stringify(@state)
    if statePath = @constructor.getStatePath(@mode)
      fs.writeFileSync(statePath, stateString, 'utf8')
    else
      @getCurrentWindow().loadSettings.windowState = stateString

  # Public: Get the time taken to completely load the current window.
  #
  # This time include things like loading and activating packages, creating
  # DOM elements for the editor, and reading the config.
  #
  # Returns the number of milliseconds taken to load the window or null
  # if the window hasn't finished loading yet.
  getWindowLoadTime: ->
    @loadTime

  crashMainProcess: ->
    remote.process.crash()

  crashRenderProcess: ->
    process.crash()

  # Public: Visually and audibly trigger a beep.
  beep: ->
    shell.beep() if @config.get('core.audioBeep')
    @workspaceView.trigger 'beep'

  getUserInitScriptPath: ->
    initScriptPath = fs.resolve(@getConfigDirPath(), 'init', ['js', 'coffee'])
    initScriptPath ? path.join(@getConfigDirPath(), 'init.coffee')

  requireUserInitScript: ->
    if userInitScriptPath = @getUserInitScriptPath()
      try
        require(userInitScriptPath) if fs.isFileSync(userInitScriptPath)
      catch error
        console.error "Failed to load `#{userInitScriptPath}`", error.stack, error

  # Public: Require the module with the given globals.
  #
  # The globals will be set on the `window` object and removed after the
  # require completes.
  #
  # id - The {String} module name or path.
  # globals - An {Object} to set as globals during require (default: {})
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
