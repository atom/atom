EventEmitter = require 'event-emitter'
Native = require 'native'
GlobalKeymap = require 'global-keymap'
$ = require 'jquery'
_ = require 'underscore'

module.exports =
class App
  globalKeymap: null
  native: null
  windows: null

  constructor: (@loadPath, nativeMethods)->
    @globalKeymap = new GlobalKeymap
    @native = new Native(nativeMethods)
    @windows = []

  bindKeys: (selector, bindings) ->
    @globalKeymap.bindKeys(selector, bindings)

  bindKey: (selector, pattern, eventName) ->
    @globalKeymap.bindKey(selector, pattern, eventName)

  open: (url) ->
    @native.open url

  quit: ->
    @native.terminate null

  windowOpened: (window) ->
    @windows.push window
    @trigger "open", window

  windowClosed: (window) ->
    index = @windows.indexOf(window)
    @windows.splice(index, 1) if index >= 0

_.extend(App.prototype, EventEmitter)
