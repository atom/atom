Editor = require 'editor'
Event = require 'event'
KeyBinder = require 'key-binder'
Native = require 'native'

fs = require 'fs'

# This a weirdo file. We don't create a Window class, we just add stuff to
# the DOM window.
windowAdditions =
  editor: null

  extensions: []

  appRoot: OSX.NSBundle.mainBundle.resourcePath

  startup: () ->
    if atomController.path
      @setRecentPath atomController.path
    else
      atomController.path = @recentPath()

    KeyBinder.register "window", window

    @editor = if fs.isFile atomController.path
      new Editor atomController.path
    else
      new Editor @tmpFile()

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
    localStorage.lastOpenedPath ? @tmpFile()

  setRecentPath: (path) ->
    localStorage.lastOpenedPath = path

  tmpFile: ->
    "/tmp/atom"

  showConsole: ->
    atomController.webView.inspector.showConsole true

  reload: ->
    @close()
    Native.newWindow atomController.path

  open: (path) ->
    atomController.window.makeKeyAndOrderFront atomController

    if fs.isFile path
      Event.trigger 'window:open', path

  close: ->
    atomController.close

  # Global methods that are used by the cocoa side of things
  handleKeyEvent: ->
    KeyBinder.handleEvent.apply KeyBinder, arguments

  triggerEvent: ->
    Event.trigger.apply Event, arguments

  canOpen: (path) ->
    parent = atomController.path.replace(/([^\/])$/, "$1/")
    child = path.replace(/([^\/])$/, "$1/")

    console.log parent
    console.log child
    window.x = parent
    window.y = child

    # If the child is contained by the parent, it can be opened by this window
    return child.match "^" + parent

for key, value of windowAdditions
  console.warn "DOMWindow already has a key named `#{key}`" if window[key]
  window[key] = value
