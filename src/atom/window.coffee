fs = require 'fs'
_ = require 'underscore'
$ = require 'jquery'

Keymap = require 'keymap'
RootView = require 'root-view'

require 'jquery-extensions'
require 'underscore-extensions'

# This a weirdo file. We don't create a Window class, we just add stuff to
# the DOM window.

windowAdditions =
  rootViewParentSelector: 'body'
  rootView: null
  keymap: null

  startup: (path) ->
    @setUpKeymap()
    @attachRootView(path)
    @loadUserConfiguration()
    $(window).on 'close', => @close()
    $(window).focus()
    atom.windowOpened this

  shutdown: ->
    @rootView.remove()
    $(window).unbind('focus')
    $(window).unbind('blur')
    atom.windowClosed this
    @tearDownKeymap()

  setUpKeymap: ->
    @keymap = new Keymap()
    @keymap.bindDefaultKeys()

    @_handleKeyEvent = (e) => @keymap.handleKeyEvent(e)
    $(document).on 'keydown', @_handleKeyEvent

  tearDownKeymap: ->
    @keymap.unbindDefaultKeys()
    $(document).off 'keydown', @_handleKeyEvent

  attachRootView: (path) ->
    @rootView = new RootView {path}
    $(@rootViewParentSelector).append @rootView

  loadUserConfiguration: ->
    try
      require atom.userConfigurationPath if fs.exists(atom.userConfigurationPath)
    catch error
      console.error "Failed to load `#{atom.userConfigurationPath}`", error
      @showConsole()

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
