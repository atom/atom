BrowserWindow = require 'browser-window'
Menu = require 'menu'
ContextMenu = require './context-menu'
app = require 'app'
dialog = require 'dialog'
ipc = require 'ipc'
path = require 'path'
fs = require 'fs'
url = require 'url'
_ = require 'underscore-plus'

module.exports =
class AtomWindow
  @iconPath: path.resolve(__dirname, '..', '..', 'resources', 'atom.png')
  @includeShellLoadTime: true

  browserWindow: null
  loaded: null
  isSpec: null

  constructor: (settings={}) ->
    {@resourcePath, pathToOpen, initialLine, @isSpec, @exitWhenDone} = settings
    global.atomApplication.addWindow(this)

    @setupNodePath(@resourcePath)
    @browserWindow = new BrowserWindow show: false, title: 'Atom', icon: @constructor.iconPath
    @browserWindow.restart = _.wrap _.bind(@browserWindow.restart, @browserWindow), (restart) =>
      @setupNodePath(@resourcePath)
      restart()

    @handleEvents()

    loadSettings = _.extend({}, settings)
    loadSettings.windowState ?= '{}'
    loadSettings.appVersion = app.getVersion()

    # Only send to the first non-spec window created
    if @constructor.includeShellLoadTime and not @isSpec
      @constructor.includeShellLoadTime = false
      loadSettings.shellLoadTime ?= Date.now() - global.shellStartTime

    loadSettings.initialPath = pathToOpen
    if fs.statSyncNoException(pathToOpen).isFile?()
      loadSettings.initialPath = path.dirname(pathToOpen)

    @browserWindow.loadSettings = loadSettings
    @browserWindow.once 'window:loaded', => @loaded = true
    @browserWindow.loadUrl @getUrl(loadSettings)
    @browserWindow.focusOnWebView() if @isSpec

    @openPath(pathToOpen, initialLine)

  setupNodePath: (resourcePath) ->
    process.env['NODE_PATH'] = path.resolve(resourcePath, 'exports')

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
    @browserWindow.on 'destroyed', =>
      global.atomApplication.removeWindow(this)

    @browserWindow.on 'unresponsive', =>
      return if @isSpec

      chosen = dialog.showMessageBox @browserWindow,
        type: 'warning'
        buttons: ['Close', 'Keep Waiting']
        message: 'Editor is not responding'
        detail: 'The editor is not responding. Would you like to force close it or just keep waiting?'
      @browserWindow.destroy() if chosen is 0

    @browserWindow.on 'crashed', =>
      global.atomApplication.exit(100) if @exitWhenDone

      chosen = dialog.showMessageBox @browserWindow,
        type: 'warning'
        buttons: ['Close Window', 'Reload', 'Keep It Open']
        message: 'The editor has crashed'
        detail: 'Please report this issue to atom@github.com'
      switch chosen
        when 0 then @browserWindow.destroy()
        when 1 then @browserWindow.restart()

    @browserWindow.on 'context-menu', (menuTemplate) =>
      new ContextMenu(menuTemplate, @browserWindow)

    if @isSpec
      # Spec window's web view should always have focus
      @browserWindow.on 'blur', =>
        @browserWindow.focusOnWebView()

  openPath: (pathToOpen, initialLine) ->
    if @loaded
      @focus()
      @sendCommand('window:open-path', {pathToOpen, initialLine})
      @sendCommand('window:update-available', global.atomApplication.getUpdateVersion()) if global.atomApplication.getUpdateVersion()
    else
      @browserWindow.once 'window:loaded', => @openPath(pathToOpen, initialLine)

  sendCommand: (command, args...) ->
    if @isSpecWindow()
      unless @sendCommandToFirstResponder(command)
        switch command
          when 'window:reload' then @reload()
          when 'window:toggle-dev-tools' then @toggleDevTools()
          when 'window:close' then @close()
    else if @isWebViewFocused()
      @sendCommandToBrowserWindow(command, args...)
    else
      unless @sendCommandToFirstResponder(command)
        @sendCommandToBrowserWindow(command, args...)

  sendCommandToBrowserWindow: (command, args...) ->
    action = if args[0]?.contextCommand then 'context-command' else 'command'
    ipc.sendChannel @browserWindow.getProcessId(), @browserWindow.getRoutingId(), action, command, args...

  sendCommandToFirstResponder: (command) ->
    switch command
      when 'core:undo' then Menu.sendActionToFirstResponder('undo:')
      when 'core:redo' then Menu.sendActionToFirstResponder('redo:')
      when 'core:copy' then Menu.sendActionToFirstResponder('copy:')
      when 'core:cut' then Menu.sendActionToFirstResponder('cut:')
      when 'core:paste' then Menu.sendActionToFirstResponder('paste:')
      when 'core:select-all' then Menu.sendActionToFirstResponder('selectAll:')
      else return false
    true

  close: -> @browserWindow.close()

  focus: -> @browserWindow.focus()

  getSize: -> @browserWindow.getSize()

  handlesAtomCommands: ->
    not @isSpecWindow() and @isWebViewFocused()

  isFocused: -> @browserWindow.isFocused()

  isWebViewFocused: -> @browserWindow.isWebViewFocused()

  isSpecWindow: -> @isSpec

  reload: -> @browserWindow.restart()

  toggleDevTools: -> @browserWindow.toggleDevTools()
