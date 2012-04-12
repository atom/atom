Keymap = require 'keymap'
fs = require 'fs'

$ = require 'jquery'
_ = require 'underscore'
require 'underscore-extensions'

module.exports =
class Atom
  keymap: null
  windows: null
  userConfigurationPath: null
  rootViewStates: null

  constructor: (@loadPath, nativeMethods)->
    @windows = []
    @setUpKeymap()
    @userConfigurationPath = fs.absolute "~/.atom/atom.coffee"
    @rootViewStates = {}

  setUpKeymap: ->
    @keymap = new Keymap()
    @handleKeyEvent = (e) => @keymap.handleKeyEvent(e)
    $(document).on 'keydown', @handleKeyEvent
    @keymap.bindDefaultKeys()

  open: (path) ->
    $native.open path

  quit: ->
    $native.terminate null

  windowOpened: (window) ->
    @windows.push(window) unless _.contains(@windows, window)

  windowClosed: (window) ->
    _.remove(@windows, window)
