fsUtils = require 'fs-utils'
path = require 'path'
$ = require 'jquery'
less = require 'less'
ipc = require 'ipc'
remote = require 'remote'
WindowEventHandler = require 'window-event-handler'
require 'jquery-extensions'
require 'underscore-extensions'
require 'space-pen-extensions'

deserializers = {}
deferredDeserializers = {}
defaultWindowDimensions = {width: 800, height: 600}

### Internal ###

windowEventHandler = null

# This method is called in any window needing a general environment, including specs
window.setUpEnvironment = ->
  window.resourcePath = remote.getCurrentWindow().loadSettings.resourcePath

  Config = require 'config'
  Syntax = require 'syntax'
  Pasteboard = require 'pasteboard'
  Keymap = require 'keymap'

  window.rootViewParentSelector = 'body'
  window.config = new Config
  window.syntax = deserialize(atom.getWindowState('syntax')) ? new Syntax
  window.pasteboard = new Pasteboard
  window.keymap = new Keymap()

  keymap.bindDefaultKeys()

  requireStylesheet 'atom'

  if nativeStylesheetPath = fsUtils.resolveOnLoadPath(process.platform, ['css', 'less'])
    requireStylesheet(nativeStylesheetPath)

# This method is only called when opening a real application window
window.startEditorWindow = ->
  installAtomCommand()
  installApmCommand()

  atom.windowMode = 'editor'
  windowEventHandler = new WindowEventHandler
  restoreDimensions()
  config.load()
  keymap.loadBundledKeymaps()
  atom.loadThemes()
  atom.loadPackages()
  deserializeEditorWindow()
  atom.activatePackages()
  keymap.loadUserKeymaps()
  atom.requireUserInitScript()
  $(window).on 'unload', -> unloadEditorWindow(); false
  atom.show()
  atom.focus()

window.startConfigWindow = ->
  atom.windowMode = 'config'
  restoreDimensions()
  windowEventHandler = new WindowEventHandler
  config.load()
  keymap.loadBundledKeymaps()
  atom.loadThemes()
  atom.loadPackages()
  deserializeConfigWindow()
  atom.activatePackageConfigs()
  keymap.loadUserKeymaps()
  $(window).on 'unload', -> unloadConfigWindow(); false
  atom.show()
  atom.focus()

window.unloadEditorWindow = ->
  return if not project and not rootView
  atom.setWindowState('syntax', syntax.serialize())
  atom.setWindowState('rootView', rootView.serialize())
  atom.deactivatePackages()
  atom.setWindowState('packageStates', atom.packageStates)
  rootView.remove()
  project.destroy()
  git?.destroy()
  windowEventHandler?.unsubscribe()
  window.rootView = null
  window.project = null
  window.git = null

window.installAtomCommand = (callback) ->
  commandPath = path.join(window.resourcePath, 'atom.sh')
  require('command-installer').install(commandPath, callback)

window.installApmCommand = (callback) ->
  commandPath = path.join(window.resourcePath, 'node_modules', '.bin', 'apm')
  require('command-installer').install(commandPath, callback)

window.unloadConfigWindow = ->
  return if not configView
  atom.setWindowState('configView', configView.serialize())
  configView.remove()
  windowEventHandler?.unsubscribe()
  window.configView = null

window.onDrop = (e) ->
  e.preventDefault()
  e.stopPropagation()
  for file in e.originalEvent.dataTransfer.files
    atom.open(file.path)

window.deserializeEditorWindow = ->
  RootView = require 'root-view'
  Project = require 'project'
  Git = require 'git'

  {initialPath} = atom.getLoadSettings()

  windowState = atom.getWindowState()

  atom.packageStates = windowState.packageStates ? {}
  window.project = new Project(initialPath)
  window.rootView = deserialize(windowState.rootView) ? new RootView

  $(rootViewParentSelector).append(rootView)

  window.git = Git.open(project.getPath())
  project.on 'path-changed', ->
    projectPath = project.getPath()
    atom.setPathToOpen(projectPath)

    window.git?.destroy()
    window.git = Git.open(projectPath)

window.deserializeConfigWindow = ->
  ConfigView = require 'config-view'
  windowState = atom.getWindowState()
  window.configView = deserialize(windowState.configView) ? new ConfigView()
  $(rootViewParentSelector).append(configView)

window.stylesheetElementForId = (id) ->
  $("""head style[id="#{id}"]""")

window.resolveStylesheet = (stylesheetPath) ->
  if path.extname(stylesheetPath).length > 0
    fsUtils.resolveOnLoadPath(stylesheetPath)
  else
    fsUtils.resolveOnLoadPath(stylesheetPath, ['css', 'less'])

window.requireStylesheet = (stylesheetPath) ->
  if fullPath = window.resolveStylesheet(stylesheetPath)
    content = window.loadStylesheet(fullPath)
    window.applyStylesheet(fullPath, content)
  else
    throw new Error("Could not find a file at path '#{stylesheetPath}'")

window.loadStylesheet = (stylesheetPath) ->
  if path.extname(stylesheetPath) is '.less'
    loadLessStylesheet(stylesheetPath)
  else
    fsUtils.read(stylesheetPath)

window.loadLessStylesheet = (lessStylesheetPath) ->
  parser = new less.Parser
    syncImport: true
    paths: config.lessSearchPaths
    filename: lessStylesheetPath
  try
    content = null
    parser.parse fsUtils.read(lessStylesheetPath), (e, tree) ->
      throw e if e?
      content = tree.toCSS()
    content
  catch e
    console.error """
      Error compiling less stylesheet: #{lessStylesheetPath}
      Line number: #{e.line}
      #{e.message}
    """

window.removeStylesheet = (stylesheetPath) ->
  unless fullPath = window.resolveStylesheet(stylesheetPath)
    throw new Error("Could not find a file at path '#{stylesheetPath}'")
  window.stylesheetElementForId(fullPath).remove()

window.applyStylesheet = (id, text, ttype = 'bundled') ->
  unless window.stylesheetElementForId(id).length
    if $("head style.#{ttype}").length
      $("head style.#{ttype}:last").after "<style class='#{ttype}' id='#{id}'>#{text}</style>"
    else
      $("head").append "<style class='#{ttype}' id='#{id}'>#{text}</style>"

window.getDimensions = ->
  browserWindow = remote.getCurrentWindow()
  [x, y] = browserWindow.getPosition()
  [width, height] = browserWindow.getSize()
  {x, y, width, height}

window.setDimensions = ({x, y, width, height}) ->
  browserWindow = remote.getCurrentWindow()
  browserWindow.setSize(width, height)
  if x? and y?
    browserWindow.setPosition(x, y)
  else
    browserWindow.center()

window.restoreDimensions = ->
  dimensions = atom.getWindowState('dimensions')
  dimensions = defaultWindowDimensions unless dimensions?.width and dimensions?.height
  window.setDimensions(dimensions)
  $(window).on 'unload', -> atom.setWindowState('dimensions', window.getDimensions())

window.closeWithoutConfirm = ->
  atom.hide()
  ipc.sendChannel 'close-without-confirm'

window.onerror = ->
  atom.openDevTools()

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

window.requireWithGlobals = (id, globals={}) ->
  existingGlobals = {}
  for key, value of globals
    existingGlobals[key] = window[key]
    window[key] = value

  require(id)

  for key, value of existingGlobals
    if value is undefined
      delete window[key]
    else
      window[key] = value

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
