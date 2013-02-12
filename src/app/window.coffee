# This a weirdo file. We don't create a Window class, we just add stuff to
# the DOM window.

fs = require 'fs'
$ = require 'jquery'
Config = require 'config'
Syntax = require 'syntax'
RootView = require 'root-view'
Pasteboard = require 'pasteboard'
require 'jquery-extensions'
require 'underscore-extensions'
require 'space-pen-extensions'

windowAdditions =
  rootViewParentSelector: 'body'
  rootView: null
  keymap: null
  platform: $native.getPlatform()

  # This method runs when the file is required. Any code here will run
  # in all environments: spec, benchmark, and application
  startup: ->
    @config = new Config
    @syntax = new Syntax
    @setUpKeymap()
    @pasteboard = new Pasteboard
    @setUpEventHandlers()

  setUpEventHandlers: ->
    $(window).on 'core:close', => @close()
    $(window).command 'window:close', => @close()
    $(window).command 'window:toggle-full-screen', => atom.toggleFullScreen()
    $(window).on 'focus', -> $("body").removeClass('is-blurred')
    $(window).on 'blur',  -> $("body").addClass('is-blurred')

  # This method is intended only to be run when starting a normal application
  # Note: RootView assigns itself on window on initialization so that
  # window.rootView is available when loading user configuration
  attachRootView: (pathToOpen) ->
    if pathState = atom.getRootViewStateForPath(pathToOpen)
      RootView.deserialize(pathState)
    else
      new RootView(pathToOpen)

    $(@rootViewParentSelector).append(@rootView)
    $(window).focus()
    $(window).on 'beforeunload', =>
      @shutdown()
      false

  shutdown: ->
    if @rootView
      atom.setWindowState('pathToOpen', @rootView.project.getPath())
      @rootView.deactivate()
      @rootView = null
    $(window).off('focus')
    $(window).off('blur')
    $(window).off('before')

  setUpKeymap: ->
    Keymap = require 'keymap'

    @keymap = new Keymap()
    @keymap.bindDefaultKeys()
    @keymap.loadBundledKeymaps()
    @keymap.loadUserKeymaps()

    @_handleKeyEvent = (e) => @keymap.handleKeyEvent(e)
    $(document).on 'keydown', @_handleKeyEvent

  stylesheetElementForId: (id) ->
    $("head style[id='#{id}']")

  requireStylesheet: (path) ->
    if fullPath = require.resolve(path)
      window.applyStylesheet(fullPath, fs.read(fullPath))
    unless fullPath
      throw new Error("Could not find a file at path '#{path}'")

  removeStylesheet: (path) ->
    unless fullPath = require.resolve(path)
      throw new Error("Could not find a file at path '#{path}'")
    window.stylesheetElementForId(fullPath).remove()

  applyStylesheet: (id, text, ttype = 'bundled') ->
    unless window.stylesheetElementForId(id).length
      if $("head style.#{ttype}").length
        $("head style.#{ttype}:last").after "<style class='#{ttype}' id='#{id}'>#{text}</style>"
      else
        $("head").append "<style class='#{ttype}' id='#{id}'>#{text}</style>"


  reload: ->
    if rootView?.getModifiedBuffers().length > 0
      atom.confirm(
        "There are unsaved buffers, reload anyway?",
        "You will lose all unsaved changes if you reload",
        "Reload", (-> $native.reload()),
        "Cancel"
      )
    else
      $native.reload()

  onerror: ->
    atom.showDevTools()

  measure: (description, fn) ->
    start = new Date().getTime()
    value = fn()
    result = new Date().getTime() - start
    console.log description, result
    value

window[key] = value for key, value of windowAdditions
window.startup()

requireStylesheet 'reset.css'
requireStylesheet 'atom.css'
requireStylesheet 'tabs.css'
requireStylesheet 'tree-view.css'
requireStylesheet 'status-bar.css'
requireStylesheet 'command-panel.css'
requireStylesheet 'fuzzy-finder.css'
requireStylesheet 'overlay.css'
requireStylesheet 'popover-list.css'
requireStylesheet 'notification.css'
requireStylesheet 'markdown.css'

if nativeStylesheetPath = require.resolve("#{platform}.css")
  requireStylesheet(nativeStylesheetPath)
