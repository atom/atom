_ = require 'underscore'

File = require 'fs'
Window = require 'window'

module.exports =
class App
  @windows: []

  @root: OSX.NSBundle.mainBundle.resourcePath

  @activeWindow: null

  @start: ->
    @setActiveWindow new Window
      controller : WindowController
      path : localStorage.lastOpenedPath ? File.workingDirectory()

    _.map File.list("~/.atomicity/"), (path) ->
      require path

  @setActiveWindow: (window) ->
    @activeWindow = window
    @windows.push window if window not in @windows
