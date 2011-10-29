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

  path: null

  startup: () ->
    @path = atomController.path ? @recentPath()

    KeyBinder.register "window", window

    @editor = new Editor @path

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

  recentPath: ->
    localStorage.lastOpenedPath ? "/tmp/atom"

  setRecentPath: (path) ->
    localStorage.lastOpenedPath = path

  handleKeyEvent: ->
    KeyBinder.handleEvent.apply KeyBinder, arguments

  showConsole: ->
    atomController.webView.inspector.showConsole true

  reload: ->
    @close()
    Native.newWindow @path

  open: (path) ->
    path = Native.openPanel() if not path
    if path
      @path = path
      @setRecentPath path
      Event.trigger 'window:open', path

  close: ->
    atomController.close

for key, value of windowAdditions
  console.warn "DOMWindow already has a key named `#{key}`" if window[key]
  window[key] = value
