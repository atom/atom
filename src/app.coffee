_ = require 'underscore'
Window = require 'window'

module.exports =
class App
  @windows: []

  @root: OSX.NSBundle.mainBundle.resourcePath

  @activeWindow: null

  @setup: ->
    @setActiveWindow new Window
      controller : WindowController
      path : localStorage.lastOpenedPath

    @activeWindow.loadPlugins()

  @setActiveWindow: (window) ->
    @activeWindow = window
    @windows.push window if window not in @windows
