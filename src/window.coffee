path = require 'path'
{$} = require './space-pen-extensions'
WindowEventHandler = require './window-event-handler'

### Internal ###

windowEventHandler = null

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
  if process.platform is 'darwin'
    installAtomCommand()
    installApmCommand()

  windowEventHandler = new WindowEventHandler
  atom.restoreDimensions()
  atom.config.load()
  atom.config.setDefaults('core', require('./root-view').configDefaults)
  atom.config.setDefaults('editor', require('./editor-view').configDefaults)
  atom.keymap.loadBundledKeymaps()
  atom.themes.loadBaseStylesheets()
  atom.packages.loadPackages()
  atom.deserializeEditorWindow()
  atom.packages.activate()
  atom.keymap.loadUserKeymap()
  atom.requireUserInitScript()
  atom.menu.update()
  $(window).on 'unload', ->
    $(document.body).hide()
    unloadEditorWindow()
    false

  atom.displayWindow()

window.unloadEditorWindow = ->
  return if not atom.project and not atom.rootView
  windowState = atom.getWindowState()
  windowState.set('project', atom.project)
  windowState.set('syntax', atom.syntax.serialize())
  windowState.set('rootView', atom.rootView.serialize())
  atom.packages.deactivatePackages()
  windowState.set('packageStates', atom.packages.packageStates)
  atom.saveWindowState()
  atom.rootView.remove()
  atom.project.destroy()
  windowEventHandler?.unsubscribe()

installAtomCommand = (callback) ->
  {resourcePath} = atom.getLoadSettings()
  commandPath = path.join(resourcePath, 'atom.sh')
  require('./command-installer').install(commandPath, callback)

installApmCommand = (callback) ->
  {resourcePath} = atom.getLoadSettings()
  commandPath = path.join(resourcePath, 'node_modules', '.bin', 'apm')
  require('./command-installer').install(commandPath, callback)

window.onerror = ->
  atom.openDevTools()

# Public: Measure how long a function takes to run.
#
# * description:
#   A String description that will be logged to the console.
# * fn:
#   A Function to measure the duration of.
#
# Returns the value returned by the given function.
window.measure = (description, fn) ->
  start = Date.now()
  value = fn()
  result = Date.now() - start
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
