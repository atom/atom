BrowserWindow = require 'browser-window'
app = require 'app'
dialog = require 'dialog'
ipc = require 'ipc'
path = require 'path'
fs = require 'fs'

module.exports =
class AtomWindow
  browserWindow: null

  constructor: ({bootstrapScript, resourcePath, pathToOpen, exitWhenDone, @isSpec}) ->
    global.atomApplication.addWindow(this)

    @setupNodePath(resourcePath)
    @browserWindow = new BrowserWindow show: false, title: 'Atom'
    @handleEvents()

    initialPath = pathToOpen
    try
      initialPath = path.dirname(pathToOpen) if fs.statSync(pathToOpen).isFile()

    @browserWindow.loadSettings = {initialPath, bootstrapScript, resourcePath, exitWhenDone}
    @browserWindow.once 'window:loaded', => @loaded = true
    @browserWindow.loadUrl "file://#{resourcePath}/static/index.html"

    @openPath(pathToOpen)

  setupNodePath: (resourcePath) ->
    paths = [
      'src/stdlib'
      'src/app'
      'src/packages'
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

  handleEvents: ->
    @browserWindow.on 'destroyed', =>
      global.atomApplication.removeWindow(this)

    @browserWindow.on 'unresponsive', =>
      chosen = dialog.showMessageBox @browserWindow,
        type: 'warning'
        buttons: ['Close', 'Keep Waiting']
        message: 'Editor is not responsing'
        detail: 'The editor is not responding. Would you like to force close it or just keep waiting?'
      if chosen is 0
        setImmediate => @browserWindow.destroy()

    @browserWindow.on 'crashed', =>
      chosen = dialog.showMessageBox @browserWindow,
        type: 'warning'
        buttons: ['Close Window', 'Reload', 'Keep It Open']
        message: 'The editor has crashed'
        detail: 'Please report this issue to https://github.com/github/atom/issues'
      switch chosen
        when 0 then setImmediate => @browserWindow.destroy()
        when 1 then @browserWindow.restart()

    if @isSpec
      # Spec window's web view should always have focus
      @browserWindow.on 'blur', =>
        @browserWindow.focusOnWebView()
    else
      @browserWindow.on 'close', (event) =>
        unless @browserWindow.isCrashed()
          event.preventDefault()
          @sendCommand 'window:close'

  openPath: (pathToOpen) ->
    if @loaded
      @focus()
      @sendCommand('window:open-path', pathToOpen)
    else
      @browserWindow.once 'window:loaded', => @openPath(pathToOpen)

  sendCommand: (command, args...) ->
    ipc.sendChannel @browserWindow.getProcessId(), @browserWindow.getRoutingId(), 'command', command, args...

  focus: -> @browserWindow.focus()

  isFocused: -> @browserWindow.isFocused()
