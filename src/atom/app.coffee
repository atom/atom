Native = require 'native'
$ = require 'jquery'
_ = require 'underscore'

module.exports =
class App
  native: null
  windows: null

  constructor: (@loadPath, nativeMethods)->
    @native = new Native(nativeMethods)
    @windows = []

  open: (url) ->
    @native.open url

  quit: ->
    @native.terminate null

  windowOpened: (window) ->
    @windows.push window

  windowClosed: (window) ->
    index = @windows.indexOf(window)
    @windows.splice(index, 1) if index >= 0