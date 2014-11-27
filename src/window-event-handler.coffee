path = require 'path'
{$} = require './space-pen-extensions'
_ = require 'underscore-plus'
ipc = require 'ipc'
shell = require 'shell'
{Subscriber} = require 'emissary'
fs = require 'fs-plus'

# Handles low-level events related to the window.
module.exports =
class WindowEventHandler
  Subscriber.includeInto(this)

  constructor: ->
    @reloadRequested = false

    @subscribe ipc, 'message', (message, detail) ->
      switch message
        when 'open-path'
          {pathToOpen, initialLine, initialColumn} = detail

          unless atom.project?.getPaths().length
            if fs.existsSync(pathToOpen) or fs.existsSync(path.dirname(pathToOpen))
              atom.project?.setPaths([pathToOpen])

          unless fs.isDirectorySync(pathToOpen)
            atom.workspace?.open(pathToOpen, {initialLine, initialColumn})

        when 'update-available'
          atom.updateAvailable(detail)

          # FIXME: Remove this when deprecations are removed
          {releaseVersion, releaseNotes} = detail
          detail = [releaseVersion, releaseNotes]
          atom.commands.dispatch atom.views.getView(atom.workspace), "window:update-available", detail

    @subscribe ipc, 'command', (command, args...) ->
      activeElement = document.activeElement
      # Use the workspace element view if body has focus
      if activeElement is document.body and workspaceElement = atom.views.getView(atom.workspace)
        activeElement = workspaceElement

      atom.commands.dispatch(activeElement, command, args[0])

    @subscribe ipc, 'context-command', (command, args...) ->
      $(atom.contextMenu.activeElement).trigger(command, args...)

    @subscribe $(window), 'focus', -> document.body.classList.remove('is-blurred')

    @subscribe $(window), 'blur', -> document.body.classList.add('is-blurred')

    @subscribe $(window), 'beforeunload', =>
      confirmed = atom.workspace?.confirmClose()
      atom.hide() if confirmed and not @reloadRequested and atom.getCurrentWindow().isWebViewFocused()
      @reloadRequested = false

      atom.storeDefaultWindowDimensions()
      atom.storeWindowDimensions()
      atom.unloadEditorWindow() if confirmed

      confirmed

    @subscribe $(window), 'blur', -> atom.storeDefaultWindowDimensions()

    @subscribe $(window), 'unload', -> atom.removeEditorWindow()

    @subscribeToCommand $(window), 'window:toggle-full-screen', -> atom.toggleFullScreen()

    @subscribeToCommand $(window), 'window:close', -> atom.close()

    @subscribeToCommand $(window), 'window:reload', =>
      @reloadRequested = true
      atom.reload()

    @subscribeToCommand $(window), 'window:toggle-dev-tools', -> atom.toggleDevTools()

    if process.platform in ['win32', 'linux']
      @subscribeToCommand $(window), 'window:toggle-menu-bar', ->
        atom.config.set('core.autoHideMenuBar', !atom.config.get('core.autoHideMenuBar'))

    @subscribeToCommand $(document), 'core:focus-next', @focusNext

    @subscribeToCommand $(document), 'core:focus-previous', @focusPrevious

    document.addEventListener 'keydown', @onKeydown

    @subscribe $(document), 'drop', (e) ->
      e.preventDefault()
      e.stopPropagation()
      pathsToOpen = _.pluck(e.originalEvent.dataTransfer.files, 'path')
      atom.open({pathsToOpen}) if pathsToOpen.length > 0

    @subscribe $(document), 'dragover', (e) ->
      e.preventDefault()
      e.stopPropagation()

    @subscribe $(document), 'click', 'a', @openLink

    @subscribe $(document), 'contextmenu', (e) ->
      e.preventDefault()
      atom.contextMenu.showForEvent(e)

    @handleNativeKeybindings()

  # Wire commands that should be handled by the native menu
  # for elements with the `.native-key-bindings` class.
  handleNativeKeybindings: ->
    menu = null
    bindCommandToAction = (command, action) =>
      @subscribe $(document), command, (event) ->
        if event.target.webkitMatchesSelector('.native-key-bindings')
          menu ?= require('remote').require('menu')
          menu.sendActionToFirstResponder(action)
        true

    bindCommandToAction('core:copy', 'copy:')
    bindCommandToAction('core:paste', 'paste:')
    bindCommandToAction('core:undo', 'undo:')
    bindCommandToAction('core:redo', 'redo:')
    bindCommandToAction('core:select-all', 'selectAll:')

  onKeydown: (event) ->
    atom.keymaps.handleKeyboardEvent(event)
    event.stopImmediatePropagation()

  openLink: ({target, currentTarget}) ->
    location = target?.getAttribute('href') or currentTarget?.getAttribute('href')
    if location and location[0] isnt '#' and /^https?:\/\//.test(location)
      shell.openExternal(location)
    false

  eachTabIndexedElement: (callback) ->
    for element in $('[tabindex]')
      element = $(element)
      continue if element.isDisabled()

      tabIndex = parseInt(element.attr('tabindex'))
      continue unless tabIndex >= 0

      callback(element, tabIndex)

  focusNext: =>
    focusedTabIndex = parseInt($(':focus').attr('tabindex')) or -Infinity

    nextElement = null
    nextTabIndex = Infinity
    lowestElement = null
    lowestTabIndex = Infinity
    @eachTabIndexedElement (element, tabIndex) ->
      if tabIndex < lowestTabIndex
        lowestTabIndex = tabIndex
        lowestElement = element

      if focusedTabIndex < tabIndex < nextTabIndex
        nextTabIndex = tabIndex
        nextElement = element

    if nextElement?
      nextElement.focus()
    else if lowestElement?
      lowestElement.focus()

  focusPrevious: =>
    focusedTabIndex = parseInt($(':focus').attr('tabindex')) or Infinity

    previousElement = null
    previousTabIndex = -Infinity
    highestElement = null
    highestTabIndex = -Infinity
    @eachTabIndexedElement (element, tabIndex) ->
      if tabIndex > highestTabIndex
        highestTabIndex = tabIndex
        highestElement = element

      if focusedTabIndex > tabIndex > previousTabIndex
        previousTabIndex = tabIndex
        previousElement = element

    if previousElement?
      previousElement.focus()
    else if highestElement?
      highestElement.focus()
