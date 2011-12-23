fs = require 'fs'
_ = require 'underscore'
$ = require 'jquery'

Layout = require 'layout'
Editor = require 'editor'

# This a weirdo file. We don't create a Window class, we just add stuff to
# the DOM window.

windowAdditions =
  editor: null
  keyBindings: null
  layout: null

  startup: ->
    @keyBindings = {}
    @layout = Layout.attach()
    @editor = new Editor $atomController.url?.toString()
    @registerKeydownHandler()
    @bindKeys()

  shutdown: ->
    @layout.remove()
    @editor.shutdown()

  bindKeys: ->
    @bindKey 'meta+s', => @editor.save()

  bindKey: (pattern, action) ->
    @keyBindings[pattern] = action

  keyEventMatchesPattern: (event, pattern) ->
    [modifiers..., key] = pattern.split '+'
    patternModifiers =
      ctrlKey: 'ctrl' in modifiers
      altKey: 'alt' in modifiers
      shiftKey: 'shift' in modifiers
      metaKey: 'meta' in modifiers

    patternModifiers.ctrlKey == event.ctrlKey and
      patternModifiers.altKey == event.altKey and
      patternModifiers.shiftKey == event.shiftKey and
      patternModifiers.metaKey == event.metaKey and
      event.which == key.toUpperCase().charCodeAt 0

  registerKeydownHandler: ->
    $(document).bind 'keydown', (event) =>
      for pattern, action of @keyBindings
        action() if @keyEventMatchesPattern(event, pattern)

  showConsole: ->
    $atomController.webView.inspector.showConsole true

  onerror: ->
    @showConsole true

for key, value of windowAdditions
  console.warn "DOMWindow already has a key named `#{key}`" if window[key]
  window[key] = value
