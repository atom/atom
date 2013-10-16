path = require 'path'
{$} = require './space-pen-extensions'
_ = require 'underscore-plus'
ipc = require 'ipc'
WindowEventHandler = require './window-event-handler'

### Internal ###

windowEventHandler = null

# Schedule the window to be shown and focused on the next tick
#
# This is done in a next tick to prevent a white flicker from occurring
# if called synchronously.
displayWindow = ->
  setImmediate ->
    atom.show()
    atom.focus()

# This method is called in any window needing a general environment, including specs
window.setUpEnvironment = (windowMode) ->
  atom.windowMode = windowMode
  window.resourcePath = atom.getLoadSettings().resourcePath
  atom.initialize()
  #TODO remove once all packages use the atom global
  window.config = atom.config
  window.syntax = atom.syntax
  window.pasteboard = atom.pasteboard
  window.keymap = atom.keymap
  window.site = atom.site

# Set up the default event handlers and menus for a non-editor windows.
#
# This can be used by packages to have a minimum level of keybindings and
# menus available when not using the standard editor window.
#
# This should only be called after setUpEnvironment() has been called.
window.setUpDefaultEvents = ->
  windowEventHandler = new WindowEventHandler
  atom.keymap.loadBundledKeymaps()
  atom.menu.update()

# This method is only called when opening a real application window
window.startEditorWindow = ->
  installAtomCommand()
  installApmCommand()

  windowEventHandler = new WindowEventHandler
  restoreDimensions()
  atom.config.load()
  atom.keymap.loadBundledKeymaps()
  atom.themes.loadBaseStylesheets()
  atom.packages.loadPackages()
  atom.themes.load()
  deserializeEditorWindow()
  atom.packages.activatePackages()
  atom.keymap.loadUserKeymaps()
  atom.requireUserInitScript()
  atom.menu.update()
  $(window).on 'unload', ->
    $(document.body).hide()
    unloadEditorWindow()
    false

  displayWindow()

window.unloadEditorWindow = ->
  return if not atom.project and not atom.rootView
  windowState = atom.getWindowState()
  windowState.set('project', atom.project.serialize())
  windowState.set('syntax', atom.syntax.serialize())
  windowState.set('rootView', atom.rootView.serialize())
  atom.packages.deactivatePackages()
  windowState.set('packageStates', atom.packages.packageStates)
  atom.saveWindowState()
  atom.rootView.remove()
  atom.project.destroy()
  windowEventHandler?.unsubscribe()
  window.rootView = null
  window.project = null

installAtomCommand = (callback) ->
  commandPath = path.join(window.resourcePath, 'atom.sh')
  require('./command-installer').install(commandPath, callback)

installApmCommand = (callback) ->
  commandPath = path.join(window.resourcePath, 'node_modules', '.bin', 'apm')
  require('./command-installer').install(commandPath, callback)

window.deserializeEditorWindow = ->
  atom.deserializePackageStates()
  atom.deserializeProject()
  window.project = atom.project
  atom.deserializeRootView()
  window.rootView = atom.rootView

window.getDimensions = -> atom.getDimensions()

window.setDimensions = (args...) -> atom.setDimensions(args...)

window.restoreDimensions = (args...) -> atom.restoreDimensions(args...)

window.onerror = ->
  atom.openDevTools()

window.registerDeserializers = (args...) ->
  atom.deserializers.add(args...)
window.registerDeserializer = (args...) ->
  atom.deserializers.add(args...)
window.registerDeferredDeserializer = (args...) ->
  atom.deserializers.addDeferred(args...)
window.unregisterDeserializer = (args...) ->
  atom.deserializers.remove(args...)
window.deserialize = (args...) ->
  atom.deserializers.deserialize(args...)
window.getDeserializer = (args...) ->
  atom.deserializers.get(args...)
window.requireWithGlobals = (args...) ->
  atom.requireWithGlobals(args...)

# Public: Measure how long a function takes to run.
#
# * description:
#   A String description that will be logged to the console.
# * fn:
#   A Function to measure the duration of.
#
# Returns the value returned by the given function.
window.measure = (description, fn) ->
  start = new Date().getTime()
  value = fn()
  result = new Date().getTime() - start
  console.log description, result
  value

# Public: Create a dev tools profile for a function.
#
# * description:
#   A String descrption that will be available in the Profiles tab of the dev
#   tools.
# * fn:
#   A Function to profile.
#
# Return the value returned by the given function.
window.profile = (description, fn) ->
  measure description, ->
    console.profile(description)
    value = fn()
    console.profileEnd(description)
    value
