File = require 'fs'
KeyBinder = require 'key-binder'

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
