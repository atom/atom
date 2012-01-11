Native = require 'native'

module.exports =
class App
  native: null

  constructor: ->
    @native = new Native

  bindKeys: (selector, bindings) ->
    window.rootView.bindKeys(selector, bindings)

  open: (url) ->
    OSX.NSApp.open url

  quit: ->
    OSX.NSApp.terminate null

  windows: ->
    controller.jsWindow for controller in OSX.NSApp.controllers
