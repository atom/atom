$ = require 'jquery'
_ = require 'underscore'
ipc = require 'ipc'
remote = require 'remote'
Subscriber = require 'subscriber'
fsUtils = require 'fs-utils'

module.exports =
class WindowEventHandler
  constructor: ->
    @subscribe ipc, 'command', (command, args...) ->
      $(document.activeElement).trigger(command, args...)

    @subscribe $(window), 'focus', -> $("body").removeClass('is-blurred')
    @subscribe $(window), 'blur',  -> $("body").addClass('is-blurred')
    @subscribe $(window), 'window:open-path', (event, pathToOpen) ->
      rootView?.open(pathToOpen) unless fsUtils.isDirectorySync(pathToOpen)
    @subscribe $(window), 'beforeunload', -> rootView?.confirmClose()

    @subscribeToCommand $(window), 'window:toggle-full-screen', => atom.toggleFullScreen()
    @subscribeToCommand $(window), 'window:close', => window.close()
    @subscribeToCommand $(window), 'window:reload', => atom.reload()

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
      remote.getCurrentWindow().emit('context-menu', e.pageX, e.pageY)

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

_.extend WindowEventHandler.prototype, Subscriber
