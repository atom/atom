module.exports =
class App
  open: (url) ->
    OSX.NSApp.open url

  quit: ->
    OSX.NSApp.terminate null
