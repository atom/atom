Native = require 'native'
KeyBinder = require 'key-binder'

module.exports =
class App
  native: null
  keyBinder: null

  constructor: ->
    @native = new Native
    @keyBinder = new KeyBinder

  open: (url) ->
    OSX.NSApp.open url

  quit: ->
    OSX.NSApp.terminate null

  windows: ->
    controller.jsWindow for controller in OSX.NSApp.controllers
