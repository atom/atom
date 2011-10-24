_ = require 'underscore'

File = require 'fs'
Window = require 'window'

module.exports =
class App
  @root: OSX.NSBundle.mainBundle.resourcePath

  @start: ->
    @window = new Window
      controller : AtomController
      path : localStorage.lastOpenedPath ? File.workingDirectory()
