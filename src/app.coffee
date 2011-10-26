File = require 'fs'
KeyBinder = require 'key-binder'
require 'window'

module.exports =
class App
  @root: OSX.NSBundle.mainBundle.resourcePath

  @startup: ->
    KeyBinder.register "app", @

    window.startup()

    KeyBinder.load "#{@root}/static/key-bindings.coffee"
    KeyBinder.load "~/.atomicity/key-bindings.coffee"

  @quit: ->
    OSX.NSApp.terminate OSX.NSApp
