Native = require 'native'
GlobalKeymap = require 'global-keymap'
$ = require 'jquery'

module.exports =
class App
  globalKeymap: null
  native: null

  constructor: ->
    @native = new Native
    @globalKeymap = new GlobalKeymap
    $(document).on 'keydown', (e) => console.log e; @globalKeymap.handleKeyEvent(e)

  bindKeys: (selector, bindings) ->
    @globalKeymap.bindKeys(selector, bindings)

  open: (url) ->
    OSX.NSApp.open url

  quit: ->
    OSX.NSApp.terminate null

  windows: ->
    controller.jsWindow for controller in OSX.NSApp.controllers
