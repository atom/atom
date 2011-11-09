KeyBinder = require 'key-binder'
fs = require 'fs'
require 'window'

module.exports =
class App
  constructor: ->
    KeyBinder.register "app", @
    window.startup()

  open: (path) ->
    OSX.NSApp.open path

  quit: ->
    OSX.NSApp.terminate null
