fs = require 'fs'
$ = require 'jquery'
require 'jquery-extensions'
require 'underscore-extensions'
require 'space-pen-extensions'

deserializers = {}

# This method is called in any window needing a general environment, including specs
window.setUpEnvironment = ->
  Config = require 'config'
  Syntax = require 'syntax'
  Pasteboard = require 'pasteboard'
  Keymap = require 'keymap'

  window.rootViewParentSelector = 'body'
  window.platform = $native.getPlatform()
  window.config = new Config
  window.syntax = new Syntax
  window.pasteboard = new Pasteboard
  window.keymap = new Keymap()
  $(document).on 'keydown', keymap.handleKeyEvent
  keymap.bindDefaultKeys()

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

# This method is only called when opening a real application window
window.startup = ->
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

window.shutdown = ->
  return if not project and not rootView
  atom.setWindowState('pathToOpen', project.getPath())
  atom.setRootViewStateForPath project.getPath(),
    project: project.serialize()
    rootView: rootView.serialize()
  rootView.deactivate()
  project.destroy()
  $(window).off('focus blur before')
  window.rootView = null
  window.project = null

window.handleWindowEvents = ->
  $(window).on 'core:close', => window.close()
  $(window).command 'window:close', => window.close()
  $(window).command 'window:toggle-full-screen', => atom.toggleFullScreen()
  $(window).on 'focus', -> $("body").removeClass('is-blurred')
  $(window).on 'blur',  -> $("body").addClass('is-blurred')

window.buildProjectAndRootView = ->
  RootView = require 'root-view'
  Project = require 'project'

  windowState = atom.getRootViewStateForPath(atom.getPathToOpen())
  if windowState?.project?
    window.project = deserialize(windowState.project)
    window.rootView = deserialize(windowState.rootView)
  window.project ?= new Project(atom.getPathToOpen())
  window.rootView ?= new RootView
  $(rootViewParentSelector).append(rootView)

window.stylesheetElementForId = (id) ->
  $("head style[id='#{id}']")

window.requireStylesheet = (path) ->
  if fullPath = require.resolve(path)
    window.applyStylesheet(fullPath, fs.read(fullPath))
  unless fullPath
    throw new Error("Could not find a file at path '#{path}'")

window.removeStylesheet = (path) ->
  unless fullPath = require.resolve(path)
    throw new Error("Could not find a file at path '#{path}'")
  window.stylesheetElementForId(fullPath).remove()

window.applyStylesheet = (id, text, ttype = 'bundled') ->
  unless window.stylesheetElementForId(id).length
    if $("head style.#{ttype}").length
      $("head style.#{ttype}:last").after "<style class='#{ttype}' id='#{id}'>#{text}</style>"
    else
      $("head").append "<style class='#{ttype}' id='#{id}'>#{text}</style>"

window.reload = ->
  if rootView?.getModifiedBuffers().length > 0
    atom.confirm(
      "There are unsaved buffers, reload anyway?",
      "You will lose all unsaved changes if you reload",
      "Reload", (-> $native.reload()),
      "Cancel"
    )
  else
    $native.reload()

window.onerror = ->
  atom.showDevTools()

window.registerDeserializers = (args...) ->
  registerDeserializer(arg) for arg in args

window.registerDeserializer = (klass) ->
  deserializers[klass.name] = klass

window.deserialize = (state) ->
  deserializers[state.deserializer]?.deserialize(state)

window.measure = (description, fn) ->
  start = new Date().getTime()
  value = fn()
  result = new Date().getTime() - start
  console.log description, result
  value
