ace = require 'ace/ace'
canon = require 'pilot/canon'

key = require 'keymaster'

exports.bindKey = (name, shortcut, callback) ->
  key shortcut, -> callback(); false

window.handleKeyEvent = (event) ->
  if event.keyCode == 50
    console.log "Got `"
    true
  else if (event.modifierFlags & OSX.NSCommandKeyMask) and event.keyCode is 12 # cmd and q pushed
    console.log "Cmd-Q"
    true
  else
    console.log event.keyCode
    false
