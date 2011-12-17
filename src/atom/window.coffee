fs = require 'fs'
_ = require 'underscore'

Layout = require 'layout'
Editor = require 'editor'

# This a weirdo file. We don't create a Window class, we just add stuff to
# the DOM window.

windowAdditions =
  editor: null
  url: $atomController.url?.toString()

  startup: ->
    Layout.attach()
    @editor = new Editor @url
    @bindKeys()

  bindKeys: ->
    $(document).bind 'keydown', 'meta+s', => @editor.save()

  showConsole: ->
    $atomController.webView.inspector.showConsole true

  onerror: ->
    @showConsole true

  triggerEvent: ->
    null

for key, value of windowAdditions
  console.warn "DOMWindow already has a key named `#{key}`" if window[key]
  window[key] = value
