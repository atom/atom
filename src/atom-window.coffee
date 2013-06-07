BrowserWindow = require 'browser-window'
dialog = require 'dialog'
ipc = require 'ipc'

module.exports =
class AtomWindow
  browserWindow: null

  constructor: ({bootstrapScript, resourcePath, @pathToOpen, exitWhenDone, @isSpec}) ->
    global.atomApplication.addWindow(this)

    @browserWindow = new BrowserWindow show: false, title: 'Atom'
    @handleEvents()

    url = "file://#{resourcePath}/static/index.html#"
    url += "bootstrapScript=#{encodeURIComponent(bootstrapScript)}"
    url += "&resourcePath=#{encodeURIComponent(resourcePath)}"
    url += "&pathToOpen=#{encodeURIComponent(@pathToOpen)}" if @pathToOpen
    url += '&exitWhenDone=1' if exitWhenDone

    @browserWindow.loadUrl url

  handleEvents: ->
    @browserWindow.on 'destroyed', =>
      global.atomApplication.removeWindow(this)

    @browserWindow.on 'unresponsive', =>
      chosen = dialog.showMessageBox @browserWindow,
        type: 'warning'
        buttons: ['Close', 'Keep Waiting']
        message: 'Editor window is frozen'
        detail: "The editor window becomes frozen because of JavaScript dead loop, you can force closing it or just keep waiting."
      @browserWindow.destroy() if chosen is 0

    if @isSpec
      # Spec window's web view should always have focus
      @browserWindow.on 'blur', =>
        @browserWindow.focusOnWebView()
    else
      @browserWindow.on 'close', (event) =>
        event.preventDefault()
        @sendCommand 'window:close'

  sendCommand: (command, args...) ->
    ipc.sendChannel @browserWindow.getProcessId(), @browserWindow.getRoutingId(), 'command', command, args...

  focus: -> @browserWindow.focus()

  isFocused: -> @browserWindow.isFocused()
