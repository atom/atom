path = require 'path'
{Disposable, CompositeDisposable} = require 'event-kit'
ipc = require 'ipc'
shell = require 'shell'
fs = require 'fs-plus'
listen = require './delegated-listener'

# Handles low-level events related to the window.
module.exports =
class WindowEventHandler
  constructor: (@atomEnv) ->
    @reloadRequested = false
    @subscriptions = new CompositeDisposable

    @on(ipc, 'message', @handleIPCMessage)
    @on(ipc, 'command', @handleIPCCommand)
    @on(ipc, 'context-command', @handleIPCContextCommand)

    @addEventListener(window, 'focus', @handleWindowFocus)
    @addEventListener(window, 'blur', @handleWindowBlur)
    @addEventListener(window, 'beforeunload', @handleWindowBeforeunload)
    @addEventListener(window, 'unload', @handleWindowUnload)

    @addEventListener(document, 'keydown', @handleDocumentKeydown)
    @addEventListener(document, 'drop', @handleDocumentDrop)
    @addEventListener(document, 'dragover', @handleDocumentDragover)
    @addEventListener(document, 'contextmenu', @handleDocumentContextmenu)
    @subscriptions.add listen(document, 'click', 'a', @handleLinkClick)
    @subscriptions.add listen(document, 'submit', 'form', @handleFormSubmit)

    @subscriptions.add @atomEnv.commands.add window,
      'window:toggle-full-screen': @handleWindowToggleFullScreen
      'window:close': @handleWindowClose
      'window:reload': @handleWindowReload
      'window:toggle-dev-tools': @handleWindowToggleDevTools

    if process.platform in ['win32', 'linux']
      @subscriptions.add @atomEnv.commands.add window,
        'window:toggle-menu-bar': @handleWindowToggleMenuBar

    @subscriptions.add @atomEnv.commands.add document,
      'core:focus-next': @handleFocusNext
      'core:focus-previous': @handleFocusPrevious

    @handleNativeKeybindings()

  # Wire commands that should be handled by Chromium for elements with the
  # `.native-key-bindings` class.
  handleNativeKeybindings: ->
    bindCommandToAction = (command, action) =>
      @addEventListener document, command, (event) =>
        if event.target.webkitMatchesSelector('.native-key-bindings')
          @atomEnv.getCurrentWindow().webContents[action]()

    bindCommandToAction('core:copy', 'copy')
    bindCommandToAction('core:paste', 'paste')
    bindCommandToAction('core:undo', 'undo')
    bindCommandToAction('core:redo', 'redo')
    bindCommandToAction('core:select-all', 'selectAll')
    bindCommandToAction('core:cut', 'cut')

  unsubscribe: ->
    @subscriptions.dispose()

  on: (target, eventName, handler) ->
    target.on(eventName, handler)
    @subscriptions.add(new Disposable ->
      target.removeListener(eventName, handler)
    )

  addEventListener: (target, eventName, handler) ->
    target.addEventListener(eventName, handler)
    @subscriptions.add(new Disposable(-> target.removeEventListener(eventName, handler)))

  handleDocumentKeydown: (event) =>
    @atomEnv.keymaps.handleKeyboardEvent(event)
    event.stopImmediatePropagation()

  handleDrop: (event) ->
    event.preventDefault()
    event.stopPropagation()

  handleDragover: (event) ->
    event.preventDefault()
    event.stopPropagation()
    event.dataTransfer.dropEffect = 'none'

  eachTabIndexedElement: (callback) ->
    for element in document.querySelectorAll('[tabindex]')
      continue if element.disabled
      continue unless element.tabIndex >= 0
      callback(element, element.tabIndex)
    return

  handleFocusNext: =>
    focusedTabIndex = document.activeElement.tabIndex ? -Infinity

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

  handleFocusPrevious: =>
    focusedTabIndex = document.activeElement.tabIndex ? Infinity

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

  handleIPCMessage: (message, detail) =>
    switch message
      when 'open-locations'
        needsProjectPaths = @atomEnv.project?.getPaths().length is 0

        for {pathToOpen, initialLine, initialColumn} in detail
          if pathToOpen? and needsProjectPaths
            if fs.existsSync(pathToOpen)
              @atomEnv.project.addPath(pathToOpen)
            else if fs.existsSync(path.dirname(pathToOpen))
              @atomEnv.project.addPath(path.dirname(pathToOpen))
            else
              @atomEnv.project.addPath(pathToOpen)

          unless fs.isDirectorySync(pathToOpen)
            @atomEnv.workspace?.open(pathToOpen, {initialLine, initialColumn})
        return
      when 'update-available'
        @atomEnv.updateAvailable(detail)

  handleIPCCommand: (command, args...) =>
    activeElement = document.activeElement
    # Use the workspace element view if body has focus
    if activeElement is document.body and workspaceElement = @atomEnv.views.getView(@atomEnv.workspace)
      activeElement = workspaceElement

    @atomEnv.commands.dispatch(activeElement, command, args[0])

  handleIPCContextCommand: (command, args...) =>
    @atomEnv.commands.dispatch(@atomEnv.contextMenu.activeElement, command, args)

  handleWindowFocus: ->
    document.body.classList.remove('is-blurred')

  handleWindowBlur: =>
    document.body.classList.add('is-blurred')
    @atomEnv.storeDefaultWindowDimensions()

  handleWindowBeforeunload: =>
    confirmed = @atomEnv.workspace?.confirmClose(windowCloseRequested: true)
    @atomEnv.hide() if confirmed and not @reloadRequested and @atomEnv.getCurrentWindow().isWebViewFocused()
    @reloadRequested = false

    @atomEnv.storeDefaultWindowDimensions()
    @atomEnv.storeWindowDimensions()
    if confirmed
      @atomEnv.unloadEditorWindow()
    else
      ipc.send('cancel-window-close')

    confirmed

  handleWindowUnload: =>
    @atomEnv.removeEditorWindow()

  handleWindowToggleFullScreen: =>
    @atomEnv.toggleFullScreen()

  handleWindowClose: =>
    @atomEnv.close()

  handleWindowReload: =>
    @reloadRequested = true
    @atomEnv.reload()

  handleWindowToggleDevTools: =>
    @atomEnv.toggleDevTools()

  handleWindowToggleMenuBar: =>
    @atomEnv.config.set('core.autoHideMenuBar', not @atomEnv.config.get('core.autoHideMenuBar'))

    if @atomEnv.config.get('core.autoHideMenuBar')
      detail = "To toggle, press the Alt key or execute the window:toggle-menu-bar command"
      @atomEnv.notifications.addInfo('Menu bar hidden', {detail})

  handleLinkClick: (event) ->
    event.preventDefault()
    location = event.currentTarget?.getAttribute('href')
    if location and location[0] isnt '#' and /^https?:\/\//.test(location)
      shell.openExternal(location)

  handleFormSubmit: (event) ->
    # Prevent form submits from changing the current window's URL
    event.preventDefault()

  handleDocumentContextmenu: (event) =>
    event.preventDefault()
    @atomEnv.contextMenu.showForEvent(event)
