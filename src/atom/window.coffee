fs = require 'fs'
_ = require 'underscore'
$ = require 'jquery'

GlobalKeymap = require 'global-keymap'
RootView = require 'root-view'

require 'jquery-extensions'

# This a weirdo file. We don't create a Window class, we just add stuff to
# the DOM window.

windowAdditions =
  rootView: null
  keymap: null

  startup: (url) ->
    @setupKeymap()
    @attachRootView(url)

    $(window).on 'close', =>
      @shutdown()
      @close()

    $(window).focus()
    atom.windowOpened this

  shutdown: ->
    @rootView.remove()
    $(window).unbind('focus')
    $(window).unbind('blur')
    atom.windowClosed this

  setupKeymap: ->
    @keymap = new GlobalKeymap()
    @keymap.bindDefaultKeys()
    $(document).on 'keydown', (e) => @keymap.handleKeyEvent(e)

  attachRootView: (url) ->
    @rootView = new RootView {url}
    $('body').append @rootView

  requireStylesheet: (path) ->
    fullPath = require.resolve(path)
    content = fs.read(fullPath)
    return if $("head style[path='#{fullPath}']").length
    $('head').append "<style path='#{fullPath}'>#{content}</style>"

  showConsole: ->
    $native.showDevTools()

  onerror: ->
    @showConsole()

for key, value of windowAdditions
  console.warn "DOMWindow already has a key named `#{key}`" if window[key]
  window[key] = value

requireStylesheet 'reset.css'
requireStylesheet 'atom.css'
