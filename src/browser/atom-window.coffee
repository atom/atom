BrowserWindow = require 'browser-window'
ContextMenu = require './context-menu'
app = require 'app'
dialog = require 'dialog'
path = require 'path'
fs = require 'fs'
url = require 'url'
_ = require 'underscore-plus'
{EventEmitter} = require 'events'

module.exports =
class AtomWindow
  _.extend @prototype, EventEmitter.prototype

  @iconPath: path.resolve(__dirname, '..', '..', 'resources', 'atom.png')
  @includeShellLoadTime: true

  browserWindow: null
  loaded: null
  isSpec: null

  constructor: (settings={}) ->
    {@resourcePath, pathToOpen, initialLine, initialColumn, @isSpec, @exitWhenDone, @safeMode} = settings

    # Normalize to make sure drive letter case is consistent on Windows
    @resourcePath = path.normalize(@resourcePath) if @resourcePath

    @browserWindow = new BrowserWindow show: false, title: 'Atom', icon: @constructor.iconPath
    global.atomApplication.addWindow(this)

    @handleEvents()

    loadSettings = _.extend({}, settings)
    loadSettings.windowState ?= '{}'
    loadSettings.appVersion = app.getVersion()
    loadSettings.resourcePath = @resourcePath

    # Only send to the first non-spec window created
    if @constructor.includeShellLoadTime and not @isSpec
      @constructor.includeShellLoadTime = false
      loadSettings.shellLoadTime ?= Date.now() - global.shellStartTime

    loadSettings.initialPath = pathToOpen
    if fs.statSyncNoException(pathToOpen).isFile?()
      loadSettings.initialPath = path.dirname(pathToOpen)

    @browserWindow.loadSettings = loadSettings
    @browserWindow.once 'window:loaded', =>
      @emit 'window:loaded'
      @loaded = true

    @browserWindow.on 'project-path-changed', (@projectPath) =>

    @browserWindow.loadUrl @getUrl(loadSettings)
    @browserWindow.focusOnWebView() if @isSpec

    @openPath(pathToOpen, initialLine, initialColumn)

  getUrl: (loadSettingsObj) ->
    # Ignore the windowState when passing loadSettings via URL, since it could
    # be quite large.
    loadSettings = _.clone(loadSettingsObj)
    delete loadSettings['windowState']

    url.format
      protocol: 'file'
      pathname: "#{@resourcePath}/static/index.html"
      slashes: true
      query: {loadSettings: JSON.stringify(loadSettings)}

  hasProjectPath: -> @projectPath?.length > 0

  getInitialPath: ->
    @browserWindow.loadSettings.initialPath

  containsPath: (pathToCheck) ->
    initialPath = @getInitialPath()
    if not initialPath
      false
    else if not pathToCheck
      false
    else if pathToCheck is initialPath
      true
    else if fs.statSyncNoException(pathToCheck).isDirectory?()
      false
    else if pathToCheck.indexOf(path.join(initialPath, path.sep)) is 0
      true
    else
      false

  handleEvents: ->
    @browserWindow.on 'closed', =>
      global.atomApplication.removeWindow(this)

    @browserWindow.on 'unresponsive', =>
      return if @isSpec

      chosen = dialog.showMessageBox @browserWindow,
        type: 'warning'
        buttons: ['Close', 'Keep Waiting']
        message: 'Editor is not responding'
        detail: 'The editor is not responding. Would you like to force close it or just keep waiting?'
      @browserWindow.destroy() if chosen is 0

    @browserWindow.webContents.on 'crashed', =>
      global.atomApplication.exit(100) if @exitWhenDone

      chosen = dialog.showMessageBox @browserWindow,
        type: 'warning'
        buttons: ['Close Window', 'Reload', 'Keep It Open']
        message: 'The editor has crashed'
        detail: 'Please report this issue to https://github.com/atom/atom'
      switch chosen
        when 0 then @browserWindow.destroy()
        when 1 then @browserWindow.restart()

    @browserWindow.on 'context-menu', (menuTemplate) =>
      new ContextMenu(menuTemplate, this)

    if @isSpec
      # Workaround for https://github.com/atom/atom-shell/issues/380
      # Don't focus the window when it is being blurred during close or
      # else the app will crash on Windows.
      if process.platform is 'win32'
        @browserWindow.on 'close', => @isWindowClosing = true

      # Spec window's web view should always have focus
      @browserWindow.on 'blur', =>
        @browserWindow.focusOnWebView() unless @isWindowClosing

  openPath: (pathToOpen, initialLine, initialColumn) ->
    if @loaded
      @focus()
      @sendCommand('window:open-path', {pathToOpen, initialLine, initialColumn})
    else
      @browserWindow.once 'window:loaded', => @openPath(pathToOpen, initialLine, initialColumn)

  sendCommand: (command, args...) ->
    if @isSpecWindow()
      unless global.atomApplication.sendCommandToFirstResponder(command)
        switch command
          when 'window:reload' then @reload()
          when 'window:toggle-dev-tools' then @toggleDevTools()
          when 'window:close' then @close()
          when 'window:update-available' then @sendCommandToBrowserWindow(command, args...) # For spec testing
    else if @isWebViewFocused()
      @sendCommandToBrowserWindow(command, args...)
    else
      unless global.atomApplication.sendCommandToFirstResponder(command)
        @sendCommandToBrowserWindow(command, args...)

  sendCommandToBrowserWindow: (command, args...) ->
    action = if args[0]?.contextCommand then 'context-command' else 'command'
    @browserWindow.webContents.send action, command, args...

  getDimensions: ->
    [x, y] = @browserWindow.getPosition()
    [width, height] = @browserWindow.getSize()
    {x, y, width, height}

  close: -> @browserWindow.close()

  focus: -> @browserWindow.focus()

  minimize: -> @browserWindow.minimize()

  maximize: -> @browserWindow.maximize()

  restore: -> @browserWindow.restore()

  handlesAtomCommands: ->
    not @isSpecWindow() and @isWebViewFocused()

  isFocused: -> @browserWindow.isFocused()

  isMinimized: -> @browserWindow.isMinimized()

  isWebViewFocused: -> @browserWindow.isWebViewFocused()

  isSpecWindow: -> @isSpec

  reload: -> @browserWindow.restart()

  toggleDevTools: -> @browserWindow.toggleDevTools()
