app = require 'app'
delegate = require 'atom_delegate'
path = require 'path'
Window = require 'window'

# All opened windows.
windows = []

# Quit when all windows are closed.
app.on 'window-all-closed', ->
  app.quit()

delegate.browserMainParts.preMainMessageLoopRun = ->
  win = new Window width: 800, height: 600, show: false
  win.loadUrl "file://#{__dirname}/../static/index.html"

  win.on 'destroyed', ->
    windows.splice windows.indexOf(win), 1

  windows.push win
  win.show()
