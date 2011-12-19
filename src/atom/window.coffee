fs = require 'fs'
_ = require 'underscore'
$ = require 'jquery'

Layout = require 'layout'
Editor = require 'editor'

# This a weirdo file. We don't create a Window class, we just add stuff to
# the DOM window.

windowAdditions =
  editor: null
  layout: null

  startup: ->
    @layout = Layout.attach()
    @editor = new Editor $atomController.url?.toString()
    @bindKeys()

  shutdown: ->
    @layout.remove()
    @editor.shutdown()
    @unbindKeys()

  bindKeys: ->
    $(document).bind 'keydown', (event) =>
      if String.fromCharCode(event.which) == 'S' and event.metaKey
        @editor.save()

  unbindKeys: ->
    $(document).unbind 'keydown'

  showConsole: ->
    $atomController.webView.inspector.showConsole true

  onerror: ->
    @showConsole true

for key, value of windowAdditions
  console.warn "DOMWindow already has a key named `#{key}`" if window[key]
  window[key] = value
