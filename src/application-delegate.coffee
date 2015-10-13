remote = require 'remote'
shell = require 'shell'

module.exports =
class ApplicationDelegate
  open: (params) ->
    ipc.send('open', params)

  pickFolder: ->
    responseChannel = "atom-pick-folder-response"
    ipc.on responseChannel, (path) ->
      ipc.removeAllListeners(responseChannel)
      callback(path)
    ipc.send("pick-folder", responseChannel)

  getCurrentWindow: ->
    remote.getCurrentWindow()

  closeWindow: ->
    remote.getCurrentWindow().close()

  getWindowSize: ->
    [width, height] = remote.getCurrentWindow().getSize()
    {width, height}

  setWindowSize: (width, height) ->
    remote.getCurrentWindow().setSize(width, height)

  getWindowPosition: ->
    [x, y] = remote.getCurrentWindow().getPosition()
    {x, y}

  setWindowPosition: (x, y) ->
    remote.getCurrentWindow().setPosition(x, y)

  centerWindow: ->
    remote.getCurrentWindow().center()

  focusWindow: ->
    remote.getCurrentWindow().focus()

  showWindow: ->
    remote.getCurrentWindow().show()

  hideWindow: ->
    remote.getCurrentWindow().hide()

  restartWindow: ->
    remote.getCurrentWindow().restart()

  isWindowMaximized: ->
    remote.getCurrentWindow().isMaximized()

  maximizeWindow: ->
    remote.getCurrentWindow().maximize()

  isWindowFullScreen: ->
    remote.getCurrentWindow().isFullScreen()

  setWindowFullScreen: (fullScreen=false) ->
    remote.getCurrentWindow().setFullScreen(fullScreen)

  openWindowDevTools: ->
    remote.getCurrentWindow().openDevTools()

  toggleWindowDevTools: ->
    remote.getCurrentWindow().toggleDevTools()

  executeJavaScriptInWindowDevTools: (code) ->
    remote.getCurrentWindow().executeJavaScriptInDevTools(code)

  setWindowDocumentEdited: (edited) ->
    remote.getCurrentWindow().setDocumentEdited(edited)

  setRepresentedFilename: (filename) ->
    remote.getCurrentWindow().setRepresentedFilename(filename)

  setAutoHideWindowMenuBar: (autoHide) ->
    remote.getCurrentWindow().setAutoHideMenuBar(autoHide)

  setWindowMenuBarVisibility: (visible) ->
    remote.getCurrentWindow().setMenuBarVisibility(visible)

  getPrimaryDisplayWorkAreaSize: ->
    screen = remote.require 'screen'
    screen.getPrimaryDisplay().workAreaSize

  showMessageDialog: (params) ->
    dialog = remote.require('dialog')
    dialog.showMessageBox remote.getCurrentWindow(), params

  showSaveDialog: (params) ->
    dialog = remote.require('dialog')
    dialog.showSaveDialog remote.getCurrentWindow(), params

  playBeepSound: ->
    shell.beep()
