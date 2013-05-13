app = require 'app'
delegate = require 'atom_delegate'
path = require 'path'
Window = require 'window'

# Quit when all windows are closed.
app.on 'window-all-closed', ->
  app.quit()

class AtomWindow
  @windows = []

  constructor: (options) ->
    {@bootstrapScript, @isDev, @isSpec, @exitWhenDone} = options

    if @isDev
      # TODO: read resource-path command parameter
    else
      @resourcePath = path.dirname(__dirname)

    @window = @open()

  open: ->
    params = [
      {name: 'bootstrapScript', param: @bootstrapScript},
      {name: 'resourcePath', param: @resourcePath},
    ]
    params.push {name: 'devMode', param: 1} if @isDev
    params.push {name: 'exitWhenDone', param: 1} if @exitWhenDone

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

    if @isSpec
      resourcePaths = ['benchmark', 'spec'].contat resourcePaths
      resourcePaths.push 'spec/fixtures/packages'

    homeDir = process.env[if process.platform is 'win32' then 'USERPROFILE' else 'HOME']
    resourcePaths.push path.join(homeDir, '.atom', 'packages')

    resourcePaths = resourcePaths.map (relativeOrAbsolutePath) =>
      path.resolve @resourcePath, relativeOrAbsolutePath

    process.env['NODE_PATH'] = resourcePaths.join path.delimiter

  openWithParams: (pairs) ->
    win = new Window width: 800, height: 600, show: false, title: 'Atom'

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

delegate.browserMainParts.preMainMessageLoopRun = ->
  new AtomWindow
    bootstrapScript: 'window-bootstrap',
    isDev: false,
    isSpec: false,
    exitWhenDone: false
