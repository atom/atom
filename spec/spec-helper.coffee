nakedLoad 'jasmine-jquery'
$ = require 'jquery'
_ = require 'underscore'
Native = require 'native'

afterEach ->
  (new Native).resetMainMenu()

window.atom = new (require 'app')

window.keydown = (pattern) ->
  console.log @createKeyEvent(pattern)
  $(document).trigger @createKeyEvent(pattern)

window.createKeyEvent = (pattern) ->
  $.Event "keydown", atom.keyBinder.parseKeyPattern(pattern)

