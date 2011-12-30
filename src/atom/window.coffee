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
    @rootView.editor.open $atomController.url?.toString()
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
      event.which == keys.charCode

  namedKeys:
    backspace: 8, tab: 9, clear: 12,
    enter: 13, 'return': 13,
    esc: 27, escape: 27, space: 32,
    left: 37, up: 38,
    right: 39, down: 40,
    del: 46, 'delete': 46,
    home: 36, end: 35,
    pageup: 33, pagedown: 34,
    ',': 188, '.': 190, '/': 191,
    '`': 192, '-': 189, '=': 187,
    ';': 186, '\'': 222,
    '[': 219, ']': 221, '\\': 220

  parseKeyPattern: (pattern) ->
    [modifiers..., key] = pattern.split '+'

    if window.namedKeys[key]
      charCode = window.namedKeys[key]
      key = null
    else
      charCode = key.toUpperCase().charCodeAt 0

    ctrlKey: 'ctrl' in modifiers
    altKey: 'alt' in modifiers
    shiftKey: 'shift' in modifiers
    metaKey: 'meta' in modifiers
    charCode: charCode
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
