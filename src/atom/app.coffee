module.exports =
class App
  open: (url) ->
    OSX.NSApp.open url

  quit: ->
    OSX.NSApp.terminate null

  windows: ->
    controller.jsWindow for controller in OSX.NSApp.controllers
