# yay!
App = require 'app'
Window = require 'window'
App.setActiveWindow new Window controller: WindowController

Editor = require 'editor'
App.activeWindow.document = new Editor

require 'plugins'

if localStorage.lastOpenedFilename
  App.activeWindow.open(localStorage.lastOpenedFilename)

App.activeWindow.document.ace._emit "loaded"
