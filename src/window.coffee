KeyBinder = require 'key-binder'
fs = require 'fs'

# This file is a weirdo. We don't create a Window class, we just add stuff to
# the DOM window.
windowAdditions =
  extensions: []

  startup: ->
    KeyBinder.register "window", window

    @path = localStorage.lastOpenedPath ? File.workingDirectory()
    @appPath = OSX.NSBundle.mainBundle.resourcePath

  handleKeyEvent: ->
    KeyBinder.handleEvent.apply KeyBinder, arguments

  showConsole: ->
    atomController.webView.inspector.showConsole true

for key, value of windowAdditions
  raise "DOMWindow already has a key named #{key}" if window[key]
  window[key] = value
