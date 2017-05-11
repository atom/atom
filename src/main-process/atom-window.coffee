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

    if @shouldAddCustomTitleBar()
      options.titleBarStyle = 'hidden'

    if @shouldAddCustomInsetTitleBar()
      options.titleBarStyle = 'hidden-inset'

    if @shouldHideTitleBar()
      options.frame = false

    @browserWindow = new BrowserWindow(options)
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
        stat = fs.statSyncNoException(pathToOpen) or null
        if stat?.isDirectory()
          pathToOpen
        else
          parentDirectory = path.dirname(pathToOpen)
          if stat?.isFile() or fs.existsSync(parentDirectory)
            parentDirectory
          else
            pathToOpen
    loadSettings.initialPaths.sort()

    # Only send to the first non-spec window created
    if @constructor.includeShellLoadTime and not @isSpec
      @constructor.includeShellLoadTime = false
      loadSettings.shellLoadTime ?= Date.now() - global.shellStartTime

    @representedDirectoryPaths = loadSettings.initialPaths
    @env = loadSettings.env if loadSettings.env?

    @browserWindow.loadSettingsJSON = JSON.stringify(loadSettings)

    @browserWindow.on 'window:loaded', =>
      @disableZoom()
      @emit 'window:loaded'
      @resolveLoadedPromise()

    @browserWindow.on 'window:locations-opened', =>
      @emit 'window:locations-opened'

    @browserWindow.on 'enter-full-screen', =>
      @browserWindow.webContents.send('did-enter-full-screen')

    @browserWindow.on 'leave-full-screen', =>
      @browserWindow.webContents.send('did-leave-full-screen')

    @browserWindow.loadURL url.format
      protocol: 'file'
      pathname: "#{@resourcePath}/static/index.html"
      slashes: true

    @browserWindow.showSaveDialog = @showSaveDialog.bind(this)

    @browserWindow.focusOnWebView() if @isSpec
    @browserWindow.temporaryState = {windowDimensions} if windowDimensions?

    hasPathToOpen = not (locationsToOpen.length is 1 and not locationsToOpen[0].pathToOpen?)
    @openLocations(locationsToOpen) if hasPathToOpen and not @isSpecWindow()

    @atomApplication.addWindow(this)

  hasProjectPath: -> @representedDirectoryPaths.length > 0

  setupContextMenu: ->
    ContextMenu = require './context-menu'

    @browserWindow.on 'context-menu', (menuTemplate) =>
      new ContextMenu(menuTemplate, this)

  containsPaths: (paths) ->
    for pathToCheck in paths
      return false unless @containsPath(pathToCheck)
    true

  containsPath: (pathToCheck) ->
    @representedDirectoryPaths.some (projectPath) ->
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
      if @headless
        console.log "Renderer process crashed, exiting"
        @atomApplication.exit(100)
        return

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

  shouldAddCustomTitleBar: ->
    not @isSpec and
    process.platform is 'darwin' and
    @atomApplication.config.get('core.titleBar') is 'custom'

  shouldAddCustomInsetTitleBar: ->
    not @isSpec and
    process.platform is 'darwin' and
    @atomApplication.config.get('core.titleBar') is 'custom-inset'

  shouldHideTitleBar: ->
    not @isSpec and
    process.platform is 'darwin' and
    @atomApplication.config.get('core.titleBar') is 'hidden'

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

  showSaveDialog: (params) ->
    params = Object.assign({
      title: 'Save File',
      defaultPath: @representedDirectoryPaths[0]
    }, params)
    dialog.showSaveDialog(@browserWindow, params)

  toggleDevTools: -> @browserWindow.toggleDevTools()

  openDevTools: -> @browserWindow.openDevTools()

  closeDevTools: -> @browserWindow.closeDevTools()

  setDocumentEdited: (documentEdited) -> @browserWindow.setDocumentEdited(documentEdited)

  setRepresentedFilename: (representedFilename) -> @browserWindow.setRepresentedFilename(representedFilename)

  setRepresentedDirectoryPaths: (@representedDirectoryPaths) ->
    @representedDirectoryPaths.sort()
    @atomApplication.saveState()

  copy: -> @browserWindow.copy()

  disableZoom: ->
    @browserWindow.webContents.setZoomLevelLimits(1, 1)
