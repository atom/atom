fs = require 'fs'
_ = require 'underscore'
$ = require 'jquery'

GlobalKeymap = require 'global-keymap'
RootView = require 'root-view'

# This a weirdo file. We don't create a Window class, we just add stuff to
# the DOM window.

windowAdditions =
  rootView: null
  menuItemActions: null
  keymap: null

  startup: (url) ->
    @menuItemActions = {}

    @setupKeymap()
    @attachRootView(url)
    @registerEventHandlers()
    @bindMenuItems()
    
    $(window).focus()
    atom.windowOpened this

  shutdown: ->
    @rootView.remove()
    $(window).unbind('focus')
    $(window).unbind('blur')
    atom.windowClosed this

  setupKeymap: ->
    @keymap = new GlobalKeymap()
    $(document).on 'keydown', (e) -> @keymap.handleKeyEvent(e)

  attachRootView: (url) ->
    @rootView = new RootView {url}
    $('body').append @rootView

  requireStylesheet: (path) ->
    fullPath = require.resolve(path)
    content = fs.read(fullPath)
    return if $("head style[path='#{fullPath}']").length
    $('head').append "<style path='#{fullPath}'>#{content}</style>"

  bindMenuItems: ->
    # we want to integrate this better with keybindings
    # @bindMenuItem "File > Save", "meta+s", => @rootView.editor.save()

  bindMenuItem: (path, pattern, action) ->
    @menuItemActions[path] = {action: action, pattern: pattern}

  registerEventHandlers: ->
    $(window).on 'close', => 
      @shutdown()
      @close()
    $(window).focus => @registerMenuItems()
    $(window).blur -> atom.native.resetMainMenu()

  registerMenuItems: ->
    for path, {pattern} of @menuItemActions
      atom.native.addMenuItem(path, pattern)

  performActionForMenuItemPath: (path) ->
    @menuItemActions[path].action()

  showConsole: ->
    # $atomController.webView.inspector.showConsole true

  onerror: ->
    @showConsole true

for key, value of windowAdditions
  console.warn "DOMWindow already has a key named `#{key}`" if window[key]
  window[key] = value


requireStylesheet 'reset.css'
requireStylesheet 'atom.css'

