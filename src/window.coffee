Editor = require 'editor'
Event = require 'event'
KeyBinder = require 'key-binder'
Native = require 'native'

fs = require 'fs'

# This file is a weirdo. We don't create a Window class, we just add stuff to
# the DOM window.
windowAdditions =
  editor: null

  extensions: []

  appRoot: OSX.NSBundle.mainBundle.resourcePath

  path: localStorage.lastOpenedPath ? fs.workingDirectory()

  startup: ->
    KeyBinder.register "window", window

    @editor = new Editor()

    @loadExtensions()

    KeyBinder.load "#{@appRoot}/static/key-bindings.coffee"
    KeyBinder.load "~/.atomicity/key-bindings.coffee"

  loadExtensions: ->
    extension.shutdown() for extension in @extensions
    @extensions = []

    extensionPaths = fs.list(@appRoot + "/extensions")
    for extensionPath in extensionPaths when fs.isDirectory extensionPath
      try
        extension = require extensionPath
        extensions.push new Extension()
      catch error
        console.warn "window: Loading Extension #{fs.base extensionPath} failed."
        console.warn error

    # After all the extensions are created, start them up.
    for extension in @extensions
      try
        extension.startup()
      catch error
        console.warn "window: Extension #{extension.constructor.name} failed to startup."
        console.warn error

  handleKeyEvent: ->
    KeyBinder.handleEvent.apply KeyBinder, arguments

  showConsole: ->
    atomController.webView.inspector.showConsole true

  open: (path) ->
    path = Native.openPanel() if not path
    Event.trigger 'window:open', path if path

for key, value of windowAdditions
  console.warn "DOMWindow already has a key named `#{key}`" if window[key]
  window[key] = value
