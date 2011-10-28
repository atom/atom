KeyBinder = require 'key-binder'
require 'window'

module.exports =
class App
  @startup: ->
    KeyBinder.register "app", @
    window.startup()

  @quit: ->
    OSX.NSApp.terminate OSX.NSApp
