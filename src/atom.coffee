#TODO remove once all packages have been updated
fs = require 'fs-plus'
fs.exists = fs.existsSync
fs.makeTree = fs.makeTreeSync
fs.move = fs.moveSync
fs.read = (filePath) -> fs.readFileSync(filePath, 'utf8')
fs.remove = fs.removeSync
fs.write = fs.writeFile
fs.writeSync = fs.writeFileSync

fs = require 'fs-plus'
{$} = require './space-pen-extensions'
_ = require 'underscore-plus'
Package = require './package'
ipc = require 'ipc'
remote = require 'remote'
shell = require 'shell'
crypto = require 'crypto'
path = require 'path'
os = require 'os'
dialog = remote.require 'dialog'
app = remote.require 'app'
{Document} = require 'telepath'
DeserializerManager = require './deserializer-manager'
{Subscriber} = require 'emissary'
SiteShim = require './site-shim'

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
    @syntax = deserialize(@getWindowState('syntax')) ? new Syntax()

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
    @rootView = deserialize(state.get('rootView'))
    unless @rootView?
      @rootView = new RootView()
      state.set('rootView', @rootView.getState())
    $(@rootViewParentSelector).append(@rootView)

  deserializePackageStates: ->
    state = @getWindowState()
    @packages.packageStates = state.getObject('packageStates') ? {}
    state.remove('packageStates')

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
    defaultPath ?= project?.getPath()
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
      @getCurrentWindow().loadSettings.windowState = JSON.stringify(windowState.serialize())

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
    userInitScriptPath = path.join(@getConfigDirPath(), "user.coffee")
    try
      require userInitScriptPath if fs.isFileSync(userInitScriptPath)
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
