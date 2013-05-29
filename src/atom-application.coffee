AtomWindow = require './atom-window'
BrowserWindow = require 'browser_window'
Menu = require 'menu'
app = require 'app'
ipc = require 'ipc'
dialog = require 'dialog'
fs = require 'fs'
path = require 'path'
net = require 'net'

module.exports =
class AtomApplication
  windows: null
  configWindow: null
  menu: null
  resourcePath: null
  pathsToOpen: null
  version: null
  socketPath: '/tmp/atom.sock'

  constructor: ({@resourcePath, @pathsToOpen, @version, test, pidToKillWhenClosed}) ->
    @pidsToOpenWindows = {}
    @pathsToOpen ?= [null]
    @windows = []

    @sendArgumentsToExistingProcess pidToKillWhenClosed, (success) =>
      process.exit(0) if success # An Atom already exists, kill this process
      @listenForArgumentsFromNewProcess()
      @setupNodePath()
      @setupJavaScriptArguments()
      @buildApplicationMenu()
      @handleEvents()

      if test
        @runSpecs(true)
      else
        @openPaths(@pathsToOpen, pidToKillWhenClosed)

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

  sendArgumentsToExistingProcess: (pidToKillWhenClosed, callback) ->
    client = net.connect {path: @socketPath}, (args...) =>
      client.write(JSON.stringify({@pathsToOpen, pidToKillWhenClosed}))
      callback(true)

    client.on 'error', (args...) -> callback(false)

  listenForArgumentsFromNewProcess: ->
    fs.unlinkSync @socketPath if fs.existsSync(@socketPath)
    server = net.createServer (connection) =>
      connection.on 'data', (data) =>
        {pathsToOpen, pidToKillWhenClosed} = JSON.parse(data)
        @openPaths(pathsToOpen, pidToKillWhenClosed)

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
        { label: 'Reload', accelerator: 'Command+R', click: => BrowserWindow.getFocusedWindow()?.restart() }
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
        @openPaths(pathsToOpen)
      else
        pathsToOpen = dialog.showOpenDialog title: 'Open', properties: ['openFile', 'openDirectory', 'multiSelections', 'createDirectory']
        @openPaths(pathsToOpen)

    ipc.on 'new-window', =>
      @open()

    ipc.on 'get-version', (event) =>
      event.result = @version

  sendCommand: (command, args...) ->
    for atomWindow in @windows when atomWindow.isFocused()
      atomWindow.sendCommand(command, args...)

  windowForPath: (pathToOpen) ->
    return null unless pathToOpen

    for atomWindow in @windows
      if pathToOpen is atomWindow.pathToOpen
        return atomWindow

      if pathToOpen.indexOf(path.join(atomWindow.pathToOpen, path.sep)) is 0
        return atomWindow

    null

  openPaths: (pathsToOpen=[], pidToKillWhenClosed) ->
    @openPath(pathToOpen, pidToKillWhenClosed) for pathToOpen in pathsToOpen

  openPath: (pathToOpen, pidToKillWhenClosed) ->
    if openedWindow = @windowForPath(pathToOpen)
      openedWindow.focus()
      openedWindow.sendCommand('window:open-path', pathToOpen)
    else
      bootstrapScript = 'window-bootstrap'
      openedWindow = new AtomWindow({pathToOpen, bootstrapScript, @resourcePath})

    if pidToKillWhenClosed?
      @pidsToOpenWindows[pidToKillWhenClosed] = openedWindow

    openedWindow.browserWindow.on 'closed', =>
      for pid, trackedWindow of @pidsToOpenWindows when trackedWindow is openedWindow
        process.kill(pid)
        delete @pidsToOpenWindows[pid]

  openConfig: ->
    if @configWindow
      @configWindow.focus()
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

    specWindow.show()
