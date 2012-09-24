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
  platform: $native.getPlatform()

  startup: (path) ->
    TextMateBundle.loadAll()
    TextMateTheme.loadAll()

    @attachRootView(path)
    $(window).on 'close', => @close()
    $(window).on 'beforeunload', =>
      @shutdown()
      false
    $(window).focus()

  shutdown: ->
    @rootView.deactivate()
    $(window).unbind('focus')
    $(window).unbind('blur')
    $(window).off('before')

  setUpKeymap: ->
    Keymap = require 'keymap'

    @keymap = new Keymap()
    @keymap.bindDefaultKeys()
    require(keymapPath) for keymapPath in fs.list(require.resolve("keymaps"))

    @_handleKeyEvent = (e) => @keymap.handleKeyEvent(e)
    $(document).on 'keydown', @_handleKeyEvent

  # Note: RootView assigns itself on window on initialization so that
  # window.rootView is available when loading user configuration
  attachRootView: (pathToOpen) ->
    if rootViewState = atom.getRootViewStateForPath(pathToOpen)
      RootView.deserialize(rootViewState)
    else
      new RootView(pathToOpen)
      @rootView.open() unless pathToOpen

    $(@rootViewParentSelector).append @rootView

  requireStylesheet: (path) ->
    unless fullPath = require.resolve(path)
      throw new Error("requireStylesheet could not find a file at path '#{path}'")
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
      atom.confirm(
        "There are unsaved buffers, reload anyway?",
        "You will lose all unsaved changes if you reload",
        "Reload", (-> Native.reload()),
        "Cancel"
      )
    else
      Native.reload()

  onerror: ->
    atom.showDevTools()

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

if nativeStylesheetPath = require.resolve("#{platform}.css")
  requireStylesheet(nativeStylesheetPath)
