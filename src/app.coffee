KeyBinder = require 'key-binder'
fs = require 'fs'
require 'window'

module.exports =
class App
  @startup: ->
    KeyBinder.register "app", @
    window.startup()

  @open: (path) ->
    OSX.NSApp.open path

  @quit: ->
    OSX.NSApp.terminate null 
