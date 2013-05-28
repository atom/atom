AtomWindow = require 'atom-window'
BrowserWindow = require 'browser_window'
Menu = require 'menu'
app = require 'app'
ipc = require 'ipc'
dialog = require 'dialog'
fs = require 'fs'
path = require 'path'
net = require 'net'

atomApplication = null

module.exports =
class AtomApplication
  @addWindow: (window) -> atomApplication.addWindow(window)
  @removeWindow: (window) -> atomApplication.removeWindow(window)

  windows: null
  configWindow: null
  menu: null
  resourcePath: null
  executedFrom: null
  pathsToOpen: null
  testMode: null
  version: null
  socketPath: '/tmp/atom.sock'

  constructor: ({@resourcePath, @executedFrom, @pathsToOpen, @testMode, @version}) ->
    @pathsToOpen ?= [@executedFrom] if @executedFrom
    @executedFrom ?= process.cwd()
    atomApplication = this
    @windows = []

    @sendArgumentsToExistingProcess (success) =>
      process.exit(1) if success # An Atom already exists, kill this process
      @listenForArgumentsFromNewProcess()
      @setupNodePath()
      @setupJavaScriptArguments()
      @buildApplicationMenu()
      @handleEvents()

      if @testMode
        @runSpecs(true)
      else
        @open(@pathsToOpen)

  removeWindow: (window) ->
    @windows.splice @windows.indexOf(window), 1

  addWindow: (window) ->
    @windows.push window

  getHomeDir: ->
    process.env[if process.platform is 'win32' then 'USERPROFILE' else 'HOME']

  setupNodePath: ->
    resourcePaths = [
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

    resourcePaths.push path.join(@getHomeDir(), '.atom', 'packages')

    resourcePaths = resourcePaths.map (relativeOrAbsolutePath) =>
      path.resolve @resourcePath, relativeOrAbsolutePath

    process.env['NODE_PATH'] = resourcePaths.join path.delimiter

  sendArgumentsToExistingProcess: (callback) ->
    client = net.connect {path: @socketPath}, (args...) =>
      pathsToOpen = (@pathsToOpen ? []).map (pathToOpen) =>
        path.resolve(@executedFrom, pathToOpen)
      output = JSON.stringify({pathsToOpen})
      client.write(output)
      callback(true)

    client.on 'error', (args...) -> callback(false)

  listenForArgumentsFromNewProcess: ->
    fs.unlinkSync @socketPath if fs.existsSync(@socketPath)
    server = net.createServer (connection) =>
      connection.on 'data', (data) =>
        {pathsToOpen} = JSON.parse(data)
        @open(pathsToOpen)

    server.listen @socketPath
    server.on 'error', (error) -> console.error 'Application server failed', error

  setupJavaScriptArguments: ->
    app.commandLine.appendSwitch 'js-flags', '--harmony_collections'

  buildApplicationMenu: ->
    atomMenu =
      label: 'Atom'
      submenu: [
        { label: 'About Atom', selector: 'orderFrontStandardAboutPanel:' }
        { label: "Version #{@version}", enabled: false }
        { type: 'separator' }
        { label: 'Preferences...', accelerator: 'Command+,', click: => @openConfig() }
        { type: 'separator' }
        { label: 'Hide Atom Shell', accelerator: 'Command+H', selector: 'hide:' }
        { label: 'Hide Others', accelerator: 'Command+Shift+H', selector: 'hideOtherApplications:' }
        { label: 'Show All', selector: 'unhideAllApplications:' }
        { type: 'separator' }
        { label: 'Run Specs', accelerator: 'Command+MacCtrl+Alt+S', click: => @runSpecs() }
        { type: 'separator' }
        { label: 'Quit', accelerator: 'Command+Q', click: -> app.quit() }
      ]

    editMenu =
      label: 'Edit'
      submenu:[
        { label: 'Undo', accelerator: 'Command+Z', selector: 'undo:' }
        { label: 'Redo', accelerator: 'Command+Shift+Z', selector: 'redo:' }
        { type: 'separator' }
        { label: 'Cut', accelerator: 'Command+X', selector: 'cut:' }
        { label: 'Copy', accelerator: 'Command+C', selector: 'copy:' }
        { label: 'Paste', accelerator: 'Command+V', selector: 'paste:' }
        { label: 'Select All', accelerator: 'Command+A', selector: 'selectAll:' }
      ]

    viewMenu =
      label: 'View'
      submenu:[
        { label: 'Reload', accelerator: 'Command+R', click: => BrowserWindow.getFocusedWindow()?.reloadIgnoringCache() }
        { label: 'Toggle DevTools', accelerator: 'Alt+Command+I', click: => BrowserWindow.getFocusedWindow()?.toggleDevTools() }
      ]

    windowMenu =
      label: 'Window'
      submenu: [
        { label: 'Minimize', accelerator: 'Command+M', selector: 'performMiniaturize:' }
        { label: 'Close', accelerator: 'Command+W', selector: 'performClose:' }
        { type: 'separator' }
        { label: 'Bring All to Front', selector: 'arrangeInFront:' }
      ]

    @menu = Menu.buildFromTemplate [atomMenu, viewMenu, editMenu, windowMenu]
    Menu.setApplicationMenu @menu

  handleEvents: ->
    # Quit when all windows are closed.
    app.on 'window-all-closed', ->
      app.quit()

    ipc.on 'close-without-confirm', (processId, routingId) ->
      window = BrowserWindow.fromProcessIdAndRoutingId processId, routingId
      window.removeAllListeners 'close'
      window.close()

    ipc.on 'open-config', =>
      @openConfig()

    ipc.on 'open', (processId, routingId, pathsToOpen) =>
      if pathsToOpen?.length > 0
        @open(pathsToOpen)
      else
        pathsToOpen = dialog.showOpenDialog title: 'Open', properties: ['openFile', 'openDirectory', 'multiSelections', 'createDirectory']
        @open(pathsToOpen) if pathsToOpen?

    ipc.on 'new-window', =>
      @open()

    ipc.on 'get-version', (event) =>
      event.result = @version

  sendCommand: (command) ->
    atomWindow.sendCommand command for atomWindow in @windows when atomWindow.browserWindow.isFocused()

  open: (pathsToOpen) ->
    pathsToOpen ?= [null]
    for pathToOpen in pathsToOpen
      pathToOpen = path.resolve(@executedFrom, pathToOpen) if @executedFrom and pathToOpen
      if pathToOpen
        for atomWindow in @windows
          if pathToOpen is atomWindow.pathToOpen
            atomWindow.browserWindow.focus()
            return

      atomWindow = new AtomWindow
        pathToOpen: pathToOpen
        bootstrapScript: 'window-bootstrap'
        resourcePath: @resourcePath

  openConfig: ->
    if @configWindow
      @configWindow.browserWindow.focus()
      return

    @configWindow = new AtomWindow
      bootstrapScript: 'config-bootstrap'
      resourcePath: @resourcePath
    @configWindow.browserWindow.on 'destroyed', =>
      @configWindow = null

  runSpecs: (exitWhenDone) ->
    specWindow = new AtomWindow
      bootstrapScript: 'spec-bootstrap'
      resourcePath: @resourcePath
      exitWhenDone: exitWhenDone
      isSpec: true

    specWindow.browserWindow.show()
