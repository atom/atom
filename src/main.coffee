path = require 'path'
optimist = require 'optimist'
delegate = require 'atom_delegate'

resourcePath = null
executedFrom = null
pathsToOpen = null
atomApplication = null

setupNodePath= ->
  resourcePaths = [
    'src/stdlib',
    'src/app',
    'src/packages',
    'src',
    'vendor',
    'static',
    'node_modules',
  ]

  homeDir = process.env[if process.platform is 'win32' then 'USERPROFILE' else 'HOME']
  resourcePaths.push path.join(homeDir, '.atom', 'packages')

  resourcePaths = resourcePaths.map (relativeOrAbsolutePath) =>
    path.resolve resourcePath, relativeOrAbsolutePath

  process.env['NODE_PATH'] = resourcePaths.join path.delimiter

parseCommandLine = ->
  args = optimist(process.argv[1..]).argv
  resourcePath = args['resource-path'] ? path.dirname(__dirname)
  executedFrom = args['executed-from']
  pathsToOpen = args._

bootstrapApplication = ->
  parseCommandLine()
  setupNodePath()
  atomApplication = new AtomApplication({resourcePath, executedFrom})

  if pathsToOpen.length > 0
    atomApplication.open(pathToOpen) for pathToOpen in pathsToOpen
  else
    atomApplication.open()

delegate.browserMainParts.preMainMessageLoopRun = bootstrapApplication

app = require 'app'
BrowserWindow = require 'browser_window'
Menu = require 'menu'
ipc = require 'ipc'
dialog = require 'dialog'

class AtomApplication
  resourcePath: null
  menu: null
  windows: null

  constructor: ({@resourcePath, @executedFrom}) ->
    @windows = []

    @setupJavaScriptArguments()
    @buildApplicationMenu()
    @handleEvents()

  setupJavaScriptArguments: ->
    app.commandLine.appendSwitch 'js-flags', '--harmony_collections'

  buildApplicationMenu: ->
    atomMenu =
      label: 'Atom'
      submenu: [
        { label: 'About Atom', selector: 'orderFrontStandardAboutPanel:' }
        { type: 'separator' }
        { label: 'Hide Atom Shell', accelerator: 'Command+H', selector: 'hide:' }
        { label: 'Hide Others', accelerator: 'Command+Shift+H', selector: 'hideOtherApplications:' }
        { label: 'Show All', selector: 'unhideAllApplications:' }
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
        { label: 'Reload', accelerator: 'Command+R', click: => @sendCommand 'window:reload' }
        { label: 'Toggle DevTools', accelerator: 'Alt+Command+I', click: => @sendCommand 'toggle-dev-tools' }
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

    ipc.on 'open-folder', =>
      currentWindow = BrowserWindow.getFocusedWindow()
      pathsToOpen = dialog.showOpenDialog title: 'Open', properties: ['openFile', 'openDirectory', 'multiSelections', 'createDirectory']
      @open(pathToOpen) for pathToOpen in pathsToOpen if pathsToOpen?

    ipc.on 'new-window', =>
      @open()

  sendCommand: (command) ->
    atomWindow.sendCommand command for atomWindow in @windows when atomWindow.browserWindow.isFocused()

  open: (pathToOpen) ->
    pathToOpen = path.resolve(executedFrom, pathToOpen) if executedFrom

    atomWindow = new AtomWindow
      pathToOpen: pathToOpen
      bootstrapScript: 'window-bootstrap',
      resourcePath: @resourcePath

    @windows.push atomWindow

class AtomWindow
  browserWindow: null

  constructor: ({bootstrapScript, resourcePath, pathToOpen}) ->
    @browserWindow = new BrowserWindow width: 800, height: 600, show: false, title: 'Atom'
    @handleEvents()

    url = "file://#{resourcePath}/static/index.html?bootstrapScript=#{bootstrapScript}&resourcePath=#{resourcePath}"
    url += "&pathToOpen=#{pathToOpen}" if pathToOpen

    console.log url
    @browserWindow.loadUrl url
    @browserWindow.show()

  handleEvents: ->
    @browserWindow.on 'destroyed', =>
      atomApplication.windows.splice atomApplication.windows.indexOf(this), 1

    @browserWindow.on 'close', (event) =>
      event.preventDefault()
      @sendCommand 'window:close'

  sendCommand: (command) ->
    ipc.sendChannel @browserWindow.getProcessId(), @browserWindow.getRoutingId(), 'command', command
