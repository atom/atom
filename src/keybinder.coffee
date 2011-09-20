_ = require 'underscore'

ace = require 'ace/ace'
canon = require 'pilot/canon'

key = require 'keymaster'

exports.bindKey = (scope, shortcut, method) ->
  key shortcut, ->
    if _.isFunction method
      method.apply scope
    else
      if scope[method]
        scope[method]()
      else
        console.error "keymap: no '#{method}' method found"

    false

window.handleKeyEvent = (event) ->
  false
#   if (event.modifierFlags & OSX.NSCommandKeyMask) and event.keyCode == 50
#     console.log "Got Cmd-`"
#     true
#   else
#     false
