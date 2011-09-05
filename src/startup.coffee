App = require 'app'
Window = require 'window'
App.setActiveWindow new Window controller: WindowController

window.handleKeyEvent = (event) ->
  if event.keyCode == 50
    console.log("Got `")
    true
  else if (event.modifierFlags & OSX.NSCommandKeyMask) and event.keyCode == 12 # cmd and q pushed
    console.log("Cmd-Q")
    true
  else
    console.log(event.keyCode)
    false

require 'editor'
require 'plugins'
