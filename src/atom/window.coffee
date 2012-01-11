fs = require 'fs'
_ = require 'underscore'
$ = require 'jquery'

RootView = require 'root-view'

# This a weirdo file. We don't create a Window class, we just add stuff to
# the DOM window.

windowAdditions =
  rootView: null
  menuItemActions: null

  startup: ->
    @menuItemActions = {}
    @rootView = RootView.build(url: $atomController.url?.toString())
    $('body').append @rootView
    @registerEventHandlers()
    @bindMenuItems()
    $(this).on 'close', => @close()
    $(window).focus()

  shutdown: ->
    @rootView.remove()
    $(window).unbind('focus')
    $(window).unbind('blur')

  bindMenuItems: ->
    # we want to integrate this better with keybindings
    # @bindMenuItem "File > Save", "meta+s", => @rootView.editor.save()

  bindMenuItem: (path, pattern, action) ->
    @menuItemActions[path] = {action: action, pattern: pattern}

  registerEventHandlers: ->
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

