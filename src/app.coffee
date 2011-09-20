_ = require 'underscore'
Window = require 'window'
Plugins = require 'plugins'

module.exports =
class App
  @windows: []
  
  @root: OSX.NSBundle.mainBundle.resourcePath

  @activeWindow: null

  @setup: ->
    @setActiveWindow new Window controller : WindowController

    # Move this someone more approriate
    if localStorage.lastOpenedPath
      @activeWindow.open localStorage.lastOpenedPath

    Plugins.load()
    @activeWindow.document.ace._emit "loaded"

  @setActiveWindow: (window) ->
    @activeWindow = window
    @windows.push window if window not in @windows
