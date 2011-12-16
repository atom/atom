fs = require 'fs'
_ = require 'underscore'

Editor = require 'editor'

# This a weirdo file. We don't create a Window class, we just add stuff to
# the DOM window.
#
# Events:
#   window:load - Same as window.onLoad. Final event of app startup.
windowAdditions =
  editor: null
  url: $atomController.url?.toString()

  startup: ->
    @editor = new Editor @url

  shutdown: ->
    $atomController.close

  showConsole: ->
    $atomController.webView.inspector.showConsole true

  onerror: ->
    @showConsole true

  triggerEvent: ->
    null

for key, value of windowAdditions
  console.warn "DOMWindow already has a key named `#{key}`" if window[key]
  window[key] = value
