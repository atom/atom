module.exports =
class App
  open: (path) ->
    OSX.NSApp.open path

  quit: ->
    OSX.NSApp.terminate null
