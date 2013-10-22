#TODO remove once all packages have been updated
{Emitter} = require 'emissary'
Emitter::one = (args...) -> @once(args...)
Emitter::trigger = (args...) -> @emit(args...)
Emitter::subscriptionCount = (args...) -> @getSubscriptionCount(args...)

fsUtils = require './fs-utils'
{$} = require './space-pen-extensions'
_ = require 'underscore-plus'
Package = require './package'
ipc = require 'ipc'
remote = require 'remote'
shell = require 'shell'
{$$} = require 'space-pen'
crypto = require 'crypto'
path = require 'path'
dialog = remote.require 'dialog'
app = remote.require 'app'
{Document} = require 'telepath'
DeserializerManager = require './deserializer-manager'
{Subscriber} = require 'emissary'

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
    @keymap = new Keymap()
    @packages = new PackageManager({devMode, configDirPath, resourcePath})

    #TODO Remove once packages have been updated to not touch atom.packageStates directly
    @__defineGetter__ 'packageStates', => @packages.packageStates
    @__defineSetter__ 'packageStates', (packageStates) => @packages.packageStates = packageStates

    @subscribe @packages, 'loaded', => @watchThemes()
    @themes = new ThemeManager()
    @contextMenu = new ContextMenuManager(devMode)
    @menu = new MenuManager()
    @pasteboard = new Pasteboard()
    @syntax = deserialize(@getWindowState('syntax')) ? new Syntax()

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
    state = @getWindowState()
    @project = deserialize(state.get('project'))
    unless @project?
      @project = new Project(@getLoadSettings().initialPath)
      state.set('project', @project.getState())

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

  #TODO Remove theses once packages have been migrated
  getPackageState: (args...) -> @packages.getPackageState(args...)
  setPackageState: (args...) -> @packages.setPackageState(args...)
  activatePackages: (args...) -> @packages.activatePackages(args...)
  activatePackage: (args...) -> @packages.activatePackage(args...)
  deactivatePackages: (args...) -> @packages.deactivatePackages(args...)
  deactivatePackage: (args...) -> @packages.deactivatePackage(args...)
  getActivePackage: (args...) -> @packages.getActivePackage(args...)
  isPackageActive: (args...) -> @packages.isPackageActive(args...)
  getActivePackages: (args...) -> @packages.getActivePackages(args...)
  loadPackages: (args...) -> @packages.loadPackages(args...)
  loadPackage: (args...) -> @packages.loadPackage(args...)
  unloadPackage: (args...) -> @packages.unloadPackage(args...)
  resolvePackagePath: (args...) -> @packages.resolvePackagePath(args...)
  isInternalPackage: (args...) -> @packages.isInternalPackage(args...)
  getLoadedPackage: (args...) -> @packages.getLoadedPackage(args...)
  isPackageLoaded: (args...) -> @packages.isPackageLoaded(args...)
  getLoadedPackages: (args...) -> @packages.getLoadedPackages(args...)
  isPackageDisabled: (args...) -> @packages.isPackageDisabled(args...)
  getAvailablePackagePaths: (args...) -> @packages.getAvailablePackagePaths(args...)
  getAvailablePackageNames: (args...) -> @packages.getAvailablePackageNames(args...)
  getAvailablePackageMetadata: (args...)-> @packages.getAvailablePackageMetadata(args...)

  loadThemes: ->
    @themes.load()

  watchThemes: ->
    @themes.on 'reloaded', =>
      pack.reloadStylesheets?() for name, pack of @packages.getActivePackages()
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

  toggleFullScreen: ->
    @setFullScreen(!@isFullScreen())

  setFullScreen: (fullScreen=false) ->
    @getCurrentWindow().setFullScreen(fullScreen)

  isFullScreen: ->
    @getCurrentWindow().isFullScreen()

  getHomeDirPath: ->
    app.getHomeDir()

  # Public: Get the directory path to Atom's configuration area.
  getConfigDirPath: ->
    @configDirPath ?= fsUtils.absolute('~/.atom')

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
      path.join(@config.userStoragePath, filename)
    else
      null

  setWindowState: (keyPath, value) ->
    windowState = @getWindowState()
    windowState.set(keyPath, value)
    windowState

  loadWindowState: ->
    if windowStatePath = @getWindowStatePath()
      if fsUtils.exists(windowStatePath)
        try
          documentStateJson  = fsUtils.read(windowStatePath)
        catch error
          console.warn "Error reading window state: #{windowStatePath}", error.stack, error
    else
      documentStateJson = @getLoadSettings().windowState

    try
      documentState = JSON.parse(documentStateJson) if documentStateJson
    catch error
      console.warn "Error parsing window state: #{windowStatePath}", error.stack, error

    doc = Document.deserialize(state: documentState) if documentState?
    doc ?= Document.create()
    @site = doc.site # TODO: Remove this when everything is using telepath models
    doc

  saveWindowState: ->
    windowState = @getWindowState()
    if windowStatePath = @getWindowStatePath()
      windowState.saveSync(path: windowStatePath)
    else
      @getCurrentWindow().loadSettings.windowState = JSON.stringify(windowState.serialize())

  getWindowState: (keyPath) ->
    @windowState ?= @loadWindowState()
    if keyPath
      @windowState.get(keyPath)
    else
      @windowState

  crashMainProcess: ->
    remote.process.crash()

  crashRenderProcess: ->
    process.crash()

  beep: ->
    shell.beep()

  requireUserInitScript: ->
    userInitScriptPath = path.join(@config.configDirPath, "user.coffee")
    try
      require userInitScriptPath if fsUtils.isFileSync(userInitScriptPath)
    catch error
  visualBeep: ->
    overlay = $$ -> @div class: 'visual-beep'
    $('body').append overlay
    setTimeout((-> overlay.remove()), 1000)

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
