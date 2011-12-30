nakedLoad 'jasmine-jquery'
$ = require 'jquery'
_ = require 'underscore'
Native = require 'native'

afterEach ->
  (new Native).resetMainMenu()

window.atom = new (require 'app')

window.keydown = (pattern) ->
  $(document).trigger @createKeyEvent pattern

window.createKeyEvent = (pattern) ->
  keys = pattern.split '+'
  key = _.last(keys)

  if window.namedKeys[key]
    key = window.namedKeys[key]
  else
    key = key.toUpperCase().charCodeAt 0

  $.Event "keydown",
    ctrlKey: 'ctrl' in keys
    altKey: 'alt' in keys
    shiftKey: 'shift' in keys
    metaKey: 'meta' in keys
    which: key

