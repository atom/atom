Keymap = require 'keymap'
$ = require 'jquery'
_ = require 'underscore'
require 'underscore-extensions'

module.exports =
class App
  keymap: null
  windows: null
  tabText: null

  constructor: (@loadPath, nativeMethods)->
    @windows = []
    @setUpKeymap()
    @tabText = "  "

  setUpKeymap: ->
    @keymap = new Keymap()
    $(document).on 'keydown', (e) => @keymap.handleKeyEvent(e)
    @keymap.bindDefaultKeys()

  open: (url) ->
    $native.open url

  quit: ->
    $native.terminate null

  windowIdCounter: 1

  windowOpened: (window) ->
    id = @windowIdCounter++
    console.log "window opened! #{id}"
    window.id = id
    @windows.push window

  windowClosed: (window) ->
    console.log "windowClosed #{window.id}"
    console.log "windows length before #{@windows.length}"
    _.remove(@windows, window)
    console.log "windows length after #{@windows.length}"
