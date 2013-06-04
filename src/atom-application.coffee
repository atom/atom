AtomWindow = require './atom-window'
BrowserWindow = require 'browser-window'
Menu = require 'menu'
autoUpdater = require 'auto-updater'
app = require 'app'
ipc = require 'ipc'
dialog = require 'dialog'
fs = require 'fs'
path = require 'path'
net = require 'net'

socketPath = '/tmp/atom.sock'

module.exports =
class AtomApplication
  @open: (options) ->
    createAtomApplication = -> new AtomApplication(options)

    # FIXME: Sometimes when socketPath doesn't exist, net.connect would strangely
    # take a few seconds to trigger 'error' event, it could be a bug of node
    # or atom-shell, before it's fixed we check the existence of socketPath to
    # speedup startup.
    if not fs.existsSync socketPath
      createAtomApplication()
      return

    client = net.connect {path: socketPath}, ->
      client.write JSON.stringify(options), ->
        client.end()
        app.terminate()

    client.on 'error', createAtomApplication

  windows: null
  configWindow: null
  menu: null
  resourcePath: null
  installUpdate: null
  version: null

  constructor: ({@resourcePath, pathsToOpen, @version, test, pidToKillWhenClosed, @dev}) ->
    global.atomApplication = this

    @pidsToOpenWindows = {}
    @pathsToOpen ?= []
    @windows = []

    @listenForArgumentsFromNewProcess()
    @setupNodePath()
    @setupJavaScriptArguments()
    @buildApplicationMenu()
    @handleEvents()

    # Don't check for updates if it's a custom build.
    if @version.indexOf('.') isnt -1
      @checkForUpdates()

    if test
      @runSpecs(true)
    else if pathsToOpen.length > 0
      @openPaths(pathsToOpen, pidToKillWhenClosed)
    else
      # Always open a editor window if this is the first instance of Atom.
      @openPath(null)

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

  listenForArgumentsFromNewProcess: ->
    fs.unlinkSync socketPath if fs.existsSync(socketPath)
    server = net.createServer (connection) =>
      connection.on 'data', (data) =>
        {pathsToOpen, pidToKillWhenClosed} = JSON.parse(data)
        @openPaths(pathsToOpen, pidToKillWhenClosed)

    server.listen socketPath
    server.on 'error', (error) -> console.error 'Application server failed', error

  setupJavaScriptArguments: ->
    app.commandLine.appendSwitch 'js-flags', '--harmony_collections'

  checkForUpdates: ->
    autoUpdater.setAutomaticallyChecksForUpdates true
    autoUpdater.checkForUpdatesInBackground()

  buildApplicationMenu: (version, continueUpdate) ->
    menus = []
    menus.push
      label: 'Atom'
      submenu: [
        { label: 'About Atom', selector: 'orderFrontStandardAboutPanel:' }
        { type: 'separator' }
        { label: 'Preferences...', accelerator: 'Command+,', click: => @openConfig() }
        { type: 'separator' }
        { label: 'Hide Atom', accelerator: 'Command+H', selector: 'hide:' }
        { label: 'Hide Others', accelerator: 'Command+Shift+H', selector: 'hideOtherApplications:' }
        { label: 'Show All', selector: 'unhideAllApplications:' }
        { type: 'separator' }
        { label: 'Run Specs', accelerator: 'Command+MacCtrl+Alt+S', click: => @runSpecs() }
        { type: 'separator' }
        { label: 'Quit', accelerator: 'Command+Q', click: -> app.quit() }
      ]

    menus[0].submenu[1..0] =
      if version
        label: "Update to #{version}"
        click: continueUpdate
      else
        label: "Version #{@version}"
        enabled: false

    if @dev
      menus.push
        label: '\uD83D\uDC80'
        submenu: [ { label: 'In Development Mode', enabled: false } ]

    menus.push
      label: 'File'
      submenu: [
        { label: 'Open...', accelerator: 'Command+O', click: => @promptForPath() }
      ]

    menus.push
      label: 'View'
      submenu:[
        { label: 'Reload', accelerator: 'Command+R', click: => BrowserWindow.getFocusedWindow()?.restart() }
        { label: 'Toggle Full Screen', accelerator: 'Command+MacCtrl+F', click: => BrowserWindow.getFocusedWindow()?.setFullscreen(!BrowserWindow.getFocusedWindow().isFullscreen()) }
        { label: 'Toggle Developer Tools', accelerator: 'Alt+Command+I', click: => BrowserWindow.getFocusedWindow()?.toggleDevTools() }
      ]

    menus.push
      label: 'Window'
      submenu: [
        { label: 'Minimize', accelerator: 'Command+M', selector: 'performMiniaturize:' }
        { label: 'Close', accelerator: 'Command+W', selector: 'performClose:' }
        { type: 'separator' }
        { label: 'Bring All to Front', selector: 'arrangeInFront:' }
      ]

    @menu = Menu.buildFromTemplate menus
    Menu.setApplicationMenu @menu

  handleEvents: ->
    # Clean the socket file when quit normally.
    app.on 'will-quit', =>
      fs.unlinkSync socketPath if fs.existsSync(socketPath)

    app.on 'open-file', (event, filePath) =>
      event.preventDefault()
      @openPath filePath

    autoUpdater.on 'ready-for-update-on-quit', (event, version, quitAndUpdate) =>
      event.preventDefault()
      @installUpdate = quitAndUpdate
      @buildApplicationMenu version, quitAndUpdate

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
        @promptForPath()

    ipc.on 'new-window', =>
      @open()

    ipc.on 'install-update', =>
      @installUpdate?()

    ipc.on 'get-version', (event) =>
      event.result = @version

  sendCommand: (command, args...) ->
    for atomWindow in @windows when atomWindow.isFocused()
      atomWindow.sendCommand(command, args...)

  windowForPath: (pathToOpen) ->
    return null unless pathToOpen

    for atomWindow in @windows when atomWindow.pathToOpen?
      if pathToOpen is atomWindow.pathToOpen
        return atomWindow

      if pathToOpen.indexOf(path.join(atomWindow.pathToOpen, path.sep)) is 0
        return atomWindow

    null

  openPaths: (pathsToOpen=[], pidToKillWhenClosed) ->
    @openPath(pathToOpen, pidToKillWhenClosed) for pathToOpen in pathsToOpen

  openPath: (pathToOpen, pidToKillWhenClosed) ->
    existingWindow = @windowForPath(pathToOpen) unless pidToKillWhenClosed
    if existingWindow
      openedWindow = existingWindow
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

  promptForPath: ->
    pathsToOpen = dialog.showOpenDialog title: 'Open', properties: ['openFile', 'openDirectory', 'multiSelections', 'createDirectory']
    @openPaths(pathsToOpen)
