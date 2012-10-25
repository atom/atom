# This a weirdo file. We don't create a Window class, we just add stuff to
# the DOM window.

Native = require 'native'
TextMateBundle = require 'text-mate-bundle'
TextMateTheme = require 'text-mate-theme'
fs = require 'fs'
_ = require 'underscore'
$ = require 'jquery'
{CoffeeScript} = require 'coffee-script'
RootView = require 'root-view'
Pasteboard = require 'pasteboard'
require 'jquery-extensions'
require 'underscore-extensions'

windowAdditions =
  rootViewParentSelector: 'body'
  rootView: null
  keymap: null
  platform: $native.getPlatform()

  # This method runs when the file is required. Any code here will run
  # in all environments: spec, benchmark, and application
  startup: ->
    TextMateBundle.loadAll()
    TextMateTheme.loadAll()
    @setUpKeymap()
    @pasteboard = new Pasteboard
    $(window).on 'core:close', => @close()

  # This method is intended only to be run when starting a normal application
  # Note: RootView assigns itself on window on initialization so that
  # window.rootView is available when loading user configuration
  attachRootView: (pathToOpen) ->
    if rootViewState = atom.getRootViewStateForPath(pathToOpen)
      RootView.deserialize(rootViewState)
    else
      new RootView(pathToOpen)

    $(@rootViewParentSelector).append(@rootView)
    $(window).focus()
    $(window).on 'beforeunload', =>
      @shutdown()
      false

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

  requireStylesheet: (path) ->
    unless fullPath = require.resolve(path)
      throw new Error("requireStylesheet could not find a file at path '#{path}'")
    window.applyStylesheet(fullPath, fs.read(fullPath))

  applyStylesheet: (id, text) ->
    unless $("head style[id='#{id}']").length
      $('head').append "<style id='#{id}'>#{text}</style>"

  requireExtension: (name, config) ->
    try
      extensionPath = require.resolve name
      throw new Error("Extension '#{name}' does not exist at path '#{extensionPath}'") unless fs.exists(extensionPath)

      extension = rootView.activateExtension(require(extensionPath), config)
      extensionKeymapPath = fs.join(fs.directory(extensionPath), "src/keymap.coffee")
      require extensionKeymapPath if fs.exists(extensionKeymapPath)
      extension
    catch e
      console.error "Failed to load extension named '#{name}'"
      throw e

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
window.startup()

requireStylesheet 'reset.css'
requireStylesheet 'atom.css'

if nativeStylesheetPath = require.resolve("#{platform}.css")
  requireStylesheet(nativeStylesheetPath)
