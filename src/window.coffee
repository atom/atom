Editor = require 'editor'
Extension = require 'extension'
Event = require 'event'
KeyBinder = require 'key-binder'
Native = require 'native'
Storage = require 'storage'

fs = require 'fs'

# This a weirdo file. We don't create a Window class, we just add stuff to
# the DOM window.
windowAdditions =
  editor: null

  extensions: {}

  appRoot: OSX.NSBundle.mainBundle.resourcePath

  startup: () ->
    KeyBinder.register "window", window

    @path = atomController.path
    @setTitle @path

    @editor = if fs.isFile @path
      new Editor @path
    else
      new Editor

    @loadExtensions()
    @loadKeyBindings()
    @loadSettings()

    @editor.restoreOpenBuffers()

  storageKey: ->
    "window:" + @path

  loadExtensions: ->
    extension.shutdown() for name, extension of @extensions
    @extensions = {}

    extensionPaths = fs.list require.resourcePath + "/extensions"
    for extensionPath in extensionPaths when fs.isDirectory extensionPath
      try
        extension = require extensionPath
        @extensions[extension.name] = new extension
      catch error
        console.warn "window: Loading Extension '#{fs.base extensionPath}' failed."
        console.warn error

    # After all the extensions are created, start them up.
    for name, extension of @extensions
      try
        extension.startup()
      catch error
        console.warn "window: Extension #{extension.constructor.name} failed to startup."
        console.warn error

  loadKeyBindings: ->
    KeyBinder.load "#{@appRoot}/static/key-bindings.coffee"
    if fs.isFile "~/.atomicity/key-bindings.coffee"
      KeyBinder.load "~/.atomicity/key-bindings.coffee"

  loadSettings: ->
    if fs.isFile "~/.atomicity/settings.coffee"
      require "~/.atomicity/settings.coffee"

  showConsole: ->
    atomController.webView.inspector.showConsole true

  setTitle: (title) ->
    atomController.window.title = title

  reload: ->
    atomController.close
    OSX.NSApp.createController @path

  # Do open and close even belong here?
  open: (path) ->
    atomController.window.makeKeyAndOrderFront atomController

    if fs.isFile path
      Event.trigger 'window:open', path

  close: (path) ->
    extension.shutdown() for name, extension of @extensions

    atomController.close
    Event.trigger 'window:close', path

  # Global methods that are used by the cocoa side of things
  handleKeyEvent: ->
    KeyBinder.handleEvent.apply KeyBinder, arguments

  triggerEvent: ->
    Event.trigger.apply Event, arguments

  canOpen: (path) ->
    parent = @path.replace(/([^\/])$/, "$1/")
    child = path.replace(/([^\/])$/, "$1/")

    # If the child is contained by the parent, it can be opened by this window
    child.match "^" + parent

for key, value of windowAdditions
  console.warn "DOMWindow already has a key named `#{key}`" if window[key]
  window[key] = value
