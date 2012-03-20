Keymap = require 'keymap'
fs = require 'fs'

$ = require 'jquery'
_ = require 'underscore'
require 'underscore-extensions'

module.exports =
class App
  keymap: null
  windows: null
  tabText: null
  userConfigurationPath: null

  constructor: (@loadPath, nativeMethods)->
    @windows = []
    @setUpKeymap()
    @tabText = "  "
    @userConfigurationPath = fs.absolute "~/.atom/atom.coffee"

  setUpKeymap: ->
    @keymap = new Keymap()
    @handleKeyEvent = (e) => @keymap.handleKeyEvent(e)
    $(document).on 'keydown', @handleKeyEvent
    @keymap.bindDefaultKeys()

  destroy: ->
    $(document).off 'keydown', @handleKeyEvent
    @keymap.unbindDefaultKeys()

  open: (url) ->
    $native.open url

  quit: ->
    $native.terminate null

  windowOpened: (window) ->
    @windows.push(window) unless _.contains(@windows, window)

  windowClosed: (window) ->
    _.remove(@windows, window)
