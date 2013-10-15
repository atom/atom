$ = require './jquery-extensions'
_ = require './underscore-extensions'
ipc = require 'ipc'
shell = require 'shell'
{Subscriber} = require 'emissary'
fsUtils = require './fs-utils'

# Private: Handles low-level events related to the window.
module.exports =
class WindowEventHandler
  Subscriber.includeInto(this)

  constructor: ->
    @reloadRequested = false

    @subscribe ipc, 'command', (command, args...) ->
      $(document.activeElement).trigger(command, args...)

    @subscribe ipc, 'context-command', (command, args...) ->
      $(atom.contextMenu.activeElement).trigger(command, args...)

    @subscribe $(window), 'focus', -> $("body").removeClass('is-blurred')

    @subscribe $(window), 'blur',  -> $("body").addClass('is-blurred')

    @subscribe $(window), 'window:open-path', (event, {pathToOpen, initialLine}) ->
      unless fsUtils.isDirectorySync(pathToOpen)
        atom.rootView?.openAsync(pathToOpen, {initialLine})

    @subscribe $(window), 'beforeunload', =>
      confirmed = atom.rootView?.confirmClose()
      atom.hide() if confirmed and not @reloadRequested and atom.getCurrentWindow().isWebViewFocused()
      @reloadRequested = false
      confirmed

    @subscribe $(window), 'unload', ->
      atom.getWindowState().set('dimensions', atom.getDimensions())

    @subscribeToCommand $(window), 'window:toggle-full-screen', => atom.toggleFullScreen()

    @subscribeToCommand $(window), 'window:close', => atom.close()

    @subscribeToCommand $(window), 'window:reload', =>
      @reloadRequested = true
      atom.reload()

    @subscribeToCommand $(window), 'window:toggle-dev-tools', => atom.toggleDevTools()

    @subscribeToCommand $(document), 'core:focus-next', @focusNext

    @subscribeToCommand $(document), 'core:focus-previous', @focusPrevious

    @subscribe $(document), 'keydown', atom.keymap.handleKeyEvent

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

  openLink: (event) =>
    location = $(event.target).attr('href')
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

    (nextElement ? lowestElement).focus()

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

    (previousElement ? highestElement).focus()
