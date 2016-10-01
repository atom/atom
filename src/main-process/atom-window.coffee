{BrowserWindow, app, dialog, ipcMain} = require 'electron'
path = require 'path'
fs = require 'fs'
url = require 'url'
{EventEmitter} = require 'events'

module.exports =
class AtomWindow
  Object.assign @prototype, EventEmitter.prototype

  @iconPath: path.resolve(__dirname, '..', '..', 'resources', 'atom.png')
  @includeShellLoadTime: true

  browserWindow: null
  loaded: null
  isSpec: null

  constructor: (@atomApplication, @fileRecoveryService, settings={}) ->
    {@resourcePath, pathToOpen, locationsToOpen, @isSpec, @headless, @safeMode, @devMode} = settings
    locationsToOpen ?= [{pathToOpen}] if pathToOpen
    locationsToOpen ?= []

    @loadedPromise = new Promise((@resolveLoadedPromise) =>)
    @closedPromise = new Promise((@resolveClosedPromise) =>)

    options =
      show: false
      title: 'Atom'
      # Add an opaque backgroundColor (instead of keeping the default
      # transparent one) to prevent subpixel anti-aliasing from being disabled.
      # We believe this is a regression introduced with Electron 0.37.3, and
      # thus we should remove this as soon as a fix gets released.
      backgroundColor: "#fff"
      webPreferences:
        # Prevent specs from throttling when the window is in the background:
        # this should result in faster CI builds, and an improvement in the
        # local development experience when running specs through the UI (which
        # now won't pause when e.g. minimizing the window).
        backgroundThrottling: not @isSpec

    # Don't set icon on Windows so the exe's ico will be used as window and
    # taskbar's icon. See https://github.com/atom/atom/issues/4811 for more.
    if process.platform is 'linux'
      options.icon = @constructor.iconPath

    if @shouldHideTitleBar()
      options.titleBarStyle = 'hidden'

    @browserWindow = new BrowserWindow options
    @atomApplication.addWindow(this)

    @handleEvents()

    loadSettings = Object.assign({}, settings)
    loadSettings.appVersion = app.getVersion()
    loadSettings.resourcePath = @resourcePath
    loadSettings.devMode ?= false
    loadSettings.safeMode ?= false
    loadSettings.atomHome = process.env.ATOM_HOME
    loadSettings.clearWindowState ?= false
    loadSettings.initialPaths ?=
      for {pathToOpen} in locationsToOpen when pathToOpen
        if fs.statSyncNoException(pathToOpen).isFile?()
          path.dirname(pathToOpen)
        else
          pathToOpen

    loadSettings.initialPaths.sort()

    # Only send to the first non-spec window created
    if @constructor.includeShellLoadTime and not @isSpec
      @constructor.includeShellLoadTime = false
      loadSettings.shellLoadTime ?= Date.now() - global.shellStartTime

    @browserWindow.loadSettings = loadSettings

    @browserWindow.on 'window:loaded', =>
      @emit 'window:loaded'
      @resolveLoadedPromise()

    @setLoadSettings(loadSettings)
    @env = loadSettings.env if loadSettings.env?
    @browserWindow.focusOnWebView() if @isSpec
    @browserWindow.temporaryState = {windowDimensions} if windowDimensions?

    hasPathToOpen = not (locationsToOpen.length is 1 and not locationsToOpen[0].pathToOpen?)
    @openLocations(locationsToOpen) if hasPathToOpen and not @isSpecWindow()

  setLoadSettings: (loadSettings) ->
    @browserWindow.loadURL url.format
      protocol: 'file'
      pathname: "#{@resourcePath}/static/index.html"
      slashes: true
      hash: encodeURIComponent(JSON.stringify(loadSettings))

  getLoadSettings: ->
    if @browserWindow.webContents? and not @browserWindow.webContents.isLoading()
      hash = url.parse(@browserWindow.webContents.getURL()).hash.substr(1)
      JSON.parse(decodeURIComponent(hash))

  hasProjectPath: -> @getLoadSettings().initialPaths?.length > 0

  setupContextMenu: ->
    ContextMenu = require './context-menu'

    @browserWindow.on 'context-menu', (menuTemplate) =>
      new ContextMenu(menuTemplate, this)

  containsPaths: (paths) ->
    for pathToCheck in paths
      return false unless @containsPath(pathToCheck)
    true

  containsPath: (pathToCheck) ->
    @getLoadSettings()?.initialPaths?.some (projectPath) ->
      if not projectPath
        false
      else if not pathToCheck
        false
      else if pathToCheck is projectPath
        true
      else if fs.statSyncNoException(pathToCheck).isDirectory?()
        false
      else if pathToCheck.indexOf(path.join(projectPath, path.sep)) is 0
        true
      else
        false

  handleEvents: ->
    @browserWindow.on 'close', (event) =>
      unless @atomApplication.quitting or @unloading
        event.preventDefault()
        @unloading = true
        @atomApplication.saveState(false)
        @saveState().then(=> @close())

    @browserWindow.on 'closed', =>
      @fileRecoveryService.didCloseWindow(this)
      @atomApplication.removeWindow(this)
      @resolveClosedPromise()

    @browserWindow.on 'unresponsive', =>
      return if @isSpec

      chosen = dialog.showMessageBox @browserWindow,
        type: 'warning'
        buttons: ['Close', 'Keep Waiting']
        message: 'Editor is not responding'
        detail: 'The editor is not responding. Would you like to force close it or just keep waiting?'
      @browserWindow.destroy() if chosen is 0

    @browserWindow.webContents.on 'crashed', =>
      @atomApplication.exit(100) if @headless

      @fileRecoveryService.didCrashWindow(this)
      chosen = dialog.showMessageBox @browserWindow,
        type: 'warning'
        buttons: ['Close Window', 'Reload', 'Keep It Open']
        message: 'The editor has crashed'
        detail: 'Please report this issue to https://github.com/atom/atom'
      switch chosen
        when 0 then @browserWindow.destroy()
        when 1 then @browserWindow.reload()

    @browserWindow.webContents.on 'will-navigate', (event, url) =>
      unless url is @browserWindow.webContents.getURL()
        event.preventDefault()

    @setupContextMenu()

    if @isSpec
      # Spec window's web view should always have focus
      @browserWindow.on 'blur', =>
        @browserWindow.focusOnWebView()

  didCancelWindowUnload: ->
    @unloading = false

  saveState: ->
    if @isSpecWindow()
      return Promise.resolve()

    @lastSaveStatePromise = new Promise (resolve) =>
      callback = (event) =>
        if BrowserWindow.fromWebContents(event.sender) is @browserWindow
          ipcMain.removeListener('did-save-window-state', callback)
          resolve()
      ipcMain.on('did-save-window-state', callback)
      @browserWindow.webContents.send('save-window-state')
    @lastSaveStatePromise

  openPath: (pathToOpen, initialLine, initialColumn) ->
    @openLocations([{pathToOpen, initialLine, initialColumn}])

  openLocations: (locationsToOpen) ->
    @loadedPromise.then => @sendMessage 'open-locations', locationsToOpen

  replaceEnvironment: (env) ->
    @browserWindow.webContents.send 'environment', env

  sendMessage: (message, detail) ->
    @browserWindow.webContents.send 'message', message, detail

  sendCommand: (command, args...) ->
    if @isSpecWindow()
      unless @atomApplication.sendCommandToFirstResponder(command)
        switch command
          when 'window:reload' then @reload()
          when 'window:toggle-dev-tools' then @toggleDevTools()
          when 'window:close' then @close()
    else if @isWebViewFocused()
      @sendCommandToBrowserWindow(command, args...)
    else
      unless @atomApplication.sendCommandToFirstResponder(command)
        @sendCommandToBrowserWindow(command, args...)

  sendCommandToBrowserWindow: (command, args...) ->
    action = if args[0]?.contextCommand then 'context-command' else 'command'
    @browserWindow.webContents.send action, command, args...

  getDimensions: ->
    [x, y] = @browserWindow.getPosition()
    [width, height] = @browserWindow.getSize()
    {x, y, width, height}

  shouldHideTitleBar: ->
    not @isSpec and
    process.platform is 'darwin' and
    @atomApplication.config.get('core.useCustomTitleBar')

  close: -> @browserWindow.close()

  focus: -> @browserWindow.focus()

  minimize: -> @browserWindow.minimize()

  maximize: -> @browserWindow.maximize()

  unmaximize: -> @browserWindow.unmaximize()

  restore: -> @browserWindow.restore()

  setFullScreen: (fullScreen) -> @browserWindow.setFullScreen(fullScreen)

  setAutoHideMenuBar: (autoHideMenuBar) -> @browserWindow.setAutoHideMenuBar(autoHideMenuBar)

  handlesAtomCommands: ->
    not @isSpecWindow() and @isWebViewFocused()

  isFocused: -> @browserWindow.isFocused()

  isMaximized: -> @browserWindow.isMaximized()

  isMinimized: -> @browserWindow.isMinimized()

  isWebViewFocused: -> @browserWindow.isWebViewFocused()

  isSpecWindow: -> @isSpec

  reload: ->
    @loadedPromise = new Promise((@resolveLoadedPromise) =>)
    @saveState().then => @browserWindow.reload()
    @loadedPromise

  toggleDevTools: -> @browserWindow.toggleDevTools()

  openDevTools: -> @browserWindow.openDevTools()

  closeDevTools: -> @browserWindow.closeDevTools()

  setDocumentEdited: (documentEdited) -> @browserWindow.setDocumentEdited(documentEdited)

  setRepresentedFilename: (representedFilename) -> @browserWindow.setRepresentedFilename(representedFilename)

  copy: -> @browserWindow.copy()
