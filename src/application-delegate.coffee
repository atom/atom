_ = require 'underscore-plus'
ipc = require 'ipc'
remote = require 'remote'
shell = require 'shell'
webFrame = require 'web-frame'
{Disposable} = require 'event-kit'
{getWindowLoadSettings, setWindowLoadSettings} = require './window-load-settings-helpers'

module.exports =
class ApplicationDelegate
  open: (params) ->
    ipc.send('open', params)

  pickFolder: (callback) ->
    responseChannel = "atom-pick-folder-response"
    ipc.on responseChannel, (path) ->
      ipc.removeAllListeners(responseChannel)
      callback(path)
    ipc.send("pick-folder", responseChannel)

  getCurrentWindow: ->
    remote.getCurrentWindow()

  closeWindow: ->
    ipc.send("call-window-method", "close")

  getWindowSize: ->
    [width, height] = remote.getCurrentWindow().getSize()
    {width, height}

  setWindowSize: (width, height) ->
    remote.getCurrentWindow().setSize(width, height)

  getWindowPosition: ->
    [x, y] = remote.getCurrentWindow().getPosition()
    {x, y}

  setWindowPosition: (x, y) ->
    ipc.send("call-window-method", "setPosition", x, y)

  centerWindow: ->
    ipc.send("call-window-method", "center")

  focusWindow: ->
    ipc.send("call-window-method", "focus")

  showWindow: ->
    ipc.send("call-window-method", "show")

  hideWindow: ->
    ipc.send("call-window-method", "hide")

  restartWindow: ->
    ipc.send("call-window-method", "restart")

  isWindowMaximized: ->
    remote.getCurrentWindow().isMaximized()

  maximizeWindow: ->
    ipc.send("call-window-method", "maximize")

  isWindowFullScreen: ->
    remote.getCurrentWindow().isFullScreen()

  setWindowFullScreen: (fullScreen=false) ->
    ipc.send("call-window-method", "setFullScreen", fullScreen)

  openWindowDevTools: ->
    new Promise (resolve) ->
      # Defer DevTools interaction to the next tick, because using them during
      # event handling causes some wrong input events to be triggered on
      # `TextEditorComponent` (Ref.: https://github.com/atom/atom/issues/9697).
      process.nextTick ->
        if remote.getCurrentWindow().isDevToolsOpened()
          resolve()
        else
          remote.getCurrentWindow().once("devtools-opened", -> resolve())
          ipc.send("call-window-method", "openDevTools")

  closeWindowDevTools: ->
    new Promise (resolve) ->
      # Defer DevTools interaction to the next tick, because using them during
      # event handling causes some wrong input events to be triggered on
      # `TextEditorComponent` (Ref.: https://github.com/atom/atom/issues/9697).
      process.nextTick ->
        unless remote.getCurrentWindow().isDevToolsOpened()
          resolve()
        else
          remote.getCurrentWindow().once("devtools-closed", -> resolve())
          ipc.send("call-window-method", "closeDevTools")

  toggleWindowDevTools: ->
    new Promise (resolve) =>
      # Defer DevTools interaction to the next tick, because using them during
      # event handling causes some wrong input events to be triggered on
      # `TextEditorComponent` (Ref.: https://github.com/atom/atom/issues/9697).
      process.nextTick =>
        if remote.getCurrentWindow().isDevToolsOpened()
          @closeWindowDevTools().then(resolve)
        else
          @openWindowDevTools().then(resolve)

  executeJavaScriptInWindowDevTools: (code) ->
    ipc.send("call-window-method", "executeJavaScriptInDevTools", code)

  setWindowDocumentEdited: (edited) ->
    ipc.send("call-window-method", "setDocumentEdited", edited)

  setRepresentedFilename: (filename) ->
    ipc.send("call-window-method", "setRepresentedFilename", filename)

  addRecentDocument: (filename) ->
    ipc.send("add-recent-document", filename)

  setRepresentedDirectoryPaths: (paths) ->
    loadSettings = getWindowLoadSettings()
    loadSettings['initialPaths'] = paths
    setWindowLoadSettings(loadSettings)

  setAutoHideWindowMenuBar: (autoHide) ->
    ipc.send("call-window-method", "setAutoHideMenuBar", autoHide)

  setWindowMenuBarVisibility: (visible) ->
    remote.getCurrentWindow().setMenuBarVisibility(visible)

  getPrimaryDisplayWorkAreaSize: ->
    screen = remote.require 'screen'
    screen.getPrimaryDisplay().workAreaSize

  confirm: ({message, detailedMessage, buttons}) ->
    buttons ?= {}
    if _.isArray(buttons)
      buttonLabels = buttons
    else
      buttonLabels = Object.keys(buttons)

    dialog = remote.require('dialog')
    chosen = dialog.showMessageBox(remote.getCurrentWindow(), {
      type: 'info'
      message: message
      detail: detailedMessage
      buttons: buttonLabels
    })

    if _.isArray(buttons)
      chosen
    else
      callback = buttons[buttonLabels[chosen]]
      callback?()

  showMessageDialog: (params) ->

  showSaveDialog: (params) ->
    if _.isString(params)
      params = defaultPath: params
    else
      params = _.clone(params)
    params.title ?= 'Save File'
    params.defaultPath ?= getWindowLoadSettings().initialPaths[0]
    dialog = remote.require('dialog')
    dialog.showSaveDialog remote.getCurrentWindow(), params

  playBeepSound: ->
    shell.beep()

  onDidOpenLocations: (callback) ->
    outerCallback = (message, detail) ->
      if message is 'open-locations'
        callback(detail)

    ipc.on('message', outerCallback)
    new Disposable ->
      ipc.removeListener('message', outerCallback)

  onUpdateAvailable: (callback) ->
    outerCallback = (message, detail) ->
      if message is 'update-available'
        callback(detail)

    ipc.on('message', outerCallback)
    new Disposable ->
      ipc.removeListener('message', outerCallback)

  onApplicationMenuCommand: (callback) ->
    ipc.on('command', callback)
    new Disposable ->
      ipc.removeListener('command', callback)

  onContextMenuCommand: (callback) ->
    ipc.on('context-command', callback)
    new Disposable ->
      ipc.removeListener('context-command', callback)

  didCancelWindowUnload: ->
    ipc.send('did-cancel-window-unload')

  openExternal: (url) ->
    shell.openExternal(url)

  disablePinchToZoom: ->
    webFrame.setZoomLevelLimits(1, 1)
