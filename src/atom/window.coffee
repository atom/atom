fs = require 'fs'
_ = require 'underscore'
$ = require 'jquery'

RootView = require 'root-view'

# This a weirdo file. We don't create a Window class, we just add stuff to
# the DOM window.

windowAdditions =
  keyBindings: null
  rootView: null
  menuItemActions: null

  startup: ->
    @keyBindings = {}
    @menuItemActions = {}
    @rootView = RootView.attach()
    @registerEventHandlers()
    @bindKeys()
    @bindMenuItems()
    $(window).focus()

  shutdown: ->
    @rootView.remove()
    $(window).unbind('focus')
    $(window).unbind('blur')
    $(window).unbind('keydown')

  bindKeys: ->
    @bindKey 'meta+s', => @rootView.editor.save()
    @bindKey 'meta+w', => @close()
    @bindKey 'meta+t', => @rootView.toggleFileFinder()

  bindMenuItems: ->
    @bindMenuItem "File > Save", "meta+s", => @rootView.editor.save()

  bindMenuItem: (path, pattern, action) ->
    @menuItemActions[path] = {action: action, pattern: pattern}

  bindKey: (pattern, action) ->
    @keyBindings[pattern] = action

  keyEventMatchesPattern: (event, pattern) ->
    keys = @parseKeyPattern pattern

    keys.ctrlKey == event.ctrlKey and
      keys.altKey == event.altKey and
      keys.shiftKey == event.shiftKey and
      keys.metaKey == event.metaKey and
      event.which == keys.key.toUpperCase().charCodeAt 0

  parseKeyPattern: (pattern) ->
    [modifiers..., key] = pattern.split '+'

    ctrlKey: 'ctrl' in modifiers
    altKey: 'alt' in modifiers
    shiftKey: 'shift' in modifiers
    metaKey: 'meta' in modifiers
    key: key

  registerEventHandlers: ->
    $(document).bind 'keydown', (event) =>
      for pattern, action of @keyBindings
        action() if @keyEventMatchesPattern(event, pattern)

    $(window).focus => @registerMenuItems()
    $(window).blur -> atom.native.resetMainMenu()

  registerMenuItems: ->
    for path, {pattern} of @menuItemActions
      atom.native.addMenuItem(path, pattern)

  performActionForMenuItemPath: (path) ->
    @menuItemActions[path].action()

  showConsole: ->
    $atomController.webView.inspector.showConsole true

  onerror: ->
    @showConsole true

for key, value of windowAdditions
  console.warn "DOMWindow already has a key named `#{key}`" if window[key]
  window[key] = value
