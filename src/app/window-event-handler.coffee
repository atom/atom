$ = require 'jquery'
_ = require 'underscore'
ipc = require 'ipc'
Subscriber = require 'subscriber'

module.exports =
class WindowEventHandler
  constructor: ->
    @subscribe ipc, 'command', (command) -> $(window).trigger command

    @subscribe $(window), 'focus', -> $("body").removeClass('is-blurred')
    @subscribe $(window), 'blur',  -> $("body").addClass('is-blurred')
    @subscribeToCommand $(window), 'window:toggle-full-screen', => atom.toggleFullScreen()
    @subscribeToCommand $(window), 'window:close', =>
      if rootView?
        rootView.confirmClose().done -> closeWithoutConfirm()
      else
        closeWithoutConfirm()
    @subscribeToCommand $(window), 'window:reload', => atom.reload()

    @subscribeToCommand $(document), 'core:focus-next', @focusNext
    @subscribeToCommand $(document), 'core:focus-previous', @focusPrevious

    @subscribe $(document), 'keydown', keymap.handleKeyEvent

    @subscribe $(document), 'drop', onDrop
    @subscribe $(document), 'dragover', (e) ->
      e.preventDefault()
      e.stopPropagation()

    @subscribe $(document), 'click', 'a', @openLink

  openLink: (event) =>
    location = $(event.target).attr('href')
    return unless location
    return if location[0] is '#'

    if location.indexOf('https://') is 0 or location.indexOf('http://') is 0
      require('child_process').spawn('open', [location])
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
