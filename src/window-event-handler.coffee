path = require 'path'
{$} = require './space-pen-extensions'
{Disposable} = require 'event-kit'
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
        when 'open-locations'
          needsProjectPaths = atom.project?.getPaths().length is 0

          for {pathToOpen, initialLine, initialColumn} in detail
            if pathToOpen? and needsProjectPaths
              if fs.existsSync(pathToOpen)
                atom.project.addPath(pathToOpen)
              else if fs.existsSync(path.dirname(pathToOpen))
                atom.project.addPath(path.dirname(pathToOpen))
              else
                atom.project.addPath(pathToOpen)

            unless fs.isDirectorySync(pathToOpen)
              atom.workspace?.open(pathToOpen, {initialLine, initialColumn})

          return

        when 'update-available'
          atom.updateAvailable(detail)

          # FIXME: Remove this when deprecations are removed
          {releaseVersion} = detail
          detail = [releaseVersion]
          if workspaceElement = atom.views.getView(atom.workspace)
            atom.commands.dispatch workspaceElement, "window:update-available", detail

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
      confirmed = atom.workspace?.confirmClose(windowCloseRequested: true)
      atom.hide() if confirmed and not @reloadRequested and atom.getCurrentWindow().isWebViewFocused()
      @reloadRequested = false

      atom.storeDefaultWindowDimensions()
      atom.storeWindowDimensions()
      if confirmed
        atom.unloadEditorWindow()
      else
        ipc.send('cancel-window-close')

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
        atom.config.set('core.autoHideMenuBar', not atom.config.get('core.autoHideMenuBar'))

        if atom.config.get('core.autoHideMenuBar')
          detail = "To toggle, press the Alt key or execute the window:toggle-menu-bar command"
          atom.notifications.addInfo('Menu bar hidden', {detail})

    @subscribeToCommand $(document), 'core:focus-next', @focusNext

    @subscribeToCommand $(document), 'core:focus-previous', @focusPrevious

    document.addEventListener 'keydown', @onKeydown

    document.addEventListener 'drop', @onDrop
    @subscribe new Disposable =>
      document.removeEventListener('drop', @onDrop)

    document.addEventListener 'dragover', @onDragOver
    @subscribe new Disposable =>
      document.removeEventListener('dragover', @onDragOver)

    @subscribe $(document), 'click', 'a', @openLink

    # Prevent form submits from changing the current window's URL
    @subscribe $(document), 'submit', 'form', (e) -> e.preventDefault()

    @subscribe $(document), 'contextmenu', (e) ->
      e.preventDefault()
      atom.contextMenu.showForEvent(e)

    @handleNativeKeybindings()

  # Wire commands that should be handled by Chromium for elements with the
  # `.native-key-bindings` class.
  handleNativeKeybindings: ->
    menu = null
    bindCommandToAction = (command, action) =>
      @subscribe $(document), command, (event) ->
        if event.target.webkitMatchesSelector('.native-key-bindings')
          atom.getCurrentWindow().webContents[action]()
        true

    bindCommandToAction('core:copy', 'copy')
    bindCommandToAction('core:paste', 'paste')
    bindCommandToAction('core:undo', 'undo')
    bindCommandToAction('core:redo', 'redo')
    bindCommandToAction('core:select-all', 'selectAll')
    bindCommandToAction('core:cut', 'cut')

  onKeydown: (event) ->
    atom.keymaps.handleKeyboardEvent(event)
    event.stopImmediatePropagation()

  onDrop: (event) ->
    event.preventDefault()
    event.stopPropagation()

  onDragOver: (event) ->
    event.preventDefault()
    event.stopPropagation()
    event.dataTransfer.dropEffect = 'none'

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
    return

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
