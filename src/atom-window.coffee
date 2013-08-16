BrowserWindow = require 'browser-window'
Menu = require 'menu'
MenuItem = require 'menu-item'
app = require 'app'
dialog = require 'dialog'
ipc = require 'ipc'
path = require 'path'
fs = require 'fs'
_ = require 'underscore'

module.exports =
class AtomWindow
  browserWindow: null
  contextMenu: null
  inspectElementMenuItem: null
  loaded: null

  constructor: (settings={}) ->
    {resourcePath, pathToOpen, isSpec} = settings
    global.atomApplication.addWindow(this)

    @setupNodePath(resourcePath)
    @createContextMenu()
    @browserWindow = new BrowserWindow show: false, title: 'Atom'
    @handleEvents(isSpec)

    loadSettings = _.extend({}, settings)
    loadSettings.windowState ?= ''
    loadSettings.initialPath = pathToOpen
    try
      if fs.statSync(pathToOpen).isFile()
        loadSettings.initialPath = path.dirname(pathToOpen)

    @browserWindow.loadSettings = loadSettings
    @browserWindow.once 'window:loaded', => @loaded = true
    @browserWindow.loadUrl "file://#{resourcePath}/static/index.html"

    @openPath(pathToOpen)

  setupNodePath: (resourcePath) ->
    paths = [
      'src'
      'vendor'
      'static'
      'node_modules'
      'spec'
      ''
    ]

    paths.push path.join(app.getHomeDir(), '.atom', 'packages')

    paths = paths.map (relativeOrAbsolutePath) ->
      path.resolve resourcePath, relativeOrAbsolutePath

    process.env['NODE_PATH'] = paths.join path.delimiter

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
    else if pathToCheck.indexOf(path.join(initialPath, path.sep)) is 0
      true
    else
      false

  handleEvents: (isSpec)->
    @browserWindow.on 'destroyed', =>
      global.atomApplication.removeWindow(this)

    @browserWindow.on 'unresponsive', =>
      chosen = dialog.showMessageBox @browserWindow,
        type: 'warning'
        buttons: ['Close', 'Keep Waiting']
        message: 'Editor is not responsing'
        detail: 'The editor is not responding. Would you like to force close it or just keep waiting?'
      @browserWindow.destroy() if chosen is 0

    @browserWindow.on 'crashed', =>
      chosen = dialog.showMessageBox @browserWindow,
        type: 'warning'
        buttons: ['Close Window', 'Reload', 'Keep It Open']
        message: 'The editor has crashed'
        detail: 'Please report this issue to https://github.com/atom/atom/issues'
      switch chosen
        when 0 then @browserWindow.destroy()
        when 1 then @browserWindow.restart()

    @browserWindow.on 'context-menu', (x, y) =>
      @inspectElementMenuItem.click = => @browserWindow.inspectElement(x, y)
      @contextMenu.popup(@browserWindow)

    if isSpec
      # Spec window's web view should always have focus
      @browserWindow.on 'blur', =>
        @browserWindow.focusOnWebView()

  openPath: (pathToOpen) ->
    if @loaded
      @focus()
      @sendCommand('window:open-path', pathToOpen)
    else
      @browserWindow.once 'window:loaded', => @openPath(pathToOpen)

  createContextMenu: ->
    @contextMenu = new Menu
    @inspectElementMenuItem = new MenuItem(label: 'Inspect Element')
    @contextMenu.append(@inspectElementMenuItem)

  sendCommand: (command, args...) ->
    ipc.sendChannel @browserWindow.getProcessId(), @browserWindow.getRoutingId(), 'command', command, args...

  focus: -> @browserWindow.focus()

  isFocused: -> @browserWindow.isFocused()
