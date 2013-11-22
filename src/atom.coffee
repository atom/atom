crypto = require 'crypto'
ipc = require 'ipc'
os = require 'os'
path = require 'path'
remote = require 'remote'
shell = require 'shell'
dialog = remote.require 'dialog'
app = remote.require 'app'

_ = require 'underscore-plus'
{Document} = require 'telepath'
fs = require 'fs-plus'
{Subscriber} = require 'emissary'

{$} = require './space-pen-extensions'
DeserializerManager = require './deserializer-manager'
Package = require './package'
SiteShim = require './site-shim'
WindowEventHandler = require './window-event-handler'

# Public: Atom global for dealing with packages, themes, menus, and the window.
#
# An instance of this class is always available as the `atom` global.
module.exports =
class Atom
  Subscriber.includeInto(this)

  constructor: ->
    @rootViewParentSelector = 'body'
    @deserializers = new DeserializerManager()

  initialize: ->
    @unsubscribe()
    @setBodyPlatformClass()

    {devMode, resourcePath} = atom.getLoadSettings()
    configDirPath = @getConfigDirPath()

    Config = require './config'
    Keymap = require './keymap'
    PackageManager = require './package-manager'
    Pasteboard = require './pasteboard'
    Syntax = require './syntax'
    ThemeManager = require './theme-manager'
    ContextMenuManager = require './context-menu-manager'
    MenuManager = require './menu-manager'

    @config = new Config({configDirPath, resourcePath})
    @keymap = new Keymap({configDirPath, resourcePath})
    @packages = new PackageManager({devMode, configDirPath, resourcePath})

    @subscribe @packages, 'activated', => @watchThemes()
    @themes = new ThemeManager({packageManager: @packages, configDirPath, resourcePath})
    @contextMenu = new ContextMenuManager(devMode)
    @menu = new MenuManager({resourcePath})
    @pasteboard = new Pasteboard()
    @syntax = @deserializers.deserialize(@getWindowState('syntax')) ? new Syntax()

  # Private: This method is called in any window needing a general environment, including specs
  setUpEnvironment: (@windowMode) ->
    @initialize()

  # Private:
  setBodyPlatformClass: ->
    document.body.classList.add("platform-#{process.platform}")

  getCurrentWindow: ->
    remote.getCurrentWindow()

  # Public: Get the dimensions of this window.
  #
  # Returns an object with x, y, width, and height keys.
  getDimensions: ->
    browserWindow = @getCurrentWindow()
    [x, y] = browserWindow.getPosition()
    [width, height] = browserWindow.getSize()
    {x, y, width, height}

  # Public: Set the dimensions of the window.
  #
  # The window will be centered if either the x or y coordinate is not set
  # in the dimensions parameter.
  #
  # * dimensions:
  #    + x:
  #      The new x coordinate.
  #    + y:
  #      The new y coordinate.
  #    + width:
  #      The new width.
  #    + height:
  #      The new height.
  setDimensions: ({x, y, width, height}) ->
    browserWindow = @getCurrentWindow()
    browserWindow.setSize(width, height)
    if x? and y?
      browserWindow.setPosition(x, y)
    else
      browserWindow.center()

  restoreDimensions: ->
    dimensions = @getWindowState().getObject('dimensions')
    unless dimensions?.width and dimensions?.height
      {height, width} = @getLoadSettings().initialSize ? {}
      height ?= screen.availHeight
      width ?= Math.min(screen.availWidth, 1024)
      dimensions = {width, height}
    @setDimensions(dimensions)

  # Public: Get the load settings for the current window.
  #
  # Returns an object containing all the load setting key/value pairs.
  getLoadSettings: ->
    @loadSettings ?= _.deepClone(@getCurrentWindow().loadSettings)
    _.deepClone(@loadSettings)

  deserializeProject: ->
    Project = require './project'
    @project = @getWindowState('project')
    unless @project instanceof Project
      @project = new Project(path: @getLoadSettings().initialPath)
      @setWindowState('project', @project)

  deserializeRootView: ->
    RootView = require './root-view'
    state = @getWindowState()
    @rootView = @deserializers.deserialize(state.get('rootView'))
    unless @rootView?
      @rootView = new RootView()
      state.set('rootView', @rootView.getState())
    $(@rootViewParentSelector).append(@rootView)

  deserializePackageStates: ->
    state = @getWindowState()
    @packages.packageStates = state.getObject('packageStates') ? {}
    state.remove('packageStates')

  deserializeEditorWindow: ->
    @deserializePackageStates()
    @deserializeProject()
    @deserializeRootView()

  # Private: This method is only called when opening a real application window
  startEditorWindow: ->
    if process.platform is 'darwin'
      CommandInstaller = require './command-installer'
      CommandInstaller.installAtomCommand()
      CommandInstaller.installApmCommand()

    @windowEventHandler = new WindowEventHandler
    @restoreDimensions()
    @config.load()
    @config.setDefaults('core', require('./root-view').configDefaults)
    @config.setDefaults('editor', require('./editor-view').configDefaults)
    @keymap.loadBundledKeymaps()
    @themes.loadBaseStylesheets()
    @packages.loadPackages()
    @deserializeEditorWindow()
    @packages.activate()
    @keymap.loadUserKeymap()
    @requireUserInitScript()
    @menu.update()

    $(window).on 'unload', =>
      $(document.body).hide()
      @unloadEditorWindow()
      false

    @displayWindow()

  unloadEditorWindow: ->
    return if not @project and not @rootView

    windowState = @getWindowState()
    windowState.set('project', @project)
    windowState.set('syntax', @syntax.serialize())
    windowState.set('rootView', @rootView.serialize())
    @packages.deactivatePackages()
    windowState.set('packageStates', @packages.packageStates)
    @saveWindowState()
    @rootView.remove()
    @project.destroy()
    @windowEventHandler?.unsubscribe()

  # Set up the default event handlers and menus for a non-editor window.
  #
  # This can be used by packages to have a minimum level of keybindings and
  # menus available when not using the standard editor window.
  #
  # This should only be called after setUpEnvironment() has been called.
  setUpDefaultEvents: ->
    @windowEventHandler = new WindowEventHandler
    @keymap.loadBundledKeymaps()
    @menu.update()

  loadThemes: ->
    @themes.load()

  watchThemes: ->
    @themes.on 'reloaded', =>
      # Only reload stylesheets from non-theme packages
      for pack in @packages.getActivePackages() when pack.getType() isnt 'theme'
        pack.reloadStylesheets?()
      null

  open: (options) ->
    ipc.sendChannel('open', options)

  confirm: (message, detailedMessage, buttonLabelsAndCallbacks...) ->
    buttons = []
    callbacks = []
    while buttonLabelsAndCallbacks.length
      do =>
        buttons.push buttonLabelsAndCallbacks.shift()
        callbacks.push buttonLabelsAndCallbacks.shift()

    chosen = @confirmSync(message, detailedMessage, buttons)
    callbacks[chosen]?()

  confirmSync: (message, detailedMessage, buttons, browserWindow=@getCurrentWindow()) ->
    dialog.showMessageBox browserWindow,
      type: 'info'
      message: message
      detail: detailedMessage
      buttons: buttons

  showSaveDialog: (callback) ->
    callback(showSaveDialogSync())

  showSaveDialogSync: (defaultPath) ->
    defaultPath ?= @project?.getPath()
    currentWindow = @getCurrentWindow()
    dialog.showSaveDialog currentWindow, {title: 'Save File', defaultPath}

  openDevTools: ->
    @getCurrentWindow().openDevTools()

  toggleDevTools: ->
    @getCurrentWindow().toggleDevTools()

  reload: ->
    @getCurrentWindow().restart()

  focus: ->
    @getCurrentWindow().focus()
    $(window).focus()

  show: ->
    @getCurrentWindow().show()

  hide: ->
    @getCurrentWindow().hide()

  # Private: Schedule the window to be shown and focused on the next tick.
  #
  # This is done in a next tick to prevent a white flicker from occurring
  # if called synchronously.
  displayWindow: ->
    setImmediate =>
      @show()
      @focus()
      @setFullScreen(true) if @rootView.getState().get('fullScreen')

  close: ->
    @getCurrentWindow().close()

  exit: (status) -> app.exit(status)

  inDevMode: ->
    @getLoadSettings().devMode

  inSpecMode: ->
    @getLoadSettings().isSpec

  toggleFullScreen: ->
    @setFullScreen(!@isFullScreen())

  setFullScreen: (fullScreen=false) ->
    @getCurrentWindow().setFullScreen(fullScreen)

  isFullScreen: ->
    @getCurrentWindow().isFullScreen()

  getVersion: ->
    app.getVersion()

  getHomeDirPath: ->
    process.env[if process.platform is 'win32' then 'USERPROFILE' else 'HOME']

  getTempDirPath: ->
    if process.platform is 'win32' then os.tmpdir() else '/tmp'

  # Public: Get the directory path to Atom's configuration area.
  getConfigDirPath: ->
    @configDirPath ?= fs.absolute('~/.atom')

  # Public: Get the directory path to Atom's storage area.
  getStorageDirPath: ->
    @storageDirPath ?= path.join(@getConfigDirPath(), 'storage')

  getWindowStatePath: ->
    switch @windowMode
      when 'spec'
        filename = @windowMode
      when 'editor'
        {initialPath} = @getLoadSettings()
        if initialPath
          sha1 = crypto.createHash('sha1').update(initialPath).digest('hex')
          filename = "editor-#{sha1}"

    if filename
      path.join(@getStorageDirPath(), filename)
    else
      null

  setWindowState: (keyPath, value) ->
    windowState = @getWindowState()
    windowState.set(keyPath, value)
    windowState

  loadWindowState: ->
    if windowStatePath = @getWindowStatePath()
      if fs.existsSync(windowStatePath)
        try
          documentStateJson  = fs.readFileSync(windowStatePath, 'utf8')
        catch error
          console.warn "Error reading window state: #{windowStatePath}", error.stack, error
    else
      documentStateJson = @getLoadSettings().windowState

    try
      documentState = JSON.parse(documentStateJson) if documentStateJson
    catch error
      console.warn "Error parsing window state: #{windowStatePath}", error.stack, error

    doc = Document.deserialize(documentState) if documentState?
    doc ?= Document.create()
    doc.registerModelClasses(require('./text-buffer'), require('./project'))
    # TODO: Remove this when everything is using telepath models
    if @site?
      @site.setRootDocument(doc)
    else
      @site = new SiteShim(doc)
    doc

  saveWindowState: ->
    windowState = @getWindowState()
    if windowStatePath = @getWindowStatePath()
      windowState.saveSync(windowStatePath)
    else
      @getCurrentWindow().loadSettings.windowState = JSON.stringify(windowState.serializeForPersistence())

  getWindowState: (keyPath) ->
    @windowState ?= @loadWindowState()
    if keyPath
      @windowState.get(keyPath)
    else
      @windowState

  # Private: Returns a replicated copy of the current state.
  replicate: ->
    @getWindowState().replicate()

  crashMainProcess: ->
    remote.process.crash()

  crashRenderProcess: ->
    process.crash()

  beep: ->
    shell.beep() if @config.get('core.audioBeep')
    @rootView.trigger 'beep'

  requireUserInitScript: ->
    if userInitScriptPath = fs.resolve(@getConfigDirPath(), 'user', ['js', 'coffee'])
      try
        require userInitScriptPath
      catch error
        console.error "Failed to load `#{userInitScriptPath}`", error.stack, error

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
