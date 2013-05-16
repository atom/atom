$ = require 'jquery'
_ = require 'underscore'
Subscriber = require 'subscriber'

module.exports =
class WindowEventHandler
  constructor: ->
    @subscribe $(window), 'focus', -> $("body").removeClass('is-blurred')
    @subscribe $(window), 'blur',  -> $("body").addClass('is-blurred')
    @subscribeToCommand $(window), 'window:toggle-full-screen', => atom.toggleFullScreen()
    @subscribeToCommand $(window), 'window:close', =>
      if rootView?
        rootView.confirmClose().done -> window.close()
      else
        window.close()
    @subscribeToCommand $(window), 'window:reload', => reload()

    @subscribe $(document), 'keydown', keymap.handleKeyEvent

    @subscribe $(document), 'drop', onDrop
    @subscribe $(document), 'dragover', (e) ->
      e.preventDefault()
      e.stopPropagation()

    @subscribe $(document), 'click', 'a', (e) ->
      location = $(e.target).attr('href')
      return unless location
      return if location[0] is '#'

      if location.indexOf('https://') is 0 or location.indexOf('http://') is 0
        require('child_process').spawn('open', [location])
      false

_.extend WindowEventHandler.prototype, Subscriber
