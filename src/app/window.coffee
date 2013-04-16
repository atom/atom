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
window.startup = ->
  directory = _.find ['/opt/boxen', '/opt/github', '/usr/local'], (dir) -> fsUtils.isDirectory(dir)
  if directory
    installAtomCommand(fsUtils.join(directory, 'bin/atom'))
  else
    console.warn "Failed to install `atom` binary"

  handleWindowEvents()
  handleDragDrop()
  config.load()
  keymap.loadBundledKeymaps()
  atom.loadThemes()
  atom.loadPackages()
  deserializeWindowState()
  atom.activatePackages()
  keymap.loadUserKeymaps()
  atom.requireUserInitScript()
  $(window).on 'beforeunload', -> shutdown(); false
  $(window).focus()

window.shutdown = ->
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

window.installAtomCommand = (commandPath) ->
  return if fsUtils.exists(commandPath)

  bundledCommandPath = fsUtils.resolve(window.resourcePath, 'atom.sh')
  if bundledCommandPath?
    fsUtils.write(commandPath, fsUtils.read(bundledCommandPath))
    fs.chmod(commandPath, 0o755, commandPath)

window.handleWindowEvents = ->
  $(window).command 'window:toggle-full-screen', => atom.toggleFullScreen()
  $(window).on 'focus', -> $("body").removeClass('is-blurred')
  $(window).on 'blur',  -> $("body").addClass('is-blurred')
  $(window).command 'window:close', => confirmClose()
  $(window).command 'window:reload', => reload()

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

window.deserializeWindowState = ->
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

window.stylesheetElementForId = (id) ->
  $("head style[id='#{id}']")

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
  content = fsUtils.read(path)
  if fsUtils.extension(path) == '.less'
    parser = new less.Parser
      syncImport: true
      paths: config.lessSearchPaths
      filename: path

    parser.parse content, (e, tree) ->
      throw new Error(e.message, path, e.line) if e
      content = tree.toCSS()

  content

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

confirmClose = ->
  rootView.confirmClose().done -> window.close()
