ace = require 'ace/ace'
canon = require 'pilot/canon'

key = require 'keymaster'

exports.bindKey = (name, shortcut, callback) ->
  key shortcut, -> callback(); false

window.handleKeyEvent = (event) ->
  if (event.modifierFlags & OSX.NSCommandKeyMask) and event.keyCode == 50
    console.log "Got Cmd-`"
    true
  else
    false



