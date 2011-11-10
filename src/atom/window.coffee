fs = require 'fs'
_ = require 'underscore'

# This a weirdo file. We don't create a Window class, we just add stuff to
# the DOM window.
windowAdditions =
  appRoot: OSX.NSBundle.mainBundle.resourcePath

  path: null

  startup: ->
    @path = $atomController.path.toString()
    @setTitle (_.last @path.split '/') or 'Untitled Document'

    $atomController.window.makeKeyWindow
    atom.trigger 'window:load'

  shutdown: ->

  showConsole: ->
    $atomController.webView.inspector.showConsole true

  setTitle: (title) ->
    $atomController.window.title = title

  reload: ->
    @close()
    OSX.NSApp.createController @path

  open: (path) ->
    $atomController.window.makeKeyAndOrderFront $atomController
    if atom.document.open path
      atom.trigger 'window:open', path
    else
      atom.app.open path

  close: (path) ->
    @shutdown()
    $atomController.close
    atom.trigger 'window:close', path

  handleKeyEvent: ->
    atom.keybinder.handleEvent arguments...

  triggerEvent: ->
    atom.trigger arguments...

  canOpen: (path) ->
    false

for key, value of windowAdditions
  console.warn "DOMWindow already has a key named `#{key}`" if window[key]
  window[key] = value
