BrowserWindow = require 'browser-window'
dialog = require 'dialog'
ipc = require 'ipc'
path = require 'path'

module.exports =
class AtomWindow
  browserWindow: null

  constructor: ({bootstrapScript, resourcePath, pathToOpen, exitWhenDone, @isSpec}) ->
    global.atomApplication.addWindow(this)

    @browserWindow = new BrowserWindow show: false, title: 'Atom'
    @handleEvents()

    @browserWindow.loadSettings = {pathToOpen, bootstrapScript, resourcePath, exitWhenDone}
    @browserWindow.loadUrl "file://#{resourcePath}/static/index.html"

  getPathToOpen: ->
    @browserWindow.loadSettings.pathToOpen

  containsPath: (pathToCheck) ->
    if not pathToCheck
      false
    else if pathToCheck is @getPathToOpen()
      true
    else if pathToCheck.indexOf(path.join(@getPathToOpen(), path.sep)) is 0
      true
    else
      false

  handleEvents: ->
    @browserWindow.on 'destroyed', =>
      global.atomApplication.removeWindow(this)

    @browserWindow.on 'unresponsive', =>
      chosen = dialog.showMessageBox @browserWindow,
        type: 'warning'
        buttons: ['Close', 'Keep Waiting']
        message: 'Editor window is frozen'
        detail: 'The editor window becomes frozen because of JavaScript dead loop, you can force closing it or just keep waiting.'
      if chosen is 0
        setImmediate => @browserWindow.destroy()

    @browserWindow.on 'crashed', =>
      chosen = dialog.showMessageBox @browserWindow,
        type: 'warning'
        buttons: ['Close Window', 'Reload', 'Keep It Open']
        message: 'Renderer is crashed'
        detail: "The renderer process has crashed, a crash report would be generated and you can report it to Atom's github page"
      switch chosen
        when 0 then setImmediate => @browserWindow.destroy()
        when 1 then @browserWindow.restart()

    if @isSpec
      # Spec window's web view should always have focus
      @browserWindow.on 'blur', =>
        @browserWindow.focusOnWebView()
    else
      @browserWindow.on 'close', (event) =>
        unless @browserWindow.isCrashed()
          event.preventDefault()
          @sendCommand 'window:close'

  sendCommand: (command, args...) ->
    ipc.sendChannel @browserWindow.getProcessId(), @browserWindow.getRoutingId(), 'command', command, args...

  focus: -> @browserWindow.focus()

  isFocused: -> @browserWindow.isFocused()
