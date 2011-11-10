module.exports =
class App
  constructor: ->
    atom.keybinder.register "app", this

  open: (path) ->
    OSX.NSApp.open path

  quit: ->
    OSX.NSApp.terminate null
