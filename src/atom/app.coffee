Native = require 'native'

module.exports =
class App
  native: null

  constructor: ->
    @native = new Native

  open: (url) ->
    OSX.NSApp.open url

  quit: ->
    OSX.NSApp.terminate null

  windows: ->
    controller.jsWindow for controller in OSX.NSApp.controllers
