# This a weirdo file. We don't create a Window class, we just add stuff to
# the DOM window.

TextMateBundle = require 'app/text-mate-bundle'
TextMateTheme = require 'app/text-mate-theme'
fs = require 'fs'
path = require 'path'
_ = require 'underscore'
$ = require 'jquery'
{CoffeeScript} = require 'coffee-script'
RootView = require 'app/root-view'
Pasteboard = require 'app/pasteboard'
require 'stdlib/jquery-extensions'
require 'stdlib/underscore-extensions'

windowAdditions =
  rootViewParentSelector: 'body'
  rootView: null
  keymap: null
  platform: 'mac' # $native.getPlatform()

  # This method runs when the file is required. Any code here will run
  # in all environments: spec, benchmark, and application
  startup: ->
    global.document = window.document
    global.requireStylesheet = window.requireStylesheet
    global.platform = window.platform
    global.pasteboard = new Pasteboard

    TextMateBundle.loadAll()
    TextMateTheme.loadAll()
    @setUpKeymap()
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
    Keymap = require 'app/keymap'

    @keymap = new Keymap()
    @keymap.bindDefaultKeys()

    keymapsPath = path.resolveOnLoadPath("app/keymaps")
    for keymapPath in fs.readdirSync(keymapsPath)
      require(path.join(keymapsPath, keymapPath))

    @_handleKeyEvent = (e) => @keymap.handleKeyEvent(e)
    $(document).on 'keydown', @_handleKeyEvent

  requireStylesheet: (path) ->
    unless fullPath = require.resolve(path)
      throw new Error("requireStylesheet could not find a file at path '#{path}'")
    window.applyStylesheet(fullPath, fs.readFileSync(fullPath, 'utf8'))

  applyStylesheet: (id, text) ->
    unless $("head style[id='#{id}']").length
      $('head').append "<style id='#{id}'>#{text}</style>"

  requireExtension: (name, config) ->
    try
      extensionPath = require.resolve name
      throw new Error("Extension '#{name}' does not exist at path '#{extensionPath}'") unless fs.existsSync(extensionPath)

      extension = rootView.activateExtension(require(extensionPath), config)
      extensionKeymapPath = require.resolve(fs.join(name, "src/keymap"), {verifyExistence: false})
      require extensionKeymapPath if fs.existsSync(extensionKeymapPath)
      extension
    catch e
      console.error "Failed to load extension named '#{name}'", e

  reload: ->
    if rootView?.getModifiedBuffers().length > 0
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

_.defaults(window, windowAdditions)
window.startup()

requireStylesheet 'reset.css'
requireStylesheet 'atom.css'

if nativeStylesheetPath = require.resolve("#{platform}.css")
  requireStylesheet(nativeStylesheetPath)
