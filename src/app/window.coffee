fs = require 'fs-utils'
$ = require 'jquery'
{less} = require 'less'
{spawn} = require 'child_process'
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
  window.syntax = new Syntax
  window.pasteboard = new Pasteboard
  window.keymap = new Keymap()
  $(document).on 'keydown', keymap.handleKeyEvent
  keymap.bindDefaultKeys()

  requireStylesheet 'reset.less'
  requireStylesheet 'atom.less'
  requireStylesheet 'tabs.less'
  requireStylesheet 'tree-view.less'
  requireStylesheet 'status-bar.less'
  requireStylesheet 'command-panel.less'
  requireStylesheet 'fuzzy-finder.less'
  requireStylesheet 'overlay.less'
  requireStylesheet 'popover-list.less'
  requireStylesheet 'notification.less'
  requireStylesheet 'markdown.less'

  if nativeStylesheetPath = fs.resolveOnLoadPath("#{process.platform}.css")
    requireStylesheet(nativeStylesheetPath)

# This method is only called when opening a real application window
window.startup = ->
  if fs.isDirectory('/opt/boxen')
    installAtomCommand('/opt/boxen/bin/atom')
  else if fs.isDirectory('/opt/github')
    installAtomCommand('/opt/github/bin/atom')
  else if fs.isDirectory('/usr/local')
    installAtomCommand('/usr/local/bin/atom')
  else
    console.warn "Failed to install `atom` binary"

  handleWindowEvents()
  config.load()
  atom.loadTextPackage()
  keymap.loadBundledKeymaps()
  atom.loadThemes()
  atom.loadPackages()
  buildProjectAndRootView()
  atom.activatePackages()
  keymap.loadUserKeymaps()
  atom.requireUserInitScript()
  $(window).on 'beforeunload', -> shutdown(); false
  $(window).focus()

window.shutdown = ->
  return if not project and not rootView
  atom.setWindowState('pathToOpen', project.getPath())
  atom.setRootViewStateForPath project.getPath(),
    project: project.serialize()
    rootView: rootView.serialize()
  rootView.deactivate()
  project.destroy()
  git?.destroy()
  $(window).off('focus blur before')
  window.rootView = null
  window.project = null
  window.git = null

window.installAtomCommand = (commandPath) ->
  return if fs.exists(commandPath)

  bundledCommandPath = fs.resolve(window.resourcePath, 'atom.sh')
  if bundledCommandPath?
    fs.write(commandPath, fs.read(bundledCommandPath))
    spawn("chmod u+x '#{commandPath}'")

window.handleWindowEvents = ->
  $(window).command 'window:toggle-full-screen', => atom.toggleFullScreen()
  $(window).on 'focus', -> $("body").removeClass('is-blurred')
  $(window).on 'blur',  -> $("body").addClass('is-blurred')
  $(window).command 'window:close', => confirmClose()

window.buildProjectAndRootView = ->
  RootView = require 'root-view'
  Project = require 'project'
  Git = require 'git'

  pathToOpen = atom.getPathToOpen()
  windowState = atom.getRootViewStateForPath(pathToOpen) ? {}
  window.project = deserialize(windowState.project) ? new Project(pathToOpen)
  window.rootView = deserialize(windowState.rootView) ? new RootView

  if !windowState.rootView and (!pathToOpen or fs.isFile(pathToOpen))
    rootView.open(pathToOpen)

  $(rootViewParentSelector).append(rootView)

  window.git = Git.open(project.getPath())
  project.on 'path-changed', ->
    window.git?.destroy()
    window.git = Git.open(project.getPath())

window.stylesheetElementForId = (id) ->
  $("head style[id='#{id}']")

window.requireStylesheet = (path) ->
  if fullPath = require.resolve(path)
    content = window.loadStylesheet(fullPath)
    window.applyStylesheet(fullPath, content)
  else
    console.log "bad", path
    throw new Error("Could not find a file at path '#{path}'")

window.loadStylesheet = (path) ->
  content = fs.read(path)
  if fs.extension(path) == '.less'
    (new less.Parser).parse content, (e, tree) ->
      throw new Error(e.message, file, e.line) if e
      content = tree.toCSS()

  content

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
