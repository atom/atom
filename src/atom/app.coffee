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

  windowOpened: (window) ->
    @windows.push window

  windowClosed: (window) ->
    _.remove(@windows, window)
