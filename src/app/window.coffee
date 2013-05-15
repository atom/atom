fs = require 'fs'
fsUtils = require 'fs-utils'
$ = require 'jquery'
_ = require 'underscore'
less = require 'less'
require 'jquery-extensions'
require 'underscore-extensions'
require 'space-pen-extensions'

deserializers = {}
deferredDeserializers = {}

### Internal ###

# This method is called in any window needing a general environment, including specs
window.setUpEnvironment = ->
  Config = require 'config'
  Syntax = require 'syntax'
  Pasteboard = require 'pasteboard'
  Keymap = require 'keymap'

  window.rootViewParentSelector = 'body'
  window.config = new Config
  window.syntax = deserialize(atom.getWindowState('syntax')) ? new Syntax
  window.pasteboard = new Pasteboard
  window.keymap = new Keymap()
  $(document).on 'keydown', keymap.handleKeyEvent

  keymap.bindDefaultKeys()

  requireStylesheet 'atom'

  if nativeStylesheetPath = fsUtils.resolveOnLoadPath(process.platform, ['css', 'less'])
    requireStylesheet(nativeStylesheetPath)

# This method is only called when opening a real application window
window.startEditorWindow = ->
  installAtomCommand()
  installApmCommand()

  atom.windowMode = 'editor'
  handleEvents()
  handleDragDrop()
  config.load()
  keymap.loadBundledKeymaps()
  atom.loadThemes()
  atom.loadPackages()
  deserializeEditorWindow()
  atom.activatePackages()
  keymap.loadUserKeymaps()
  atom.requireUserInitScript()
  $(window).on 'beforeunload', -> unloadEditorWindow(); false
  $(window).focus()

window.startConfigWindow = ->
  atom.windowMode = 'config'
  handleEvents()
  config.load()
  keymap.loadBundledKeymaps()
  atom.loadThemes()
  atom.loadPackages()
  deserializeConfigWindow()
  atom.activatePackageConfigs()
  keymap.loadUserKeymaps()
  $(window).on 'beforeunload', -> unloadConfigWindow(); false
  $(window).focus()

window.unloadEditorWindow = ->
  return if not project and not rootView
  atom.setWindowState('pathToOpen', project.getPath())
  atom.setWindowState('project', project.serialize())
  atom.setWindowState('syntax', syntax.serialize())
  atom.setWindowState('rootView', rootView.serialize())
  atom.deactivatePackages()
  atom.setWindowState('packageStates', atom.packageStates)
  rootView.remove()
  atom.saveWindowState()
  project.destroy()
  git?.destroy()
  $(window).off('focus blur before')
  window.rootView = null
  window.project = null
  window.git = null

window.installAtomCommand = (callback) ->
  commandPath = fsUtils.join(window.resourcePath, 'atom.sh')
  require('command-installer').install(commandPath, callback)

window.installApmCommand = (callback) ->
  commandPath = fsUtils.join(window.resourcePath, 'node_modules', '.bin', 'apm')
  require('command-installer').install(commandPath, callback)

window.unloadConfigWindow = ->
  return if not configView
  atom.setWindowState('configView', configView.serialize())
  atom.saveWindowState()
  configView.remove()
  window.configView = null
  $(window).off('focus blur before')

window.handleEvents = ->
  $(window).command 'window:toggle-full-screen', => atom.toggleFullScreen()
  $(window).on 'focus', -> $("body").removeClass('is-blurred')
  $(window).on 'blur',  -> $("body").addClass('is-blurred')
  $(window).command 'window:close', => confirmClose()
  $(window).command 'window:reload', => reload()

  $(document).on 'click', 'a', (e) ->
    location = $(e.target).attr('href')
    return unless location
    return if location[0] is '#'

    if location.indexOf('https://') is 0 or location.indexOf('http://') is 0
      require('child_process').spawn('open', [location])
    false

window.handleDragDrop = ->
  $(document).on 'dragover', (e) ->
    e.preventDefault()
    e.stopPropagation()
  $(document).on 'drop', onDrop

window.onDrop = (e) ->
  e.preventDefault()
  e.stopPropagation()
  for file in e.originalEvent.dataTransfer.files
    atom.open(file.path)

window.deserializeEditorWindow = ->
  RootView = require 'root-view'
  Project = require 'project'
  Git = require 'git'

  pathToOpen = atom.getPathToOpen()

  windowState = atom.getWindowState()

  atom.packageStates = windowState.packageStates ? {}
  window.project = deserialize(windowState.project) ? new Project(pathToOpen)
  window.rootView = deserialize(windowState.rootView) ? new RootView

  if !windowState.rootView and (!pathToOpen or fsUtils.isFile(pathToOpen))
    rootView.open(pathToOpen)

  $(rootViewParentSelector).append(rootView)

  window.git = Git.open(project.getPath())
  project.on 'path-changed', ->
    window.git?.destroy()
    window.git = Git.open(project.getPath())

window.deserializeConfigWindow = ->
  ConfigView = require 'config-view'
  windowState = atom.getWindowState()
  window.configView = deserialize(windowState.configView) ? new ConfigView()
  $(rootViewParentSelector).append(configView)

window.stylesheetElementForId = (id) ->
  $("""head style[id="#{id}"]""")

window.resolveStylesheet = (path) ->
  if fsUtils.extension(path).length > 0
    fsUtils.resolveOnLoadPath(path)
  else
    fsUtils.resolveOnLoadPath(path, ['css', 'less'])

window.requireStylesheet = (path) ->
  if fullPath = window.resolveStylesheet(path)
    content = window.loadStylesheet(fullPath)
    window.applyStylesheet(fullPath, content)
  else
    throw new Error("Could not find a file at path '#{path}'")

window.loadStylesheet = (path) ->
  if fsUtils.extension(path) == '.less'
    loadLessStylesheet(path)
  else
    fsUtils.read(path)

window.loadLessStylesheet = (path) ->
  parser = new less.Parser
    syncImport: true
    paths: config.lessSearchPaths
    filename: path
  try
    content = null
    parser.parse fsUtils.read(path), (e, tree) ->
      throw e if e?
      content = tree.toCSS()
    content
  catch e
    console.error """
      Error compiling less stylesheet: #{path}
      Line number: #{e.line}
      #{e.message}
    """

window.removeStylesheet = (path) ->
  unless fullPath = window.resolveStylesheet(path)
    throw new Error("Could not find a file at path '#{path}'")
  window.stylesheetElementForId(fullPath).remove()

window.applyStylesheet = (id, text, ttype = 'bundled') ->
  unless window.stylesheetElementForId(id).length
    if $("head style.#{ttype}").length
      $("head style.#{ttype}:last").after "<style class='#{ttype}' id='#{id}'>#{text}</style>"
    else
      $("head").append "<style class='#{ttype}' id='#{id}'>#{text}</style>"

window.reload = ->
  timesReloaded = process.global.timesReloaded ? 0
  ++timesReloaded

  if timesReloaded > 3
    atom.restartRendererProcess()
  else
    process.global.timesReloaded = timesReloaded
    $native.reload()

window.onerror = ->
  atom.showDevTools()

window.registerDeserializers = (args...) ->
  registerDeserializer(arg) for arg in args

window.registerDeserializer = (klass) ->
  deserializers[klass.name] = klass

window.registerDeferredDeserializer = (name, fn) ->
  deferredDeserializers[name] = fn

window.unregisterDeserializer = (klass) ->
  delete deserializers[klass.name]

window.deserialize = (state) ->
  if deserializer = getDeserializer(state)
    return if deserializer.version? and deserializer.version isnt state.version
    deserializer.deserialize(state)

window.getDeserializer = (state) ->
  name = state?.deserializer
  if deferredDeserializers[name]
    deferredDeserializers[name]()
    delete deferredDeserializers[name]
  deserializers[name]

window.measure = (description, fn) ->
  start = new Date().getTime()
  value = fn()
  result = new Date().getTime() - start
  console.log description, result
  value

window.profile = (description, fn) ->
  measure description, ->
    console.profile(description)
    value = fn()
    console.profileEnd(description)
    value

# Public: Shows a dialog asking if the window was _really_ meant to be closed.
confirmClose = ->
  if rootView?
    rootView.confirmClose().done -> window.close()
  else
    window.close()
