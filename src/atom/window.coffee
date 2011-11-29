fs = require 'fs'
_ = require 'underscore'

# This a weirdo file. We don't create a Window class, we just add stuff to
# the DOM window.
#
# Events:
#   window:load - Same as window.onLoad. Final event of app startup.
windowAdditions =
  url: $atomController.url?.toString()

  startup: ->
    atom.trigger 'window:load', this

    if not @resource = atom.router.open @url
      throw "I DON'T KNOW ABOUT #{@url}"

  shutdown: ->
    $atomController.close

  showConsole: ->
    $atomController.webView.inspector.showConsole true

  setTitle: (title) ->
    $atomController.window.title = title

  reload: ->
    $atomController.reload

  open: (url) ->
    url = atom.native.openPanel() unless url
    (@resource.open url) or atom.app.open url

  close: ->
    @resource.close() or @shutdown()

  save: ->
    @resource.save()

  handleKeyEvent: ->
    atom.keybinder.handleEvent arguments...

  triggerEvent: ->
    atom.trigger arguments...

for key, value of windowAdditions
  console.warn "DOMWindow already has a key named `#{key}`" if window[key]
  window[key] = value
