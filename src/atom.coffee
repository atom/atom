fsUtils = require './fs-utils'
$ = require './jquery-extensions'
_ = require './underscore-extensions'
Package = require './package'
ipc = require 'ipc'
remote = require 'remote'
shell = require 'shell'
crypto = require 'crypto'
path = require 'path'
dialog = remote.require 'dialog'
app = remote.require 'app'
{Document} = require 'telepath'
PackageManager = require './package-manager'
ThemeManager = require './theme-manager'
ContextMenuManager = require './context-menu-manager'

module.exports =
class Atom
  constructor: ->
    @packages = new PackageManager()
    @themes = new ThemeManager()
    @contextMenu = new ContextMenuManager(@getLoadSettings().devMode)

  getLoadSettings: ->
    @getCurrentWindow().loadSettings

  getCurrentWindow: ->
    remote.getCurrentWindow()

  #TODO Remove theses once packages have been migrated
  getPackageState: (args...) -> @packages.getPackageState(args...)
  setPackageState: (args...) -> @packages.setPackageState(args...)
  activatePackages: (args...) -> @packages.activatePackages(args...)
  activatePackage: (args...) -> @packages.activatePackage(args...)
  deactivatePackages: (args...) -> @packages.deactivatePackage(args...)
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
      pack.reloadStylesheets?() for name, pack of @getLoadedPackages()
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

  exit: (status) ->
    app.exit(status)

  toggleFullScreen: ->
    @setFullScreen(!@isFullScreen())

  setFullScreen: (fullScreen=false) ->
    @getCurrentWindow().setFullScreen(fullScreen)

  isFullScreen: ->
    @getCurrentWindow().isFullScreen()

  getHomeDirPath: ->
    app.getHomeDir()

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
      path.join(config.userStoragePath, filename)
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
      documentState = JSON.parse(documentStateJson) if documentStateJson?
    catch error
      console.warn "Error parsing window state: #{windowStatePath}", error.stack, error

    doc = Document.deserialize(state: documentState) if documentState?
    doc ?= Document.create()
    window.site = doc.site # TODO: Remove this when everything is using telepath models
    doc

  saveWindowState: ->
    windowState = @getWindowState()
    if windowStatePath = @getWindowStatePath()
      windowState.saveSync(path: windowStatePath)
    else
      @getLoadSettings().windowState = JSON.stringify(windowState.serialize())

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
    userInitScriptPath = path.join(config.configDirPath, "user.coffee")
    try
      require userInitScriptPath if fsUtils.isFileSync(userInitScriptPath)
    catch error
      console.error "Failed to load `#{userInitScriptPath}`", error.stack, error
