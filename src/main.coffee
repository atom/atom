path = require 'path'
optimist = require 'optimist'
delegate = require 'atom_delegate'

resourcePath = null
browserMain = null

setupNodePaths = ->
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
  modifiedArgv = ['node'].concat(process.argv) # optimist assumes the first arg will be node
  args = optimist(modifiedArgv).argv
  resourcePath = args['resource-path'] ? path.dirname(__dirname)

bootstrapApplication = ->
  parseCommandLine()
  setupNodePaths()
  browserMain = new BrowserMain

  new AtomWindow
    bootstrapScript: 'window-bootstrap',
    resourcePath: resourcePath

delegate.browserMainParts.preMainMessageLoopRun = bootstrapApplication

app = require 'app'
BrowserWindow = require 'browser_window'
Menu = require 'menu'
ipc = require 'ipc'
dialog = require 'dialog'

class BrowserMain
  windowState: null
  menu: null

  constructor: ->
    @windowState = {}

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

    viewMenu =
      label: 'View'
      submenu:[
        { label: 'Reload', accelerator: 'Command+R', click: -> BrowserWindow.getFocusedWindow()?.reloadIgnoringCache() }
        { label: 'Toggle DevTools', accelerator: 'Alt+Command+I', click: -> BrowserWindow.getFocusedWindow()?.toggleDevTools() }
      ]

    windowMenu =
      label: 'Window'
      submenu: [
        { label: 'Minimize', accelerator: 'Command+M', selector: 'performMiniaturize:' }
        { label: 'Close', accelerator: 'Command+W', selector: 'performClose:' }
        { type: 'separator' }
        { label: 'Bring All to Front', selector: 'arrangeInFront:' }
      ]

    @menu = Menu.buildFromTemplate [atomMenu, viewMenu, windowMenu]
    Menu.setApplicationMenu @menu

  handleEvents: ->
    # Quit when all windows are closed.
    app.on 'window-all-closed', ->
      app.quit()

    ipc.on 'window-state', (event, processId, messageId, message) =>
      console.log 'browser got request', event, processId, messageId, message if message?
      @windowState = message unless message == undefined
      event.result = @windowState

    ipc.on 'close-without-confirm', (processId, routingId) ->
      window = BrowserWindow.fromProcessIdAndRoutingId processId, routingId
      window.removeAllListeners 'close'
      window.close()

    ipc.on 'open-folder', ->
      currentWindow = BrowserWindow.getFocusedWindow()
      dialog.openFolder currentWindow, {}, (result, paths...) =>
        new AtomWindow
          bootstrapScript: 'window-bootstrap',
          resourcePath: resourcePath

class AtomWindow
  @windows = []

  bootstrapScript: null
  resourcePath: null

  constructor: ({@bootstrapScript, @resourcePath}) ->
    @resourcePath ?= path.dirname(__dirname)
    @window = @open()

    @window.on 'close', (event) =>
      event.preventDefault()
      ipc.sendChannel @window.getProcessId(), @window.getRoutingId(), 'close'

  open: ->
    params = [
      {name: 'bootstrapScript', param: @bootstrapScript},
      {name: 'resourcePath', param: @resourcePath},
    ]

    @openWithParams(params)

  openWithParams: (pairs) ->
    win = new BrowserWindow width: 800, height: 600, show: false, title: 'Atom'

    AtomWindow.windows.push win
    win.on 'destroyed', =>
      AtomWindow.windows.splice AtomWindow.windows.indexOf(win), 1

    url = "file://#{@resourcePath}/static/index.html"
    separator = '?'
    for pair in pairs
      url += "#{separator}#{pair.name}=#{pair.param}"
      separator = '&' if separator is '?'

    win.loadUrl url
    win.show()
    win
