net = require 'net'
fs = require 'fs'
path = require 'path'
optimist = require 'optimist'
delegate = require 'atom_delegate'

resourcePath = null
executedFrom = null
pathsToOpen = null
atomApplication = null

getHomeDir = ->
  process.env[if process.platform is 'win32' then 'USERPROFILE' else 'HOME']

setupNodePath = ->
  resourcePaths = [
    'src/stdlib',
    'src/app',
    'src/packages',
    'src',
    'vendor',
    'static',
    'node_modules',
    'spec',
    '',
  ]

  resourcePaths.push path.join(getHomeDir(), '.atom', 'packages')

  resourcePaths = resourcePaths.map (relativeOrAbsolutePath) =>
    path.resolve resourcePath, relativeOrAbsolutePath

  process.env['NODE_PATH'] = resourcePaths.join path.delimiter

parseCommandLine = ->
  args = optimist(process.argv[1..]).argv
  executedFrom = args['executed-from'] ? process.cwd()
  pathsToOpen = args._

  if args['resource-path']
    resourcePath = args['resource-path']
  else if args['dev']
    resourcePath = path.join(getHomeDir(), 'github/atom')

  try
    fs.statSync resourcePath
  catch e
    resourcePath = path.dirname(__dirname)

bootstrapApplication = ->
  setupNodePath()
  atomApplication = new AtomApplication({resourcePath, executedFrom})
  atomApplication.open(pathsToOpen)

delegate.browserMainParts.preMainMessageLoopRun = ->
  client = null
  socketPath = '/tmp/atom.sock'

  parseCommandLine()

  connect = (callback) ->
    client = net.connect {path: socketPath}, (args...) ->
      output = JSON.stringify({pathsToOpen: pathsToOpen})
      client.write(output)
      callback(true)

    client.on 'error', (args...) ->
      console.log 'error', args
      callback(false)

  listen = ->
    fs.unlinkSync socketPath if fs.existsSync(socketPath)
    server = net.createServer (connection) ->
      connection.on 'data', (data) ->
        { pathsToOpen } = JSON.parse(data)
        atomApplication.open(pathsToOpen)

    server.listen socketPath
    server.on 'error', (error) -> console.error 'Application server failed', error

  connect (success) ->
    if success
      process.exit(1)
    else
      listen()
      bootstrapApplication()

BrowserWindow = require 'browser_window'
Menu = require 'menu'
app = require 'app'
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

    ipc.on 'open-folder', =>
      currentWindow = BrowserWindow.getFocusedWindow()
      pathsToOpen = dialog.showOpenDialog title: 'Open', properties: ['openFile', 'openDirectory', 'multiSelections', 'createDirectory']
      @open(pathToOpen) for pathToOpen in pathsToOpen if pathsToOpen?

    ipc.on 'new-window', =>
      @open()

  sendCommand: (command) ->
    atomWindow.sendCommand command for atomWindow in @windows when atomWindow.browserWindow.isFocused()

  open: (pathsToOpen) ->
    pathsToOpen = [null] if pathsToOpen.length == 0
    for pathToOpen in pathsToOpen
      pathToOpen = path.resolve(executedFrom, pathToOpen) if executedFrom and pathToOpen

      atomWindow = new AtomWindow
        pathToOpen: pathToOpen
        bootstrapScript: 'window-bootstrap',
        resourcePath: @resourcePath

      @windows.push atomWindow

  runSpecs: ->
    specWindow = new AtomWindow
      bootstrapScript: 'spec-bootstrap',
      resourcePath: @resourcePath
      isSpec: true

    specWindow.browserWindow.show()
    @windows.push specWindow

class AtomWindow
  browserWindow: null

  constructor: ({bootstrapScript, resourcePath, pathToOpen, @isSpec}) ->
    @browserWindow = new BrowserWindow show: false, title: 'Atom'
    @handleEvents()

    url = "file://#{resourcePath}/static/index.html?bootstrapScript=#{bootstrapScript}&resourcePath=#{resourcePath}"
    url += "&pathToOpen=#{pathToOpen}" if pathToOpen

    @browserWindow.loadUrl url

  handleEvents: ->
    @browserWindow.on 'destroyed', =>
      atomApplication.windows.splice atomApplication.windows.indexOf(this), 1

    if @isSpec
      # Spec window's web view should always have focus
      @browserWindow.on 'blur', =>
        @browserWindow.focusOnWebView()
    else
      @browserWindow.on 'close', (event) =>
        event.preventDefault()
        @sendCommand 'window:close'

  sendCommand: (command) ->
    ipc.sendChannel @browserWindow.getProcessId(), @browserWindow.getRoutingId(), 'command', command
