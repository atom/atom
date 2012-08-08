# This a weirdo file. We don't create a Window class, we just add stuff to
# the DOM window.

Native = require 'native'
TextMateBundle = require 'text-mate-bundle'
TextMateTheme = require 'text-mate-theme'
fs = require 'fs'
_ = require 'underscore'
$ = require 'jquery'
{CoffeeScript} = require 'coffee-script'

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
    TextMateBundle.loadAll()
    TextMateTheme.loadAll()

    @attachRootView(path)
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

  # Note: RootView assigns itself on window on initialization so that
  # window.rootView is available when loading user configuration
  attachRootView: (pathToOpen) ->
    if rootViewState = atom.rootViewStates[$windowNumber]
      RootView.deserialize(JSON.parse(rootViewState))
    else
      new RootView(pathToOpen)
      @rootView.open() unless pathToOpen

    $(@rootViewParentSelector).append @rootView

  requireStylesheet: (path) ->
    fullPath = require.resolve(path)
    window.applyStylesheet(fullPath, fs.read(fullPath))

  applyStylesheet: (id, text) ->
    unless $("head style[id='#{id}']").length
      $('head').append "<style id='#{id}'>#{text}</style>"

  requireExtension: (name) ->
    extensionPath = require.resolve name
    extension = rootView.activateExtension require(extensionPath)

    extensionKeymapPath = fs.join(fs.directory(extensionPath), "keymap.coffee")
    require extensionKeymapPath if fs.exists(extensionKeymapPath)

    extension

  reload: ->
    if rootView.getModifiedBuffers().length > 0
      message = "There are unsaved buffers, reload anyway?"
      detailedMessage = "You will lose all unsaved changes if you reload"
      buttons = [
        ["Reload", -> Native.reload()]
        ["Cancel", ->]
      ]

      Native.alert(message, detailedMessage, buttons)
    else
      Native.reload()

  toggleDevTools: ->
    $native.toggleDevTools()

  onerror: ->
    $native.showDevTools()

  measure: (description, fn) ->
    start = new Date().getTime()
    fn()
    result = new Date().getTime() - start
    console.log description, result

window[key] = value for key, value of windowAdditions
window.setUpKeymap()

RootView = require 'root-view'

require 'jquery-extensions'
require 'underscore-extensions'

requireStylesheet 'reset.css'
requireStylesheet 'atom.css'
