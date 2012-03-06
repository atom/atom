GlobalKeymap = require 'global-keymap'
$ = require 'jquery'
_ = require 'underscore'

module.exports =
class App
  keymap: null
  windows: null
  tabText: null

  constructor: (@loadPath, nativeMethods)->
    @windows = []
    @setupKeymap()
    @tabText = "  "

  setupKeymap: ->
    @keymap = new GlobalKeymap()

    $(document).on 'keydown', (e) => @keymap.handleKeyEvent(e)

  open: (url) ->
    $native.open url

  quit: ->
    $native.terminate null

  windowOpened: (window) ->
    @windows.push window

  windowClosed: (window) ->
    index = @windows.indexOf(window)
    @windows.splice(index, 1) if index >= 0