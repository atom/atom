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

  constructor: ({@resourcePath, pathsToOpen, @version, test, pidToKillWhenClosed, @dev, newWindow}) ->
    global.atomApplication = this

    @pidsToOpenWindows = {}
    @pathsToOpen ?= []
    @windows = []

    @listenForArgumentsFromNewProcess()
    @setupJavaScriptArguments()
    @buildApplicationMenu()
    @handleEvents()

    # Don't check for updates if it's a custom build.
    if @version.indexOf('.') isnt -1
      @checkForUpdates()

    if test
      @runSpecs(true, @resourcePath)
    else if pathsToOpen.length > 0
      @openPaths(pathsToOpen, pidToKillWhenClosed, newWindow)
    else
      # Always open a editor window if this is the first instance of Atom.
      @openPath(null, pidToKillWhenClosed, newWindow)

  removeWindow: (window) ->
    @windows.splice @windows.indexOf(window), 1

  addWindow: (window) ->
    @windows.push window

  listenForArgumentsFromNewProcess: ->
    fs.unlinkSync socketPath if fs.existsSync(socketPath)
    server = net.createServer (connection) =>
      connection.on 'data', (data) =>
        {pathsToOpen, pidToKillWhenClosed, newWindow} = JSON.parse(data)
        @openPaths(pathsToOpen, pidToKillWhenClosed, newWindow)

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
        {
          label: 'Run Specs'
          accelerator: 'Command+MacCtrl+Alt+S'
          click: =>
            @runSpecs(false, path.join(app.getHomeDir(), 'github', 'atom'))
        }
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
        label: '\uD83D\uDC80' # Skull emoji
        submenu: [ { label: 'In Development Mode', enabled: false } ]

    menus.push
      label: 'File'
      submenu: [
        { label: 'Open...', accelerator: 'Command+O', click: => @promptForPath() }
      ]

    menus.push
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

    menus.push
      label: 'View'
      submenu:[
        { label: 'Reload', accelerator: 'Command+R', click: => BrowserWindow.getFocusedWindow()?.restart() }
        { label: 'Toggle Full Screen', accelerator: 'Command+MacCtrl+F', click: => BrowserWindow.getFocusedWindow()?.setFullScreen(!BrowserWindow.getFocusedWindow().isFullScreen()) }
        { label: 'Toggle Developer Tools', accelerator: 'Alt+Command+I', click: => BrowserWindow.getFocusedWindow()?.toggleDevTools() }
      ]

    menus.push
      label: 'Window'
      submenu: [
        { label: 'Minimize', accelerator: 'Command+M', selector: 'performMiniaturize:' }
        { label: 'Zoom', accelerator: 'Alt+Command+MacCtrl+M', selector: 'zoom:' }
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
      @openPath(null)

    ipc.on 'install-update', =>
      @installUpdate?()

    ipc.on 'get-version', (event) =>
      event.result = @version

  sendCommand: (command, args...) ->
    for atomWindow in @windows when atomWindow.isFocused()
      atomWindow.sendCommand(command, args...)

  windowForPath: (pathToOpen) ->
    for atomWindow in @windows
      return atomWindow if atomWindow.containsPath(pathToOpen)

  openPaths: (pathsToOpen=[], pidToKillWhenClosed, newWindow) ->
    @openPath(pathToOpen, pidToKillWhenClosed, newWindow) for pathToOpen in pathsToOpen

  openPath: (pathToOpen, pidToKillWhenClosed, newWindow) ->
    existingWindow = @windowForPath(pathToOpen) unless pidToKillWhenClosed or newWindow
    if existingWindow
      openedWindow = existingWindow
      openedWindow.openPath(pathToOpen)
    else
      bootstrapScript = 'window-bootstrap'
      openedWindow = new AtomWindow({pathToOpen, bootstrapScript, @resourcePath})

    if pidToKillWhenClosed?
      @pidsToOpenWindows[pidToKillWhenClosed] = openedWindow

    openedWindow.browserWindow.on 'destroyed', =>
      for pid, trackedWindow of @pidsToOpenWindows when trackedWindow is openedWindow
        try
          process.kill(pid)
        catch error
          if error.code isnt 'ESRCH'
            console.log("Killing process #{pid} failed: #{error.code}")
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

  runSpecs: (exitWhenDone, resourcePath) ->
    if resourcePath isnt @resourcePath and not fs.existsSync(resourcePath)
      resourcePath = @resourcePath

    bootstrapScript = 'spec-bootstrap'
    isSpec = true
    new AtomWindow({bootstrapScript, resourcePath, exitWhenDone, isSpec})

  promptForPath: ->
    pathsToOpen = dialog.showOpenDialog title: 'Open', properties: ['openFile', 'openDirectory', 'multiSelections', 'createDirectory']
    @openPaths(pathsToOpen)
