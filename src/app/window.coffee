# This a weirdo file. We don't create a Window class, we just add stuff to
# the DOM window.

Native = require 'native'
fs = require 'fs'
_ = require 'underscore'
$ = require 'jquery'

windowAdditions =
  rootViewParentSelector: 'body'
  rootView: null
  keymap: null

  setUpKeymap: ->
    Keymap = require 'keymap'

    @keymap = new Keymap()
    @keymap.bindDefaultKeys()
    require(keymapPath) for keymapPath in fs.list(require.resolve("keymaps"))

    @_handleKeyEvent = (e) => @keymap.handleKeyEvent(e)
    $(document).on 'keydown', @_handleKeyEvent

  startup: (path) ->
    @attachRootView(path)
    @loadUserConfiguration()
    $(window).on 'close', => @close()
    $(window).on 'beforeunload', =>
      @shutdown()
      false
    $(window).focus()
    atom.windowOpened this

  shutdown: ->
    @rootView.deactivate()
    $(window).unbind('focus')
    $(window).unbind('blur')
    $(window).off('before')
    atom.windowClosed this

  attachRootView: (pathToOpen) ->
    rootViewState = atom.rootViewStates[$windowNumber]
    if rootViewState
      @rootView = RootView.deserialize(rootViewState)
    else
      @rootView = new RootView(pathToOpen)
      @rootView.open() unless pathToOpen

    $(@rootViewParentSelector).append @rootView

  loadUserConfiguration: ->
    try
      require atom.userConfigurationPath if fs.exists(atom.userConfigurationPath)
    catch error
      console.error "Failed to load `#{atom.userConfigurationPath}`", error.message, error
      @showConsole()

  requireStylesheet: (path) ->
    fullPath = require.resolve(path)
    content = fs.read(fullPath)
    return if $("head style[path='#{fullPath}']").length
    $('head').append "<style path='#{fullPath}'>#{content}</style>"

  reload: ->
    if rootView.modifiedBuffers().length > 0
      message = "There are unsaved buffers, reload anyway?"
      detailedMessage = "You will lose all unsaved changes if you reload"
      buttons = [
        ["Reload", -> Native.reload()]
        ["Cancel", ->]
      ]

      Native.alert(message, detailedMessage, buttons)
    else
      Native.reload()

  showConsole: ->
    $native.showDevTools()

  onerror: ->
    @showConsole()

window[key] = value for key, value of windowAdditions
window.setUpKeymap()

RootView = require 'root-view'

require 'jquery-extensions'
require 'underscore-extensions'

requireStylesheet 'reset.css'
requireStylesheet 'atom.css'
