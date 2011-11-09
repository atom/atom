fs = require 'fs'
require 'window'

module.exports =
class App
  constructor: ->
    atom.keybinder.register "app", @
    window.startup()

  open: (path) ->
    OSX.NSApp.open path

  quit: ->
    OSX.NSApp.terminate null
