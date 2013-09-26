fsUtils = require './fs-utils'
path = require 'path'
telepath = require 'telepath'
$ = require './jquery-extensions'
_ = require './underscore-extensions'
remote = require 'remote'
ipc = require 'ipc'
WindowEventHandler = require './window-event-handler'

deserializers = {}
deferredDeserializers = {}
defaultWindowDimensions = {width: 800, height: 600}

### Internal ###

windowEventHandler = null

# Schedule the window to be shown and focused on the next tick
#
# This is done in a next tick to prevent a white flicker from occurring
# if called synchronously.
displayWindow = ->
  _.nextTick ->
    atom.show()
    atom.focus()

# This method is called in any window needing a general environment, including specs
window.setUpEnvironment = (windowMode) ->
  atom.windowMode = windowMode
  window.resourcePath = atom.getLoadSettings().resourcePath

  Syntax = require './syntax'

  window.rootViewParentSelector = 'body'
  window.config = atom.config
  window.syntax = deserialize(atom.getWindowState('syntax')) ? new Syntax
  window.pasteboard = atom.pasteboard
  window.keymap = atom.keymap


# Set up the default event handlers and menus for a non-editor windows.
#
# This can be used by packages to have a minimum level of keybindings and
# menus available when not using the standard editor window.
#
# This should only be called after setUpEnvironment() has been called.
window.setUpDefaultEvents = ->
  windowEventHandler = new WindowEventHandler
  keymap.loadBundledKeymaps()
  ipc.sendChannel 'update-application-menu', keymap.keystrokesByCommandForSelector('body')

# This method is only called when opening a real application window
window.startEditorWindow = ->
  installAtomCommand()
  installApmCommand()

  windowEventHandler = new WindowEventHandler
  restoreDimensions()
  config.load()
  keymap.loadBundledKeymaps()
  atom.themes.loadBaseStylesheets()
  atom.loadPackages()
  atom.loadThemes()
  deserializeEditorWindow()
  atom.activatePackages()
  keymap.loadUserKeymaps()
  atom.requireUserInitScript()
  ipc.sendChannel 'update-application-menu', keymap.keystrokesByCommandForSelector('body')
  $(window).on 'unload', ->
    $(document.body).hide()
    unloadEditorWindow()
    false

  displayWindow()

window.unloadEditorWindow = ->
  return if not project and not rootView
  windowState = atom.getWindowState()
  windowState.set('project', project.serialize())
  windowState.set('syntax', syntax.serialize())
  windowState.set('rootView', rootView.serialize())
  atom.deactivatePackages()
  windowState.set('packageStates', atom.packageStates)
  atom.saveWindowState()
  rootView.remove()
  project.destroy()
  windowEventHandler?.unsubscribe()
  lessCache?.destroy()
  window.rootView = null
  window.project = null

window.installAtomCommand = (callback) ->
  commandPath = path.join(window.resourcePath, 'atom.sh')
  require('./command-installer').install(commandPath, callback)

window.installApmCommand = (callback) ->
  commandPath = path.join(window.resourcePath, 'node_modules', '.bin', 'apm')
  require('./command-installer').install(commandPath, callback)

window.onDrop = (e) ->
  e.preventDefault()
  e.stopPropagation()
  pathsToOpen = _.pluck(e.originalEvent.dataTransfer.files, 'path')
  atom.open({pathsToOpen}) if pathsToOpen.length > 0

window.deserializeEditorWindow = ->
  RootView = require './root-view'
  Project = require './project'

  windowState = atom.getWindowState()

  atom.packageStates = windowState.getObject('packageStates') ? {}
  windowState.remove('packageStates')

  window.project = deserialize(windowState.get('project'))
  unless window.project?
    window.project = new Project(atom.getLoadSettings().initialPath)
    windowState.set('project', window.project.getState())

  window.rootView = deserialize(windowState.get('rootView'))
  unless window.rootView?
    window.rootView = new RootView()
    windowState.set('rootView', window.rootView.getState())

  $(rootViewParentSelector).append(rootView)

  project.on 'path-changed', ->
    projectPath = project.getPath()
    atom.getLoadSettings().initialPath = projectPath

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
  dimensions = atom.getWindowState().getObject('dimensions')
  dimensions = defaultWindowDimensions unless dimensions?.width and dimensions?.height
  window.setDimensions(dimensions)
  $(window).on 'unload', -> atom.getWindowState().set('dimensions', window.getDimensions())

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

window.deserialize = (state, params) ->
  return unless state?
  if deserializer = getDeserializer(state)
    stateVersion = state.get?('version') ? state.version
    return if deserializer.version? and deserializer.version isnt stateVersion
    if (state instanceof telepath.Document) and not deserializer.acceptsDocuments
      state = state.toObject()
    deserializer.deserialize(state, params)
  else
    console.warn "No deserializer found for", state

window.getDeserializer = (state) ->
  return unless state?

  name = state.get?('deserializer') ? state.deserializer
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
