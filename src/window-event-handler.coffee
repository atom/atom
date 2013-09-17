$ = require 'jquery'
_ = require 'underscore'
ipc = require 'ipc'
remote = require 'remote'
Subscriber = require 'subscriber'
fsUtils = require 'fs-utils'

# Private: Handles low-level events related to the window.
module.exports =
class WindowEventHandler
  _.extend @prototype, Subscriber

  constructor: ->
    @subscribe ipc, 'command', (command, args...) ->
      $(window).trigger(command, args...)

    @subscribe $(window), 'focus', -> $("body").removeClass('is-blurred')
    @subscribe $(window), 'blur',  -> $("body").addClass('is-blurred')
    @subscribe $(window), 'window:open-path', (event, {pathToOpen, initialLine}) ->
      rootView?.open(pathToOpen, {initialLine}) unless fsUtils.isDirectorySync(pathToOpen)
    @subscribe $(window), 'beforeunload', -> rootView?.confirmClose()

    @subscribeToCommand $(window), 'window:toggle-full-screen', => atom.toggleFullScreen()
    @subscribeToCommand $(window), 'window:close', => atom.close()
    @subscribeToCommand $(window), 'window:reload', => atom.reload()
    @subscribeToCommand $(window), 'window:toggle-dev-tools', => atom.toggleDevTools()

    @subscribeToCommand $(document), 'core:focus-next', @focusNext
    @subscribeToCommand $(document), 'core:focus-previous', @focusPrevious

    @subscribe $(document), 'keydown', keymap.handleKeyEvent

    @subscribe $(document), 'drop', onDrop
    @subscribe $(document), 'dragover', (e) ->
      e.preventDefault()
      e.stopPropagation()

    @subscribe $(document), 'click', 'a', @openLink

    @subscribe $(document), 'contextmenu', (e) ->
      e.preventDefault()
      menuTemplate = atom.contextMenuMap.menuTemplateForElement(e.target)

      # FIXME: This should be registered as a dev binding on
      # atom.contextMenuMapping, but I'm not sure where in the source.
      menuTemplate.push({ type: 'separator' })
      menuTemplate.push({ label: 'Inspect Element', click: -> remote.getCurrentWindow().inspectElement(e.pageX, e.pageY) })

      remote.getCurrentWindow().emit('context-menu', menuTemplate)

  openLink: (event) =>
    location = $(event.target).attr('href')
    if location and location[0] isnt '#' and /^https?:\/\//.test(location)
      require('shell').openExternal(location)
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
