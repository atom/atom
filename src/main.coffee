app = require 'app'
delegate = require 'atom_delegate'
path = require 'path'
Window = require 'window'

resourcePath = path.dirname(__dirname)

# All opened windows.
windows = []

# Quit when all windows are closed.
app.on 'window-all-closed', ->
  app.quit()

openWindowWithParams = (pairs) ->
  win = new Window width: 800, height: 600, show: false, title: 'Atom'

  windows.push win
  win.on 'destroyed', ->
    windows.splice windows.indexOf(win), 1

  url = "file://#{resourcePath}/static/index.html"
  separator = '?'
  for pair in pairs
    url += "#{separator}#{pair.name}=#{pair.param}"
    separator = '&' if separator is '?'

  win.loadUrl url
  win.show()

delegate.browserMainParts.preMainMessageLoopRun = ->
  openWindowWithParams [
    {name: 'bootstrapScript', param: 'window-bootstrap'},
    {name: 'resourcePath', param: resourcePath},
  ]
