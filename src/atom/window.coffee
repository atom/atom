fs = require 'fs'
_ = require 'underscore'

# This a weirdo file. We don't create a Window class, we just add stuff to
# the DOM window.
windowAdditions =
  path: null

  startup: ->
    @path = $atomController.path?.toString()
    $atomController.window.makeKeyWindow

  shutdown: ->

  showConsole: ->
    $atomController.webView.inspector.showConsole true

  setTitle: (title) ->
    $atomController.window.title = title

  reload: ->
    @close()
    OSX.NSApp.createController @path

  open: (path) ->
    path = atom.native.openPanel() unless path
    (atom.document.open path) or atom.app.open path

  close: (path) ->
    @shutdown()
    $atomController.close

  handleKeyEvent: ->
    atom.keybinder.handleEvent arguments...

  triggerEvent: ->
    atom.trigger arguments...

for key, value of windowAdditions
  console.warn "DOMWindow already has a key named `#{key}`" if window[key]
  window[key] = value
