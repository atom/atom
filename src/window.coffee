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

  extensions: []

  appRoot: OSX.NSBundle.mainBundle.resourcePath

  startup: () ->
    KeyBinder.register "window", window

    @setTitle atomController.path

    @editor = if fs.isFile atomController.path
      new Editor atomController.path
    else
      new Editor

    @loadExtensions()
    @loadKeyBindings()

    @editor.restoreOpenBuffers()

  storageKey: ->
    "window:" + atomController.path

  loadExtensions: ->
    extension.shutdown() for extension in @extensions
    @extensions = []

    extensionPaths = fs.list require.resourcePath + "/extensions"
    for extensionPath in extensionPaths when fs.isDirectory extensionPath
      try
        extension = require extensionPath
        extensions.push new extension()
      catch error
        console.warn "window: Loading Extension '#{fs.base extensionPath}' failed."
        console.warn error

    # After all the extensions are created, start them up.
    for extension in @extensions
      try
        extension.startup()
      catch error
        console.warn "window: Extension #{extension.constructor.name} failed to startup."
        console.warn error

  loadKeyBindings: ->
    KeyBinder.load "#{@appRoot}/static/key-bindings.coffee"
    KeyBinder.load "~/.atomicity/key-bindings.coffee"

  showConsole: ->
    atomController.webView.inspector.showConsole true

  setTitle: (title) ->
    atomController.window.title = title

  reload: ->
    atomController.close
    OSX.NSApp.createController atomController.path

  # Do open and close even belong here?
  open: (path) ->
    atomController.window.makeKeyAndOrderFront atomController

    if fs.isFile path
      Event.trigger 'window:open', path

  close: (path) ->
    extension.shutdown() for extension in @extensions

    atomController.close
    Event.trigger 'window:close', path

  # Global methods that are used by the cocoa side of things
  handleKeyEvent: ->
    KeyBinder.handleEvent.apply KeyBinder, arguments

  triggerEvent: ->
    Event.trigger.apply Event, arguments

  canOpen: (path) ->
    parent = atomController.path.replace(/([^\/])$/, "$1/")
    child = path.replace(/([^\/])$/, "$1/")

    # If the child is contained by the parent, it can be opened by this window
    child.match "^" + parent

for key, value of windowAdditions
  console.warn "DOMWindow already has a key named `#{key}`" if window[key]
  window[key] = value
