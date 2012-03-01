Native = require 'native'
GlobalKeymap = require 'global-keymap'
$ = require 'jquery'
_ = require 'underscore'

module.exports =
class App
  keymap: null
  native: null
  windows: null

  constructor: (@loadPath, nativeMethods)->
    @native = new Native(nativeMethods)
    @windows = []

    @setupKeymap()

  setupKeymap: ->
    @keymap = new GlobalKeymap()
    @keymap.bindKeys "*",
      'meta-o': 'open'

    $(document).on 'open', => 
      url = @native.openDialog()
      @open(url) if url
    $(document).on 'keydown', (e) => @keymap.handleKeyEvent(e)

  open: (url) ->
    @native.open url

  quit: ->
    @native.terminate null

  windowOpened: (window) ->
    @windows.push window

  windowClosed: (window) ->
    index = @windows.indexOf(window)
    @windows.splice(index, 1) if index >= 0