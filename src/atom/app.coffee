Native = require 'native'
GlobalKeymap = require 'global-keymap'
$ = require 'jquery'
_ = require 'underscore'

module.exports =
class App
  globalKeymap: null
  native: null

  constructor: (@loadPath, nativeMethods)->
    @native = new Native(nativeMethods)
    @globalKeymap = new GlobalKeymap
    $(document).on 'keydown', (e) => @globalKeymap.handleKeyEvent(e)

  bindKeys: (selector, bindings) ->
    @globalKeymap.bindKeys(selector, bindings)

  bindKey: (selector, pattern, eventName) ->
    @globalKeymap.bindKey(selector, pattern, eventName)

  open: (url) ->
    @native.open url

  quit: ->
    @native.terminate null

  windows: ->
    #    controller.jsWindow for controller in OSX.NSApp.controllers
    []
