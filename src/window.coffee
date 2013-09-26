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
  #TODO remove once all packages use the atom global
  window.resourcePath = atom.getLoadSettings().resourcePath
  window.config = atom.config
  window.syntax = atom.syntax
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

installAtomCommand = (callback) ->
  commandPath = path.join(window.resourcePath, 'atom.sh')
  require('./command-installer').install(commandPath, callback)

installApmCommand = (callback) ->
  commandPath = path.join(window.resourcePath, 'node_modules', '.bin', 'apm')
  require('./command-installer').install(commandPath, callback)

window.onDrop = (e) ->
  e.preventDefault()
  e.stopPropagation()
  pathsToOpen = _.pluck(e.originalEvent.dataTransfer.files, 'path')
  atom.open({pathsToOpen}) if pathsToOpen.length > 0

window.deserializeEditorWindow = ->
  atom.deserializeEditorWindow()
  #TODO remove once all packages use the atom global
  window.project = atom.project
  window.rootView = atom.rootView

window.getDimensions = -> atom.getDimensions()

window.setDimensions = (args...) -> atom.setDimensions(args...)

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
