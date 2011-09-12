# yay!
App = require 'app'
Window = require 'window'
App.setActiveWindow new Window controller: WindowController

Editor = require 'editor'
App.activeWindow.document = new Editor

if localStorage.lastOpenedFilename
  App.activeWindow.open(localStorage.lastOpenedFilename)

require 'plugins'
