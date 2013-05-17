app = require 'app'
delegate = require 'atom_delegate'
path = require 'path'
BrowserWindow = require 'browser_window'
ipc = require 'ipc'
dialog = require 'dialog'
optimist = require 'optimist'

class BrowserMain
  windowState: null
  commandLineArgs: null

  constructor: ->
    modifiedArgv = ['node'].concat(process.argv) # optimist assumes the first arg will be node
    @commandLineArgs = optimist(modifiedArgv).argv
    @windowState = {}

    @handleEvents()

  handleEvents: ->
    # Quit when all windows are closed.
    app.on 'window-all-closed', ->
      app.quit()

    ipc.on 'window-state', (event, processId, messageId, message) =>
      console.log 'browser got request', event, processId, messageId, message if message?
      @windowState = message unless message == undefined
      event.result = @windowState

    ipc.on 'open-folder', ->
      currentWindow = BrowserWindow.getFocusedWindow()
      dialog.openFolder currentWindow, {}, (result, paths...) =>
        new AtomWindow
          bootstrapScript: 'window-bootstrap',
          resourcePath: @commandLineArgs['resource-path']

class AtomWindow
  @windows = []

  bootstrapScript: null
  resourcePath: null

  constructor: ({@bootstrapScript, @resourcePath}) ->
    @resourcePath ?= path.dirname(__dirname)
    @window = @open()

  open: ->
    params = [
      {name: 'bootstrapScript', param: @bootstrapScript},
      {name: 'resourcePath', param: @resourcePath},
    ]

    @setNodePaths()
    @openWithParams(params)

  setNodePaths: ->
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
      path.resolve @resourcePath, relativeOrAbsolutePath

    process.env['NODE_PATH'] = resourcePaths.join path.delimiter

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


browserMain = new BrowserMain

delegate.browserMainParts.preMainMessageLoopRun = ->
  new AtomWindow
    bootstrapScript: 'window-bootstrap',
    resourcePath: browserMain.commandLineArgs['resource-path']
