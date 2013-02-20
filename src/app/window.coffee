# This a weirdo file. We don't create a Window class, we just add stuff to
# the DOM window.

fs = require 'fs'
$ = require 'jquery'
require 'jquery-extensions'
require 'underscore-extensions'
require 'space-pen-extensions'

deserializers = {}

windowAdditions =
  rootViewParentSelector: 'body'
  rootView: null
  keymap: null
  platform: $native.getPlatform()

  # This method runs when the file is required. Any code here will run
  # in all environments: spec, benchmark, and application
  setUpEnvironment: ->
    Config = require 'config'
    Syntax = require 'syntax'
    Pasteboard = require 'pasteboard'
    Keymap = require 'keymap'

    window.config = new Config
    window.syntax = new Syntax
    window.pasteboard = new Pasteboard
    window.keymap = new Keymap()
    $(document).on 'keydown', keymap.handleKeyEvent
    keymap.bindDefaultKeys()

  # This method is intended only to be run when starting a normal application
  # Note: RootView assigns itself on window on initialization so that
  # window.rootView is available when loading user configuration
  startup: ->
    handleWindowEvents()
    config.load()
    atom.loadTextPackage()
    buildProjectAndRootView()
    keymap.loadBundledKeymaps()
    atom.loadThemes()
    atom.loadPackages()
    keymap.loadUserKeymaps()
    $(window).on 'beforeunload', -> shutdown(); false
    $(window).focus()

    pathToOpen = atom.getPathToOpen()
    rootView.open(pathToOpen) if !pathToOpen or fs.isFile(pathToOpen)

  handleWindowEvents: ->
    $(window).on 'core:close', => window.close()
    $(window).command 'window:close', => window.close()
    $(window).command 'window:toggle-full-screen', => atom.toggleFullScreen()
    $(window).on 'focus', -> $("body").removeClass('is-blurred')
    $(window).on 'blur',  -> $("body").addClass('is-blurred')

  buildProjectAndRootView: ->
    RootView = require 'root-view'
    Project = require 'project'

    windowState = atom.getRootViewStateForPath(atom.getPathToOpen())
    if windowState?.project?
      window.project = deserialize(windowState.project)
      window.rootView = deserialize(windowState.rootView)
    window.project ?= new Project(atom.getPathToOpen())
    window.rootView ?= new RootView
    $(rootViewParentSelector).append(rootView)

  shutdown: ->
    atom.setWindowState('pathToOpen', project.getPath())
    atom.setRootViewStateForPath project.getPath(),
      project: project.serialize()
      rootView: rootView.serialize()
    rootView.deactivate()
    project.destroy()
    $(window).off('focus blur before')

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

  registerDeserializers: (args...) ->
    registerDeserializer(arg) for arg in args

  registerDeserializer: (klass) ->
    deserializers[klass.name] = klass

  deserialize: (state) ->
    deserializers[state.deserializer]?.deserialize(state)

  measure: (description, fn) ->
    start = new Date().getTime()
    value = fn()
    result = new Date().getTime() - start
    console.log description, result
    value

window[key] = value for key, value of windowAdditions
window.setUpEnvironment()

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
